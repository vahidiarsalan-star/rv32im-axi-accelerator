# Verification

Run everything from the repository root:

```sh
python sim/run_tests.py
```

The script rebuilds the Verilog tests and C firmware, then writes logs and a
JSON summary to `build/verification/`. Use `--rtl-only` without a cross
compiler or `--waves` to keep CPU VCD files.

## Test coverage

| Test | Main checks |
| --- | --- |
| Baseline program | Integer ALU, loads/stores, branch, call/return |
| Hazard program | Forwarding priority, writeback bypass, load-use, store and branch dependencies |
| Memory lanes | Every byte lane, both halfword lanes, sign extension |
| Control flow | All branch conditions, taken/not-taken paths, backward loop, JALR |
| Immediate edges | Signed values and shifts by 31 |
| Seeded ALU programs | Six repeatable 128-operation instruction streams |
| Failure/timeout tests | Testbench errors return a nonzero process status |
| UART unit tests | All 256 byte values, false start, bad stop bit, two divisors |
| C firmware | Fresh GCC image reaches the expected UART writes |
| UART monitor | Bad commands are rejected; a valid image is loaded and run |
| Hello and echo apps | Fresh C applications are uploaded through serial RX and checked on serial TX |

The CPU programs check their own results before writing 1 to TOHOST. The Python
generator also runs the program in its small reference interpreter. Seeded ALU
tests calculate expected register values separately in Python.

This is directed and repeatable functional testing. It is not formal
verification or an ISA compliance result. The main remaining gaps are reserved
instruction encodings, exceptions and alignment behavior, exhaustive FIFO
corners, reset during traffic, baud mismatch testing, and an independent
instruction-by-instruction reference trace.

## Debugging

```sh
python sim/run_tests.py --waves
```

Open `build/verification/hazards.vcd` in GTKWave and inspect `pc`,
`ifid_valid`, `stall`, `id_bubble`, forwarded operands, memory writes,
and writeback.
