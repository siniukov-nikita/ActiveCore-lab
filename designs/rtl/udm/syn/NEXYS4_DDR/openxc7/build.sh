#!/usr/bin/env bash
set -euo pipefail

# Usage: bash openxc7/build.sh /path/to/extracted/openxc7 [pipeline|multicycle|comb]
if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo 'Usage: build.sh /path/to/openxc7 [pipeline|multicycle|comb]' >&2
    exit 2
fi
toolchain="$(cd "$1" && pwd)"
export PATH="$toolchain/bin:$PATH"
mode="${2:-pipeline}"
case "$mode" in
    pipeline) pipeline=1; multicycle=0 ;;
    multicycle) pipeline=0; multicycle=1 ;;
    comb) pipeline=0; multicycle=0 ;;
    *) echo "Unknown divider mode: $mode" >&2; exit 2 ;;
esac

cd "$(dirname "$0")/.."
out="openxc7/build/$mode"
mkdir -p "$out"
device=xc7a100tcsg324-1
database="$toolchain/share/nextpnr/external/prjxray-db/artix7"

# Keep board pin assignments and the input clock constraint in one XDC.
# nextpnr's XDC subset needs one supported command per line, without trailing comments.
awk '
    /^set_property -dict / { sub(/;.*/, ""); print }
    /^create_clock / {
        sub(/ -add -name [^ ]+/, "")
        sub(/ -waveform \{[^}]+\}/, "")
        sub(/;.*/, "")
        print
    }
' NEXYS4_DDR.xdc > "$out/board.xdc"

yosys -Q -T -p "read_verilog -sv -defer NEXYS4_DDR.sv openxc7/sys_clk.v ../../hw/*.v ../../../reset_sync/reset_sync.v ../../../ram/ram_dual.v ../../../const_divider/const_divider*.v; \
    hierarchy -top NEXYS4_DDR -chparam DIVIDER_PIPELINE $pipeline -chparam DIVIDER_MULTICYCLE $multicycle; \
    synth_xilinx -family xc7 -flatten -top NEXYS4_DDR; check -assert; write_json $out/netlist.json" \
    > "$out/synthesis.log" 2>&1
nextpnr-xilinx --device "$device" --freq 100 --json "$out/netlist.json" \
    -o "xdc=$out/board.xdc" -o "fasm=$out/design.fasm" --report "$out/timing.json" \
    > "$out/place_route.log" 2>&1
fasm2frames --part "$device" --db-root "$database" "$out/design.fasm" > "$out/design.frames"
xc7frames2bit --part_file "$database/$device/part.yaml" --part_name "$device" \
    --frm_file "$out/design.frames" --output_file "$out/NEXYS4_DDR.bit"
printf '%s\n' "$PWD/$out/NEXYS4_DDR.bit"
