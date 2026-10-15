import math
import numpy

# alg model - python math can be used here
def cube_alg(x):
    return math.floor(numpy.cbrt(x))

# hw model - synthesizable operations only
def cube_hw(x):
    y = 0;
    ss = [30, 27, 24, 21, 18, 15, 12, 9, 6, 3, 0]
    
    for s in ss:  # Do 10 times (10 stages)
        y = 2*y;
        b = (3*y*(y + 1) + 1) << s;
        if (x >= b):
            x = x - b;
            y = y + 1;
    
    return y;

# generating test stimulus
for x in range(0, 100, 10):
    alg_val = cube_alg(x)
    hw_val = cube_hw(x)
    if (alg_val == hw_val):
        print("Correct! x: ", hex(x).ljust(6), "; y: ", hex(hw_val).ljust(6))
    else:
        print("ERROR! x: ", hex(x).ljust(6), "; y(model): ", hex(alg_val).ljust(6), "; y(hw): ", hex(hw_val).ljust(6))
