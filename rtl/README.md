# RTL source map

| Module | Role |
| --- | --- |
| [rv32i_core.v](rv32i_core.v) | Five stages, hazard handling, bypassing, branches, load/store lanes |
| [decoder.v](decoder.v) | Instruction fields, immediates and control signals |
| [alu.v](alu.v) | Integer arithmetic, logic, shifts and comparisons |
| [regfile.v](regfile.v) | 32 × 32-bit registers, x0 behavior, write-first reads |
| [riscv_defs.vh](riscv_defs.vh) | Opcode and internal control encodings |
| [soc_top.v](soc_top.v) | Unified RAM, MMIO, reset sampling, receive FIFO and LEDs |
| [uart_tx.v](uart_tx.v), [uart_rx.v](uart_rx.v) | Parameterized 8N1 serial transmitter/receiver |

Top-level FPGA module: `soc_top`. CPU interface reads are asynchronous and have
no ready/valid handshake. Most RTL is Verilog-2001; the test flow uses Icarus's
`-g2012` mode for SystemVerilog testbench conveniences.

Read [architecture](../docs/ARCHITECTURE.md), [decisions](../docs/DESIGN_DECISIONS.md)
and [ISA limits](../docs/ISA_SUPPORT.md) before changing the core. Run
`python sim/run_tests.py` from the root after a source change.
