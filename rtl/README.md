# RTL

| File | Purpose |
| --- | --- |
| [rv32i_core.v](rv32i_core.v) | Five-stage CPU and hazard logic |
| [decoder.v](decoder.v) | Instruction decode and immediates |
| [alu.v](alu.v) | Integer ALU |
| [regfile.v](regfile.v) | 32 × 32-bit register file |
| [soc_top.v](soc_top.v) | RAM, MMIO, UART FIFO, LEDs, and reset |
| [uart_tx.v](uart_tx.v) | 8N1 transmitter |
| [uart_rx.v](uart_rx.v) | 8N1 receiver |
| [riscv_defs.vh](riscv_defs.vh) | Opcodes and internal control values |

FPGA top module: `soc_top`.

Read [the architecture notes](../docs/ARCHITECTURE.md) before changing the
pipeline, then run `python sim/run_tests.py`.
