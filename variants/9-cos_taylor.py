# -*- coding: utf-8 -*-

import matplotlib.pyplot as plt

FRAC_WIDTH = 16

# HW model - synthesizable operations only
def cos_hw(x):
    
    div4_fact = 2730  # div24
    div6_fact = 91    # div720
    
    # stage 0
    pow2 = (x * x) >> FRAC_WIDTH

    # stage 1
    term0_minus_term1 = (1 << FRAC_WIDTH) - (pow2 >> 1)
    pow4 = (pow2 * pow2) >> FRAC_WIDTH

    # stage 2
    pow4 = (pow2 * pow2) >> FRAC_WIDTH
    
    # stage 3
    term2 = (pow4 * div4_fact) >> FRAC_WIDTH
    pow6 = (pow4 * pow2) >> FRAC_WIDTH
    
    # stage 4
    term0_minus_term1_plus_term2 = term0_minus_term1 + term2
    term3 = (pow6 * div6_fact)  >> FRAC_WIDTH
    
    # stage 5
    y = term0_minus_term1_plus_term2 - term3
    
    return y;

# generating test stimulus
x = []
y = []
for index in range(0, 65536, 10):
    x.append(index)
    y.append(cos_hw(index))

plt.plot(x, y)
plt.show()
