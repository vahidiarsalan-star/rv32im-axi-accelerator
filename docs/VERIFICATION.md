# Verification strategy and evidence

## Run the regression

From the repository root:

```sh
python sim/run_tests.py
```

Python 3, Icarus Verilog (`iverilog`, `vvp`), and bare-metal GNU RISC-V GCC/binutils
must be on PATH. Both `riscv32-unknown-elf-` and `riscv64-unknown-elf-` prefixes are
detected; every build explicitly targets RV32I/ILP32. Set `RISCV_PREFIX` to choose
a toolchain. No Python packages are required.

```sh
python sim/run_tests.py --rtl-only   # no cross-compiler needed
python sim/run_tests.py --waves      # also retain CPU waveforms
```

The runner rebuilds executables and firmware in `build/verification/`. Each check
has a text log; `summary.json` contains pass/fail status, tools, source SHA-256,
test counts, cycle observations, and firmware binary sizes. The digest covers
top-level HDL/test/firmware sources with normalized line endings, not docs or
the generated files. It permits comparing the checked-in evidence with a rerun.

## Coverage matrix

| Check | Stimulus / observation | What a pass establishes |
| --- | --- | --- |
| `baseline` | Original 194-word self-checking program and Python ISS | Existing arithmetic, memory, hazard and call/return checks |
| `hazards` | Consecutive producers, x0, WB/ID bypass, load-use, store data/address, load/branch | Selected dependency and wrong-path side-effect cases |
| `memory_lanes` | Distinct sentinel bytes around SB/SH, all LB/LBU and aligned LH/LHU lanes | Lane preservation and signed/unsigned extraction |
| `control_flow` | All six branch predicates taken/not-taken, backward loop, odd JALR target | Predicate handling, redirect, and link result |
| `immediate_edges` | Signed/unsigned extremes, -1 immediate, shifts by 31 | Selected immediate sign/shift boundary behavior |
| `alu_seed_*` | Six repeatable 128-operation register-ALU streams | Final register values match the model for those streams |
| `failure_exit`, `timeout_exit` | Deliberate non-success TOHOST and infinite loop | Failing simulations return nonzero and cannot silently green CI |
| `uart_divisor_10`, `uart_divisor_234` | All 256 bytes through TX/RX; short start pulse; bad stop bit | Byte transport, false-start rejection and framing detection at those divisors |
| `c_firmware` | Fresh GCC hello image at reset address, always-ready MMIO | C startup and basic execution to `tick`; not physical serial timing |
| `uart_monitor` | Pin-level serial commands, rejected loads/go, valid image and jump | Command checks, loaded RAM contents, and `!` decoded from TX |
| `uart_hello_app` | Fresh C application transported over RX | Serial output contains computed 49, 25, and `tick` |
| `uart_echo_app` | Fresh echo application followed by text | The uploaded application returns the expected serial string |

The Python ISS validates generated program behavior, and the RTL executes
embedded comparisons before writing TOHOST. The seeded tests also compute
expected ALU register values in a separate Python register model. These are
selected architectural end-state checks, **not per-instruction lockstep**.
The assembler and ISS share a repository and can share misunderstandings;
an external reference and architectural test suite remain valuable next steps.

## Observability and failure handling

The CPU harness counts active testbench cycles, asserted load-stall cycles, and
redirect events until TOHOST. These include pipeline fill and test-control
instructions. `static_words` counts words in the generated image, including
paths not executed. Dividing cycle count by that value is not CPI. Redirect
events may include the terminal loop in flight behind the success store.

CPU waveforms are optional. Open `build/verification/hazards.vcd` in GTKWave and
inspect `pc`, `ifid_valid`, `stall`, `id_bubble`, forwarding operands, memory
write enables, and writeback. Start with the last incorrect committed effect,
then trace its producer backwards through stage registers.

Testbench reset releases on a falling edge to avoid a rising-edge scheduling
race. Earlier baseline logs reported 203 cycles; the deterministic reset
schedule now reports 202. This is a harness accounting change, not a core speedup.

The UART pin observer samples the center of each data bit and checks the stop
bit. The unit loopback shares TX/RX divisor settings; it is not a baud tolerance
sweep. The application/monitor harness uses a fast, internally consistent
simulation baud ratio to keep CI short, not the board's wall-clock baud rate.

## Remaining verification work

No code/functional coverage percentage is measured. There is no formal proof,
architectural compliance certification, CDC/RDC signoff, or gate-level simulation.
Add independent instruction tracing, instruction legality tests, every FIFO
full/empty simultaneous push/pop corner, baud mismatch sweeps, reset during
traffic, loader truncation/malformed input recovery, and physical-board logs.
Tests here are functional evidence for specific scenarios, not exhaustive proof.

The [CI workflow](../.github/workflows/verify.yml) runs the same command on Ubuntu
and saves logs and a machine-readable summary. [Results](RESULTS.md) distinguish
recorded local evidence from live CI status.
