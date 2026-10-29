"""Run the variant 3 divider through the UDM UART interface on Windows."""

import argparse
import pathlib
import random
import sys
import time

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

DIVIDER_ARG_ADDR = 0x00000010
DIVIDER_QUOT_ADDR = 0x00000014
DIVIDER_REM_ADDR = 0x00000018
DIVIDER_CTRL_ADDR = 0x0000001C
DIVIDER_STATUS_ADDR = 0x00000020
BUSY = 1
DONE = 2
BAUDRATE = 921600


def find_port(explicit_port):
    if explicit_port:
        return explicit_port
    import serial.tools.list_ports

    ports = [port.device for port in serial.tools.list_ports.comports()]
    if len(ports) == 1:
        return ports[0]
    if not ports:
        raise RuntimeError("No serial ports found. Connect the Nexys4-DDR board.")
    raise RuntimeError(
        "Multiple serial ports found. Use --port with one of: " + ", ".join(ports)
    )


def run_division(link, value, mode="multicycle", timeout=1.0):
    """Run one operation; UART exchange time is not accelerator latency."""
    if mode == "multicycle" and link.rd32(DIVIDER_STATUS_ADDR) & BUSY:
        raise RuntimeError("Accelerator is busy before START")
    link.wr32(DIVIDER_ARG_ADDR, value)
    if mode == "multicycle":
        link.wr32(DIVIDER_CTRL_ADDR, 1)
        deadline = time.monotonic() + timeout
        while True:
            status = link.rd32(DIVIDER_STATUS_ADDR)
            if status & DONE and not status & BUSY:
                break
            if time.monotonic() >= deadline:
                raise TimeoutError("Accelerator DONE timeout, status=0x{:08x}".format(status))
    return link.rd32(DIVIDER_QUOT_ADDR), link.rd32(DIVIDER_REM_ADDR)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", help="Windows COM port, for example COM5")
    parser.add_argument("--mode", choices=("multicycle", "comb"), default="multicycle",
                        help="Match the programmed bitstream (default: lab 3 multicycle)")
    parser.add_argument("--timeout", type=float, default=1.0,
                        help="DONE polling timeout in seconds; serial reads have their own timeout")
    parser.add_argument("--random-count", type=int, default=0,
                        help="Append this many reproducible random inputs (seed 17)")
    parser.add_argument(
        "--values",
        nargs="*",
        type=lambda value: int(value, 0),
        default=[0, 1, 16, 17, 18, 34, 65535],
        help="Unsigned 16-bit values (decimal or 0x-prefixed)",
    )
    args = parser.parse_args()
    if not 0 < args.timeout < float("inf"):
        parser.error("timeout must be positive and finite")
    if args.random_count < 0:
        parser.error("random-count must not be negative")
    rng = random.Random(17)
    args.values.extend(rng.randrange(65536) for _ in range(args.random_count))

    for value in args.values:
        if not 0 <= value <= 0xFFFF:
            parser.error("values must be in the range 0..65535")

    port = find_port(args.port)
    from udm import udm

    link = udm(port, BAUDRATE)
    try:
        for value in args.values:
            result0, result1 = run_division(link, value, args.mode, args.timeout)
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
