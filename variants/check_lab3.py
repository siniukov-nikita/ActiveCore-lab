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
    parser.add_argument("--integration", action="store_true",
                        help="Also run real UART/UDM tests with Verilator in both modes")
    args = parser.parse_args()
    for executable in ("iverilog", "vvp"):
        if shutil.which(executable) is None:
            parser.error("Install Icarus Verilog: executable not found: " + executable)
    if args.integration and shutil.which("verilator") is None:
        parser.error("Install Verilator to run --integration")

    spec = importlib.util.spec_from_file_location("div17_model", ROOT / "variants/3-const_divider.py")
    model = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(model)
    with tempfile.TemporaryDirectory(prefix="activecore-lab3-") as directory:
        build = Path(directory)
        vectors = build / "python_vectors.hex"
        with vectors.open("w") as output:
            for value in range(65536):
                quotient, remainder = model.div17(value)
                if (quotient, remainder) != divmod(value, 17):
                    raise AssertionError("Python model mismatch: x={}".format(value))
                output.write("{:08x}{:08x}\n".format(quotient, remainder))
        for top, sources in (
            ("const_divider_tb", ["const_divider.v", "tb/const_divider_tb.sv"]),
            ("const_divider_multicycle_tb", ["const_divider_multicycle.v", "tb/const_divider_multicycle_tb.sv"]),
        ):
            executable = build / top
            subprocess.run(
                ["iverilog", "-g2012", "-Wall", "-s", top, "-o", str(executable)]
                + [str(RTL / source) for source in sources], check=True,
            )
            command = ["vvp", str(executable), "+VECTORS=" + str(vectors)]
            if args.vcd and top == "const_divider_multicycle_tb":
                path = args.vcd.resolve()
                path.parent.mkdir(parents=True, exist_ok=True)
                # Icarus $dumpfile rejects non-ASCII paths. Write in the
                # temporary build directory, then let Python copy the file.
                command.append("+VCD=directed.vcd")
            subprocess.run(command, check=True, timeout=120, cwd=build)
            if args.vcd and top == "const_divider_multicycle_tb":
                shutil.copyfile(build / "directed.vcd", path)

        if args.integration:
            udm = ROOT / "designs/rtl/udm"
            integration_sources = [
                udm / "tb/tb.sv", udm / "tb/sys_clk_sim.v",
                udm / "syn/NEXYS4_DDR/NEXYS4_DDR.sv",
                RTL / "const_divider.v", RTL / "const_divider_multicycle.v",
                ROOT / "designs/rtl/reset_sync/reset_sync.v",
                ROOT / "designs/rtl/ram/ram_dual.v",
            ] + sorted((udm / "hw").glob("*.v"))
            for multicycle in (1, 0):
                obj_dir = build / ("udm_multicycle" if multicycle else "udm_comb")
                command = [
                    "verilator", "--binary", "--timing", "-j", "2", "-Wno-fatal",
                    "--top-module", "tb", "-GDIVIDER_MULTICYCLE=" + str(multicycle),
                    "--Mdir", str(obj_dir),
                ] + [str(source) for source in integration_sources]
                log_path = build / ("verilator-{}.log".format(multicycle))
                with log_path.open("w") as log:
                    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
                if result.returncode:
                    print(log_path.read_text())
                    result.check_returncode()
                subprocess.run([str(obj_dir / "Vtb")], check=True, timeout=120)


if __name__ == "__main__":
    main()
