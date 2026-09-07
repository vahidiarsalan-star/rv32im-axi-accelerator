# Roadmap and acceptance criteria

The current deliverable is the RV32I datapath + serial-loader simulation
platform. Prioritize reproducibility and FPGA memory/timing closure before
expanding the accelerator scope.

| Milestone | State | Evidence required to call it complete |
| --- | --- | --- |
| Five-stage integer pipeline | Implemented; selected regressions pass | Directed dependencies, branches, memory lanes and repeatable ALU tests |
| C runtime and resident loader | Implemented; simulated | Fresh monitor/app builds; accepted/rejected commands; uploaded C output on serial TX |
| Automated regression | Added | Green hosted CI using the checked-in command; retained logs and source digest |
| ISA legality / observability | Open | Validate reserved encodings; explicit exception policy; retirement-valid trace; independent reference comparison |
| FPGA memory subsystem | Open | Synchronous BSRAM-compatible timing contract, stalls/backpressure, same regression passing |
| Routed FPGA baseline | Open | Current-source utilization, setup/hold report, constraint review and reproducible build settings |
| Board demonstration | Open | Reset/boot/upload/echo transcript and board capture tied to a source revision |
| RV32M extension | Planned | All eight operations, dependency interlocks, signed/unsigned high products, division corner cases |
| AXI4-Lite accelerator prototype | Planned | Separate AW/W acceptance, held responses under backpressure, CSR semantics, scoreboard tests |
| INT8 dot product | Planned | Bit-exact software reference, overflow contract, measured cycles including data movement |
| External memory / DMA | Exploratory | Sustained bandwidth, arbitration, reset/error behavior, coherency/ownership contract |

## Verification backlog

1. Independent ISA reference/compliance tests and per-retirement checks.
2. Illegal/reserved encoding and instruction/data alignment behavior.
3. Exhaustive RX FIFO boundary transitions and reset during UART traffic.
4. Baud tolerance sweeps, malformed/truncated loader streams and recovery.
5. Stack high-water measurement and stress at application size boundaries.
6. CDC/RDC review and timing constraints appropriate to physical implementation.

## RV32M acceptance details

Implement MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU. The multi-cycle unit
needs operand/result validity and a stall protocol that neither loses nor
repeats side effects. Check division by zero, signed minimum divided by -1,
sign of remainder, and dependent instructions immediately before/after completion.
Keep the compiler at RV32I until RTL and tests support RV32M.

## Performance measurement plan

Add a valid retirement event before computing CPI. Measure workload instruction
mix, active cycles, load stalls and redirect penalties separately from serial
I/O and setup. For an accelerator, report compute cycles, transfer cycles and
end-to-end speedup including software launch overhead. Do not convert the
simulation clock period into a routed hardware frequency claim.

Graphics and language-model demonstrations remain exploratory ideas. There is
no HDMI pipeline, DDR controller, cache, DMA engine, or inference workload in
the present implementation.
