import math

# alg model - python math can be used here
def sqrt_alg(x):
    return math.floor(math.sqrt(x))

# hw model - synthesizable operations only
def sqrt_hw(x):
    m = 0x40000000;
    y = 0;
    
    while (m != 0):  # Do 16 times (16 stages)
        b = y | m;
        y >>= 1;
            
        if (x >= b):
            x -= b;
            y |= m;
        m >>= 2;
    
    return y;

# generating test stimulus
for x in range(0, 100, 10):
    alg_val = sqrt_alg(x)
    hw_val = sqrt_hw(x)
    if (alg_val == hw_val):
        print("Correct! x: ", hex(x).ljust(6), "; y: ", hex(hw_val).ljust(6))
    else:
        print("ERROR! x: ", hex(x).ljust(6), "; y(model): ", hex(alg_val).ljust(6), "; y(hw): ", hex(hw_val).ljust(6))
