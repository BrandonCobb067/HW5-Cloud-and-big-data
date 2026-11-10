#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "Usage: bash run_hw5.sh /absolute/input.tsv [local|mapreduce] [new-output-path]" >&2
  exit 1
fi
INPUT="$1"
MODE="${2:-local}"
case "$MODE" in local|mapreduce) ;; *) echo "Choose local or mapreduce" >&2; exit 1 ;; esac
if [[ "$MODE" == local ]]; then INPUT="$(realpath "$INPUT")"; fi
cd "$(dirname "$0")"
mkdir -p outputs
OUTPUT="${3:-hw5_part1_results_$(date +%Y%m%d_%H%M%S)}"
pig -x "$MODE" -param "INPUT=$INPUT" -param "OUTPUT=$OUTPUT" -f HW5.pig > outputs/HW5Dump.txt 2> outputs/HW5Errors.txt
echo "Part 1 DUMP results: outputs/HW5Dump.txt. Stored tables: $OUTPUT"
