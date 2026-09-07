# Reviewer guide

This project is a compact CPU/SoC implementation you can read, compile, and
exercise. The strongest review path is the hardware/software boundary: a
program moves through a pipelined CPU, memory and MMIO, then produces serial
output checked by a testbench.

## Five-minute review

1. Read the [architecture](ARCHITECTURE.md) and the status paragraph in the
   [root README](../README.md). The current milestone is RV32I simulation;
   RV32M and AXI are future work.
2. Inspect the hazard detector, forwarding priority, and bubble control in
   [rv32i_core.v](../rtl/rv32i_core.v). Check why store data and branch
   comparisons consume forwarded operands.
3. Open [design decisions](DESIGN_DECISIONS.md), especially the asynchronous
   memory contract and the cost of moving to synchronous BSRAM.
4. Run `python sim/run_tests.py`. Compare its source digest and results with
   [recorded evidence](RESULTS.md) and [live CI](https://github.com/vahidiarsalan-star/rv32im-axi-accelerator/actions).
5. Inspect [known limits](ISA_SUPPORT.md) and the [next acceptance criteria](ROADMAP.md).

## What can be assessed directly

| Engineering area | Inspectable artifact | Review question |
| --- | --- | --- |
| Pipeline correctness | [Core](../rtl/rv32i_core.v), `hazards` test | Does the youngest result win, and do wrong-path stores stay suppressed? |
| ISA/data representation | [Decoder](../rtl/decoder.v), `memory_lanes` | Are immediates, lane enables, signed comparisons and sign extension consistent? |
| Verification judgment | [Test runner](../sim/run_tests.py), [coverage matrix](VERIFICATION.md) | Which behaviors are observed, and which are still unchecked? |
| Hardware/software integration | [Monitor](../sw/monitor.c), [linker](../sw/link_app.ld), serial app tests | Do the address map, binary layout, upload format and CPU agree? |
| FPGA implementation judgment | [Bring-up notes](FPGA_BRINGUP.md) | Which memory structures map efficiently, and what evidence is needed for timing closure? |
| Technical communication | [Decision records](DESIGN_DECISIONS.md), [roadmap](ROADMAP.md) | Are tradeoffs and milestone completion criteria explicit? |

## Ten-minute demo

Run the full regression and open `build/verification/uart_hello_app.log`.
It captures the resident monitor accepting a fresh application and serial output
showing the arithmetic results. Then open `uart_echo_app.log` for receive/transmit
behavior. With `--waves`, inspect `hazards.vcd` and follow a load-use dependency
through `stall`, `id_bubble`, forwarded operands and the final writeback.

The [results page](RESULTS.md) gives tool versions, firmware footprints and
source identity. A simulation clock is not a hardware Fmax measurement, and the
current ISA tests do not establish compliance. The saved historical placement
failure is documented because it explains a concrete implementation issue and
what remains to be demonstrated.

## Useful design discussions

- How would synchronous RAM latency change load stalls and instruction fetch?
- Why does EX/MEM forwarding take priority over MEM/WB?
- Which instruction encodings expose false source dependencies in the current detector?
- What validity information would a retirement trace need for independent checking?
- What happens if a UART load fails after writing part of its payload?
- How would an AXI slave handle separate AW and W arrival and stalled B responses?

These questions are grounded in the source and its limits. There are no claimed
company affiliations, proprietary design results, or completed accelerator
features in this portfolio.
