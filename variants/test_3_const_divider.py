import importlib.util
import pathlib
import unittest


MODEL_PATH = pathlib.Path(__file__).with_name("3-const_divider.py")
SPEC = importlib.util.spec_from_file_location("const_divider_model", MODEL_PATH)
MODEL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODEL)


class ConstDividerModelTest(unittest.TestCase):
    def test_all_16_bit_values(self):
        for value in range(1 << 16):
            quotient, remainder = MODEL.div17(value)
            self.assertEqual((quotient, remainder), divmod(value, 17))


if __name__ == "__main__":
    unittest.main()
