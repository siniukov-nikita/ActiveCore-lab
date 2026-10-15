# hw model - synthesizable operations only
def div17(x):
    dividend_size=16
    divisor=17
    divisor_size=4
    
    quotient=0
    divword = x >> (dividend_size-divisor_size)
    
    # iterations - stages
    for i in range(0, dividend_size-divisor_size+1):
        quotient = (quotient << 1)
        if (divword >= divisor):
            divword = divword-divisor
            quotient = quotient | 1
        if (i != (dividend_size-divisor_size)):
            divword = (divword << 1) | ((x & (1 << dividend_size-divisor_size-1-i)) != 0)
    
    return [quotient, divword]

if __name__ == "__main__":
    for i in range(0, 1000, 100):
        result = div17(i)
        print("x: " + str(i) + ", x/17: " + str(result[0]) + ", rem: " + str(result[1]))