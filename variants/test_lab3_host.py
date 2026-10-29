"""Host-side protocol tests without a serial port or connected FPGA."""

import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "designs/rtl/udm/sw/divider_test.py"
SPEC = importlib.util.spec_from_file_location("divider_host", SCRIPT)
HOST = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HOST)


class FakeLink:
    def __init__(self, statuses):
        self.statuses = iter(statuses)
        self.writes = []
        self.ready = False

    def wr32(self, address, value):
        self.writes.append((address, value))

    def rd32(self, address):
        if address == HOST.DIVIDER_STATUS_ADDR:
            status = next(self.statuses)
            self.ready = status == HOST.DONE
            return status
        if not self.ready:
            raise AssertionError("Host read a result before completion")
        if address == HOST.DIVIDER_QUOT_ADDR:
            return 2
        if address == HOST.DIVIDER_REM_ADDR:
            return 1
        raise AssertionError("Unexpected address")


class DividerHostTest(unittest.TestCase):
    def test_waits_for_done_and_busy_clear(self):
        link = FakeLink([0, HOST.BUSY, HOST.BUSY | HOST.DONE, HOST.DONE])
        self.assertEqual(HOST.run_division(link, 35), (2, 1))
        self.assertEqual(link.writes, [(HOST.DIVIDER_ARG_ADDR, 35), (HOST.DIVIDER_CTRL_ADDR, 1)])

    def test_immediate_completion_after_previous_done(self):
        # 130 ns work can finish before the first UART status read.
        link = FakeLink([HOST.DONE, HOST.DONE])
        self.assertEqual(HOST.run_division(link, 35), (2, 1))
        self.assertIn((HOST.DIVIDER_CTRL_ADDR, 1), link.writes)

    def test_rejects_busy_before_start(self):
        link = FakeLink([HOST.BUSY])
        with self.assertRaisesRegex(RuntimeError, "busy before START"):
            HOST.run_division(link, 35)
        self.assertEqual(link.writes, [])

    def test_completion_timeout(self):
        link = FakeLink([0, HOST.BUSY])
        with patch.object(HOST.time, "monotonic", side_effect=[0.0, 1.0]):
            with self.assertRaisesRegex(TimeoutError, "DONE timeout"):
                HOST.run_division(link, 35, timeout=0.5)

    def test_lab2_mode_has_no_control_or_status_transactions(self):
        link = FakeLink([])
        link.ready = True
        self.assertEqual(HOST.run_division(link, 35, mode="comb"), (2, 1))
        self.assertEqual(link.writes, [(HOST.DIVIDER_ARG_ADDR, 35)])


if __name__ == "__main__":
    unittest.main()
