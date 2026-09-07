# Design decisions and tradeoffs

These records explain the implementation visible in the source and what each
choice costs. They do not claim that future features or measured performance
already exist.

## D01 — Five in-order stages

**Choice:** separate fetch, decode, execute, memory, and writeback, with
side-effect controls carried through registers.

**Reason:** the pipeline makes data dependencies, control recovery, and memory
timing explicit and provides a manageable platform for RTL experimentation.
Compared with a single-cycle core it adds state and hazard logic; compared with
a deeper pipeline it keeps bypass and recovery paths smaller.

**Cost:** forwarding multiplexers and branch logic can limit the EX critical
path. Extra pipeline stages alone do not prove higher Fmax. The current tests
exercise functionality; there is no routed timing result for this revision.

**Evidence:** [core](../rtl/rv32i_core.v), `hazards` and `control_flow` regressions.

## D02 — Forward operands, prioritize the newest producer

**Choice:** EX/MEM precedes MEM/WB in the forwarding muxes; bypass matching
writeback into register-file reads; exclude x0 from forwarding and writes.

**Reason:** most arithmetic RAW dependencies can execute without waiting for
register writeback. Store data and branch predicates need the same corrected
operands as ALU operations.

**Cost:** comparators, fanout, and mux delay. Forwarding asynchronous load data
also exposes a memory-read-to-EX combinational path. A synchronous memory
subsystem will need a revised availability/latency model.

**Evidence:** adjacent same-destination producers, WB-to-ID distance, load-to-store,
store-address, and load-to-branch cases in [gen_regression.py](../sim/gen_regression.py).

## D03 — One load-use bubble with conservative decode

**Choice:** hold the front end and clear the consumer's controls for one cycle.
The existing detector compares raw register fields even when an opcode does
not semantically read one of them.

**Reason:** this keeps a small, deterministic hazard mechanism in the teaching
core and prevents a consumer from advancing immediately behind a load.

**Cost:** false dependencies can reduce throughput. With today's asynchronous
read and MEM-to-EX data path the bubble is also conservative; removing it would
require a deliberate timing and functional study. Add source-use qualifiers
before making performance claims based on stall counts.

## D04 — Resolve branches in EX

**Choice:** sequential fetch, with EX redirection and two younger slots flushed.

**Reason:** the comparator sees forwarded register values without a separate
ID-stage bypass network. It is easy to inspect wrong-path side effects.

**Cost:** taken branches and jumps lose fetch work. Earlier resolution or a
predictor could help, but needs additional dependency logic and verification.
The first step is a retirement-valid interface and workload-based measurement.

## D05 — Small asynchronous unified RAM

**Choice:** 4 KiB for the SoC and a larger 16 KiB array in the CPU testbench;
combinational instruction and data reads, byte-enabled synchronous writes.

**Reason:** the core can run useful bare-metal code with a simple memory contract.

**Cost:** the interface is not the synchronous BSRAM interface intended for a
scalable FPGA system. The RTL comment describes a small register-RAM bring-up
model, but actual mapping and fit must be established by current synthesis.
4 KiB is 32,768 storage bits before considering the rest of the design; the
source-level size alone does not prove that it fits this device. Low-address
RAM aliases outside the intended window because only index bits are decoded.

**Next decision:** define valid/ready responses, pipeline stalls, and read-during-
write behavior; then infer BSRAM and compare utilization/timing for the same tests.

## D06 — Polling UART with a receive FIFO

**Choice:** one-byte TX, 16-byte RX FIFO, status polling, sticky error flags.

**Reason:** burst absorption helps while the monitor prints responses without
requiring interrupts or DMA. Explicit `dmem_re` prevents ordinary address
activity from unintentionally popping the FIFO.

**Cost:** CPU cycles are spent polling; overrun still occurs if software cannot
keep up. The RX FIFO is not flow control. The tests cover UART byte values and
application streams, but exhaustive FIFO boundary interleavings remain open.

## D07 — Resident monitor plus PC-side compilation

**Choice:** reserve 2 KiB for the monitor, 1536 bytes for an uploaded application,
and 512 bytes for stack; load words with a modulo-2^32 additive checksum.

**Reason:** source edits can be compiled and transported over serial without
regenerating the FPGA bitstream for every application. Plain hexadecimal makes
the protocol inspectable with a terminal and a logic analyzer.

**Cost:** ASCII expands each four-byte word to nine text bytes with LF framing.
The checksum detects some accidental corruption but does not authenticate an
image. Failed loads can leave partially changed RAM, though the monitor clears
the valid-image flag. Uploaded code owns the CPU; reset returns to the monitor.
This is a trusted development-loader model, not a secure boot design.

## D08 — Freestanding toolchain, no implicit runtime

**Choice:** `-march=rv32i -mabi=ilp32`, no libc/start files, explicit stack/BSS
initialization and linker bounds. Disable relaxation and small-data generation
because the startup code does not initialize `gp`.

**Reason:** the generated software contract must match the actual hardware and
startup code. The decimal printer uses subtraction rather than a divide runtime.

**Cost:** general C libraries, floating point, division helpers, and larger
programs need deliberate runtime support and memory budgeting. Disabling
relaxation increases the monitor image, reducing its headroom. The ELF can
contain an RWX segment because RAM holds both code and data; there is no memory
protection hardware. See [results](RESULTS.md) for measured image sizes.
