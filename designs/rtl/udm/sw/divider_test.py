"""Run variant 3 or variant 10 through the UDM UART interface on Windows."""

import argparse
import importlib.util
import pathlib
import sys

import serial.tools.list_ports

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from udm import udm

MODEL_PATH = SCRIPT_DIR.parents[3] / "variants" / "10-atan2_cordic.py"
MODEL_SPEC = importlib.util.spec_from_file_location("atan2_cordic_model", MODEL_PATH)
MODEL = importlib.util.module_from_spec(MODEL_SPEC)
MODEL_SPEC.loader.exec_module(MODEL)


VARIANT_SEL_ADDR = 0x00000008
DIVIDER_ARG_ADDR = 0x00000010
DIVIDER_QUOT_ADDR = 0x00000014
DIVIDER_REM_ADDR = 0x00000018
BAUDRATE = 921600


def signed32(value):
    return value if value < (1 << 31) else value - (1 << 32)


def find_port(explicit_port):
    if explicit_port:
        return explicit_port
    ports = [port.device for port in serial.tools.list_ports.comports()]
    if len(ports) == 1:
        return ports[0]
    if not ports:
        raise RuntimeError("No serial ports found. Connect the Nexys4-DDR board.")
    raise RuntimeError(
        "Multiple serial ports found. Use --port with one of: " + ", ".join(ports)
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", help="Windows COM port, for example COM5")
    parser.add_argument("--variant", choices=("3", "10"), default="3")
    parser.add_argument(
        "--values",
        nargs="*",
        type=lambda value: int(value, 0),
        default=[0, 1, 16, 17, 18, 34, 65535],
        help="Unsigned 16-bit values (decimal or 0x-prefixed)",
    )
    args = parser.parse_args()

    variant = int(args.variant)
    for value in args.values:
        if variant == 3 and not 0 <= value <= 0xFFFF:
            parser.error("variant 3 values must be in the range 0..65535")
        if variant == 10 and not -(1 << 31) <= value < (1 << 31):
            parser.error("variant 10 values must be signed 32-bit integers")

    port = find_port(args.port)
    link = udm(port, BAUDRATE)
    try:
        link.check()
        link.wr32(VARIANT_SEL_ADDR, 1 if variant == 10 else 0)
        for value in args.values:
            if variant == 3:
                link.wr32(DIVIDER_ARG_ADDR, value)
                result0 = link.rd32(DIVIDER_QUOT_ADDR)
                result1 = link.rd32(DIVIDER_REM_ADDR)
                expected = divmod(value, 17)
                status = "PASS" if (result0, result1) == expected else "FAIL"
                print("x={:5d} quotient={:5d} remainder={:2d} expected=({}, {}) {}".format(
                    value, result0, result1, expected[0], expected[1], status
                ))
            else:
                link.wr32(DIVIDER_ARG_ADDR, value)
                link.wr32(DIVIDER_QUOT_ADDR, 1)
                result0 = link.rd32(DIVIDER_REM_ADDR)
                expected = MODEL.atan2_cordic_hw(value, 1)
                status = "PASS" if abs(signed32(result0) - expected) <= 4 else "FAIL"
                print("y={:5d} x={:5d} angle={} expected={} {}".format(
                    value, 1, signed32(result0), expected, status
                ))
            if status == "FAIL":
                raise RuntimeError("Accelerator result mismatch")
    finally:
        link.disconnect()


if __name__ == "__main__":
    main()
