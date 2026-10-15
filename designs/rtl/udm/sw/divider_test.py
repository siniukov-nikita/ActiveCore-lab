"""Run the variant 3 divider through the UDM UART interface on Windows."""

import argparse
import pathlib
import sys

import serial.tools.list_ports

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from udm import udm

DIVIDER_ARG_ADDR = 0x00000010
DIVIDER_QUOT_ADDR = 0x00000014
DIVIDER_REM_ADDR = 0x00000018
BAUDRATE = 921600


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
    parser.add_argument(
        "--values",
        nargs="*",
        type=lambda value: int(value, 0),
        default=[0, 1, 16, 17, 18, 34, 65535],
        help="Unsigned 16-bit values (decimal or 0x-prefixed)",
    )
    args = parser.parse_args()

    for value in args.values:
        if not 0 <= value <= 0xFFFF:
            parser.error("values must be in the range 0..65535")

    port = find_port(args.port)
    link = udm(port, BAUDRATE)
    try:
        link.check()
        for value in args.values:
            link.wr32(DIVIDER_ARG_ADDR, value)
            result0 = link.rd32(DIVIDER_QUOT_ADDR)
            result1 = link.rd32(DIVIDER_REM_ADDR)
            expected = divmod(value, 17)
            status = "PASS" if (result0, result1) == expected else "FAIL"
            print("x={:5d} quotient={:5d} remainder={:2d} expected=({}, {}) {}".format(
                value, result0, result1, expected[0], expected[1], status
            ))
            if status == "FAIL":
                raise RuntimeError("Accelerator result mismatch")
    finally:
        link.disconnect()


if __name__ == "__main__":
    main()
