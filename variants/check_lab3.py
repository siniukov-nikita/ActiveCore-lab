"""Exhaustive RTL check against Python div17 and independent /17, %17 oracles.

Requires Icarus Verilog (iverilog and vvp). Build files live in a temporary folder.
"""

import argparse
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "designs/rtl/const_divider"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vcd", type=Path, help="Save directed-case waveform to this path")
    parser.add_argument("--pipeline", action="store_true",
                        help="Check lab 4 pipeline instead of lab 2/3 cores")
    parser.add_argument("--integration", action="store_true",
                        help="Also run UART/UDM tests with Verilator for the selected modes")
    args = parser.parse_args()
    for executable in ("iverilog", "vvp"):
        if shutil.which(executable) is None:
            parser.error("Install Icarus Verilog: executable not found: " + executable)
    if args.integration and shutil.which("verilator") is None:
        parser.error("Install Verilator to run --integration")

    spec = importlib.util.spec_from_file_location("div17_model", ROOT / "variants/3-const_divider.py")
    model = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(model)
    with tempfile.TemporaryDirectory(prefix="activecore-divider-") as directory:
        build = Path(directory)
        vectors = build / "python_vectors.hex"
        with vectors.open("w") as output:
            for value in range(65536):
                quotient, remainder = model.div17(value)
                if (quotient, remainder) != divmod(value, 17):
                    raise AssertionError("Python model mismatch: x={}".format(value))
                output.write("{:08x}{:08x}\n".format(quotient, remainder))
        cores = ["const_divider_pipeline"] if args.pipeline else ["const_divider", "const_divider_multicycle"]
        for core in cores:
            top = core + "_tb"
            sources = [core + ".v", "tb/" + top + ".sv"]
            executable = build / top
            subprocess.run(
                ["iverilog", "-g2012", "-Wall", "-s", top, "-o", str(executable)]
                + [str(RTL / source) for source in sources], check=True,
            )
            command = ["vvp", str(executable), "+VECTORS=" + str(vectors)]
            save_wave = args.vcd is not None and core != "const_divider"
            if save_wave:
                # Icarus $dumpfile rejects non-ASCII paths. Write in the
                # temporary build directory, then let Python copy the file.
                command.append("+VCD=directed.vcd")
            subprocess.run(command, check=True, timeout=120, cwd=build)
            if save_wave:
                path = args.vcd.resolve()
                path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(build / "directed.vcd", path)

        if args.integration:
            udm = ROOT / "designs/rtl/udm"
            clock_model = "syn/NEXYS4_DDR/openxc7/sys_clk.v" if args.pipeline else "tb/sys_clk_sim.v"
            integration_sources = [
                udm / "tb/tb.sv", udm / clock_model,
                udm / "syn/NEXYS4_DDR/NEXYS4_DDR.sv",
                RTL / "const_divider.v", RTL / "const_divider_multicycle.v",
                RTL / "const_divider_pipeline.v",
                ROOT / "designs/rtl/reset_sync/reset_sync.v",
                ROOT / "designs/rtl/ram/ram_dual.v",
            ] + sorted((udm / "hw").glob("*.v"))
            modes = [("pipeline", 0, 1)] if args.pipeline else [("multicycle", 1, 0), ("comb", 0, 0)]
            for mode, multicycle, pipeline in modes:
                obj_dir = build / ("udm_" + mode)
                command = [
                    "verilator", "--binary", "--timing", "-j", "2", "-Wno-fatal",
                    "--top-module", "tb", "-GDIVIDER_MULTICYCLE=" + str(multicycle),
                    "-GDIVIDER_PIPELINE=" + str(pipeline),
                    "--Mdir", str(obj_dir),
                ] + [str(source) for source in integration_sources]
                log_path = build / ("verilator-{}.log".format(mode))
                with log_path.open("w") as log:
                    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
                if result.returncode:
                    print(log_path.read_text())
                    result.check_returncode()
                subprocess.run([str(obj_dir / "Vtb")], check=True, timeout=120)


if __name__ == "__main__":
    main()
