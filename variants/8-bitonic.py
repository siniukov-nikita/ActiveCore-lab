import math
import numpy

# alg model - python math can be used here
def sort_alg(x):
    y = x[:];
    y.sort();
    return y;

# hw model - synthesizable operations only
def sort_asc(x, index0, index1):
    if (x[index0] > x[index1]):
        x[index0], x[index1] = x[index1], x[index0]

def bitonic_sort_8_hw(x):
    y = x[:]
    
    # stage 1
    sort_asc(y, 0, 1)
    sort_asc(y, 3, 2)
    sort_asc(y, 4, 5)
    sort_asc(y, 7, 6)
        
    # stage 2
    sort_asc(y, 0, 2)
    sort_asc(y, 1, 3)
    sort_asc(y, 6, 4)
    sort_asc(y, 7, 5)
    
    sort_asc(y, 0, 1)
    sort_asc(y, 2, 3)
    sort_asc(y, 5, 4)
    sort_asc(y, 7, 6)
        
    # stage 3
    sort_asc(y, 0, 4)
    sort_asc(y, 1, 5)
    sort_asc(y, 2, 6)
    sort_asc(y, 3, 7)
    
    sort_asc(y, 0, 2)
    sort_asc(y, 1, 3)
    sort_asc(y, 4, 6)
    sort_asc(y, 5, 7)
    
    sort_asc(y, 0, 1)
    sort_asc(y, 2, 3)
    sort_asc(y, 4, 5)
    sort_asc(y, 6, 7)
    return y;

# generating test stimulus
x = [51, 160, 4, 77, 194, 223, 13, 84]

y_alg = sort_alg(x)
y_hw = bitonic_sort_8_hw(x)

for index in range(0, 8):
    if (y_alg[index] == y_hw[index]):
        print("Correct! index: ", hex(index).ljust(6), "; y: ", hex(y_hw[index]).ljust(6))
    else:
        print("ERROR! index: ", hex(index).ljust(6), "; y(model): ", hex(y_alg[index]).ljust(6), "; y(hw): ", hex(y_hw[index]).ljust(6))
