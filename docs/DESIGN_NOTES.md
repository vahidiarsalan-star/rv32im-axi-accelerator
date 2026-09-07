# Design notes

The design reference is now split into focused documents:

- [Architecture](ARCHITECTURE.md): stage state, forwarding, hazards, memory and UART.
- [Design decisions](DESIGN_DECISIONS.md): rationale, costs, alternatives and next experiments.
- [Memory map](MEMORY_MAP.md): register side effects, linker regions and loader protocol.
- [ISA scope](ISA_SUPPORT.md): implemented datapath operations and unsupported behavior.
- [Verification](VERIFICATION.md) and [results](RESULTS.md): coverage and reproducible evidence.
- [FPGA bring-up](FPGA_BRINGUP.md): current target, constraints and historical placement failure.
- [Roadmap](ROADMAP.md) and [accelerator proposal](ACCELERATOR_PLAN.md): future work.

The current implementation is an RV32I integer datapath and UART SoC.
RV32M, AXI, external memory and accelerator integration are not implemented.
