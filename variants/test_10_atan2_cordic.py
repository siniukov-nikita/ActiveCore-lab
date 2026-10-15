import importlib.util
import pathlib
import unittest


MODEL_PATH = pathlib.Path(__file__).with_name("10-atan2_cordic.py")
SPEC = importlib.util.spec_from_file_location("atan2_cordic_model", MODEL_PATH)
MODEL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODEL)


class Atan2CordicTest(unittest.TestCase):
    def test_axes_and_quadrants(self):
        expected = {
            (0, 0): 0, (1, 0): 935919876, (-1, 0): -935919876,
            (0, 1): 92605020, (0, -1): -1594024693,
            (1, 1): 438082046, (1, -1): 1281396903,
            (-1, 1): -405232810, (-1, -1): -1248547667,
            (100, 100): 421305026, (-100, 100): -422009830,
            (100, -100): 1264619883, (-100, -100): -1265324687,
        }
        for inputs, expected_angle in expected.items():
            self.assertEqual(MODEL.atan2_cordic_hw(*inputs), expected_angle)

    def test_signed_representative_inputs(self):
        for y in range(-1000, 1001, 37):
            for x in range(-1000, 1001, 41):
                actual = MODEL.atan2_cordic_hw(y, x)
                self.assertGreaterEqual(actual, -MODEL.PI)
                self.assertLessEqual(actual, MODEL.PI)
                if x == 0 and y == 0:
                    self.assertEqual(actual, 0)


if __name__ == "__main__":
    unittest.main()
