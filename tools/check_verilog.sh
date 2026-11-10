#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p output/verilog
if command -v iverilog >/dev/null && command -v vvp >/dev/null; then
    iverilog -g2012 -Wall -s tb_glue -o output/verilog/tb_glue.vvp \
        examples/verilog/glue.v examples/verilog/tb_glue.v
    vvp output/verilog/tb_glue.vvp
else
    vendor/iverilog/usr/bin/iverilog -B vendor/iverilog/usr/lib/ivl \
        -g2012 -Wall -s tb_glue -o output/verilog/tb_glue.vvp \
        examples/verilog/glue.v examples/verilog/tb_glue.v
    vendor/iverilog/usr/bin/vvp output/verilog/tb_glue.vvp
fi
