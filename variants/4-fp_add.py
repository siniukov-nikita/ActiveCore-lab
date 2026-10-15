# hw model - synthesizable operations only
def fp_add(x0, x1):
    
    x0_sign = (x0 >> 31) & 0x1
    x0_exp = (x0 >> 23) & 0xff
    x0_frac = x0 & 0x7fffff
    
    x1_sign = (x1 >> 31) & 0x1
    x1_exp = (x1 >> 23) & 0xff
    x1_frac = x1 & 0x7fffff
    
    res_sign = 0
    res_exp = 0
    res_frac = 0
    
    # stage 0: normalization
    if (x1_exp < x0_exp):
        x1_frac = x1_frac >> (x0_exp - x1_exp)
        x1_exp = x0_exp
    elif (x0_exp < x1_exp):
        x0_frac = x0_frac >> (x1_exp - x0_exp)
        x0_exp = x1_exp
    res_exp = x0_exp
    
    # stage 1: sign processing
    op0 = 0
    op1 = 0
    if x0_sign != x1_sign:
        if x0_frac > x1_frac:
            res_sign = x0_sign
            op0 = x0_frac
            op1 = -x1_frac
        else:
            res_sign = x1_sign
            op0 = x1_frac
            op1 = -x0_frac
    else:
        res_sign = x0_sign
        op0 = x0_frac
        op1 = x1_frac
    
    # stage 2: addition
    res_frac = op0 + op1

    res = (res_sign << 31) + (res_exp << 23) + res_frac
    
    return res


# decode variable:
def decode(x):
    print("sign: ", (x >> 31) & 0x1)
    print("exp:  ", (x >> 23) & 0xff)
    print("frac: ", x & 0x7fffff)

# generating test stimulus
x0_sign = 0
x0_exp = 5
x0_frac = 356

x1_sign = 1
x1_exp = 7
x1_frac = 4

x0 = (x0_sign << 31) + (x0_exp << 23) + x0_frac
x1 = (x1_sign << 31) + (x1_exp << 23) + x1_frac

res = fp_add(x0, x1)

print("x0: ", hex(x0))
print(decode(x0))
print("x1: ", hex(x1))
print(decode(x1))
print("result: ", hex(res))
print(decode(res))
