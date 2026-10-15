import math

# HW model - synthesizable operations only
def pattern_match_last(datain, pattern):
    DATAIN_SIZE = 16
    PATTERN_SIZE = 4
    TOTAL_POSITIONS = DATAIN_SIZE - PATTERN_SIZE + 1
    TOTAL_NIBBLE_POSITIONS = math.ceil(TOTAL_POSITIONS/4)
    
    pos_found = [0] * TOTAL_POSITIONS
    
    # 1st stage: parallel pattern detection
    datain_tmp = datain
    for i in range(0, TOTAL_POSITIONS):
        if ((datain_tmp[0] == pattern[0]) &
            (datain_tmp[1] == pattern[1]) & 
            (datain_tmp[2] == pattern[2]) &
            (datain_tmp[3] == pattern[3])):
            pos_found[i] = 1
        else:
            pos_found[i] = 0
        datain_tmp = datain_tmp[1:] + " "
    
    # 2nd stage: parallel finding first entry by nibbles
    nibble_pos_found = [0] * TOTAL_NIBBLE_POSITIONS
    nibble_pos_number = [0] * TOTAL_NIBBLE_POSITIONS
    for i in range(0, (TOTAL_NIBBLE_POSITIONS-1)):
        for j in range(0, 4):
            base_pos = (i<<2)+j
            if (pos_found[base_pos] & (nibble_pos_found[i] == 0)):
                nibble_pos_found[i] = 1
                nibble_pos_number[i] = base_pos
    nibble_pos_found[TOTAL_NIBBLE_POSITIONS-1] = pos_found[12]
    nibble_pos_number[TOTAL_NIBBLE_POSITIONS-1] = 12
    
    # 3rd stage: final position finder
    final_pos = 0
    for i in range(0, TOTAL_NIBBLE_POSITIONS):
        if nibble_pos_found[i]:
            final_pos = nibble_pos_number[i]
    return final_pos

# generating stimulus
def test_case(datain, pattern):
    print("datain: " + datain + ", pattern: " + pattern + ", last pos: " + str(pattern_match_last(datain, pattern)))

test_case("ABCDABCDABCDABCD", "CDAB")
test_case("Hello World, OK?", "Worl")
test_case("Again and again!", "gain")
test_case("2 be or not 2 be", "2 be")
