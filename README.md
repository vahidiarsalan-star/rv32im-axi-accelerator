# RV32IM FPGA Processor

An educational RISC-V processor and SoC for the Sipeed Tang Primer 20K. The
current hardware is a working, five-stage **RV32I** pipeline with forwarding,
load-use hazard handling, branch flushing, on-chip RAM, UART, and LEDs. The
RISC-V **M** extension is the next planned processor milestone.

## Project layout

| Directory | Contents |
| --- | --- |
| [`rtl/`](rtl/) | Synthesizable Verilog for the CPU, SoC, register file, ALU, and UART |
| [`sim/`](sim/) | Self-checking testbenches, golden instruction-set model, and simulation scripts |
| [`sw/`](sw/) | Bare-metal startup code, linker scripts, UART monitor, examples, and build scripts |
| [`gowin/`](gowin/) | Tang Primer 20K project, constraints, timing constraints, and default firmware image |
| [`docs/`](docs/) | Design notes, roadmap, and learning guide |

Generated simulator executables, waveforms, compiler outputs, and Gowin
implementation results are intentionally excluded from version control.

## Quick start: simulation

Requirements: Python 3 and, for RTL simulation, Icarus Verilog (`iverilog` and
`vvp`).

```powershell
cd sim
.\run_sim.ps1
```

The Python generator first validates the test program against its golden model.
A successful RTL run ends with `*** PASS ***`.

## Build the resident UART monitor

Requirements: `riscv32-unknown-elf-gcc` and
`riscv32-unknown-elf-objcopy`.

```powershell
cd sw
.\build.ps1
```

This rebuilds the monitor and updates `gowin/firmware.hex` for the FPGA project.
See [`sw/README.md`](sw/README.md) for application upload instructions.

## FPGA target

- Board: Sipeed Tang Primer 20K Dock
- Device: Gowin GW2A-LV18PG256C8/I7
- Clock: 27 MHz
- Gowin project: [`gowin/riscv_pipeline20.gprj`](gowin/riscv_pipeline20.gprj)

For architecture details and current implementation status, see
[`docs/DESIGN_NOTES.md`](docs/DESIGN_NOTES.md) and
[`docs/ROADMAP.md`](docs/ROADMAP.md).
