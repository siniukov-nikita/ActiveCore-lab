### UDM baseline address map

HW block | Start address | End address | Size | Type | Description
-------- | ------------- | ----------- | ---- | ---- | -----------
CSR_LED | 0x00000000 | 0x00000000 | 4 B | rw | LED register
CSR_SW | 0x00000004 | 0x00000004 | 4 B | r | Switches register
VARIANT_SEL | 0x00000008 | 0x00000008 | 4 B | rw | Active variant: 0 for divider, 1 for atan2 CORDIC; common map 0x10/0x14/0x18 follows this selection
DIVIDER_ARG | 0x00000010 | 0x00000010 | 4 B | rw | 16-bit unsigned dividend; writing starts a new combinational calculation
DIVIDER_QUOT | 0x00000014 | 0x00000014 | 4 B | r | 32-bit quotient of DIVIDER_ARG / 17
DIVIDER_REM | 0x00000018 | 0x00000018 | 4 B | r | 32-bit remainder of DIVIDER_ARG / 17
ATAN2_Y | 0x00000020 | 0x00000020 | 4 B | rw | Signed 32-bit y input
ATAN2_X | 0x00000024 | 0x00000024 | 4 B | rw | Signed 32-bit x input
ATAN2_ANGLE | 0x00000028 | 0x00000028 | 4 B | r | Signed Q3.29 atan2(y,x) result in radians
testmem | 0x80000000 | 0x80000FFF | 4 KB | rw | Test RAM
