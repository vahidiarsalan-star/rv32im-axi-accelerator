# Recorded verification results

## Local regression, 2026-09-07

Command: `python sim/run_tests.py --waves`, run on Windows with Python 3.14.6,
Icarus Verilog 13.0, and riscv32-unknown-elf GCC 14.2.0.

**19 checks passed:** 11 CPU programs, two intentional-failure harness checks,
two UART configurations, standalone C execution, the monitor protocol, and two
serially uploaded C applications. See the
[machine-readable snapshot](evidence/verification-2026-09-07.json) for the
source SHA-256 and complete per-test records.

| CPU program | Static image words | Harness cycles | Load-stall cycles | Redirect events |
| --- | ---: | ---: | ---: | ---: |
| Baseline | 194 | 202 | 1 | 6 |
| Hazard interactions | 73 | 76 | 3 | 2 |
| Memory lanes | 149 | 149 | 0 | 1 |
| Control flow | 135 | 143 | 0 | 10 |
| Immediate edges | 231 | 231 | 0 | 1 |
| Each seeded ALU case (6) | 245 | 245 | 0 | 1 |

These are harness counters, not CPI or retired-instruction counts. Static image
words include instructions on unexecuted paths. The deterministic reset release
changed baseline accounting from an older 203-cycle log to 202; this is not a
hardware performance improvement. See [measurement definitions](VERIFICATION.md).

## Firmware footprints

| Image | Binary bytes (before word padding) | Link region |
| --- | ---: | --- |
| Resident monitor | 1930 | Lower 2048 bytes; additionally 12 bytes of BSS |
| Uploaded hello | 615 | 1536-byte application region |
| Uploaded echo | 327 | 1536-byte application region |
| Standalone hello smoke image | 615 | Standalone 4 KiB map |

Linker assertions bound static allocation; stack use is not measured. The
monitor ELF reports an RWX load segment because this simple system runs code
and data from the same unprotected RAM. Toolchain versions can change sizes;
the regression rebuilds rather than requiring these numbers to be identical.

## Serial evidence

[Selected transcripts](evidence/serial-demo-2026-09-07.md) show rejected commands,
successful machine-code loading, and the freshly compiled hello and echo apps.
TX output is decoded from the serial pin, including stop-bit checking. UART unit
tests transport every byte value at divisors 10 and 234 and check false-start
rejection and a malformed stop bit.

## What these results do not establish

There is no complete ISA compliance result, independent per-retirement lockstep,
coverage percentage, formal proof, current FPGA utilization/Fmax, power result,
or physical-board demonstration. The [historical Gowin placement error](evidence/gowin-2026-08-01.md)
belongs to an older netlist and is not a current PPA result.

The badge in the [root README](../README.md) links to live hosted CI, separate
from this dated local snapshot. Rerun the same command to generate current logs
and compare source digests before citing this evidence for a later revision.
