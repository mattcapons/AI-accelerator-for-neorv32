#!/usr/bin/env bash
set -euo pipefail

GHDL="${GHDL:-ghdl}"
STD="${STD:-08}"
WORKDIR="${WORKDIR:-build/ghdl}"

rtl_sources=(
  rtl/systolic_pkg.vhd
  rtl/systolic_pe.vhd
  rtl/systolic_array.vhd
  rtl/systolic_controller.vhd
  rtl/buffer_unit.vhd
  rtl/systolic_engine.vhd
)

default_tests=(
  tb_buffer_unit
  tb_systolic_pe
  tb_systolic_controller
  tb_systolic_array
)

if [[ "${1:-}" == "clean" ]]; then
  rm -rf build
  exit 0
fi

tests=("$@")
if [[ ${#tests[@]} -eq 0 ]]; then
  tests=("${default_tests[@]}")
fi

mkdir -p "$WORKDIR"

"$GHDL" -a --std="$STD" --workdir="$WORKDIR" "${rtl_sources[@]}"

for test in "${tests[@]}"; do
  "$GHDL" -a --std="$STD" --workdir="$WORKDIR" "sim/${test}.vhd"
  "$GHDL" -e --std="$STD" --workdir="$WORKDIR" "$test"
  "$GHDL" -r --std="$STD" --workdir="$WORKDIR" "$test" --assert-level=error
done
