# Architecture

## Pipeline

The core is an in-order five-stage design:

| Stage | Main work |
| --- | --- |
| IF | Select PC and read the next instruction |
| ID | Decode instruction and read the register file |
| EX | Forward operands, run the ALU, and resolve branches |
| MEM | Read or write memory and select byte lanes |
| WB | Write ALU, load, or PC+4 data to the register file |

Pipeline state is stored in IF/ID, ID/EX, EX/MEM, and MEM/WB registers.
Instructions enter in order and complete in order.

## Hazards

EX/MEM forwarding has priority over MEM/WB forwarding because it contains the
newer result. The same forwarded values are used for ALU inputs, branch
comparisons, and store data.

The register file also returns the current writeback value when a read and write
use the same address. Writes to x0 are ignored and reads from x0 always return
zero.

A load followed immediately by an instruction that uses its destination inserts
one bubble. PC and IF/ID are held while older instructions continue. The current
detector compares raw rs1/rs2 fields, so a few instructions can stall even when
one field is not an actual source. That is harmless functionally but costs a
cycle.

Branches and jumps are resolved in EX. A taken transfer redirects the PC and
clears the two younger instructions. JAL and JALR write PC+4; JALR clears bit
zero of the target.

## Memory interface

Instruction and data reads are combinational. Stores happen on a rising clock
edge and use four byte enables. This keeps the first implementation simple, but
it is not the right interface for a larger synchronous FPGA block RAM.

Loads support LB, LBU, LH, LHU, and LW. Stores support SB, SH, and SW.
Halfword and word accesses are expected to be naturally aligned. Misaligned
accesses and bus faults do not raise exceptions.

The FPGA SoC uses 4 KiB of unified RAM. The CPU testbench uses a separate 16 KiB
model so it can reserve a TOHOST address for pass/fail reporting.

## SoC peripherals

`soc_top` adds:

- UART transmitter
- UART receiver with a two-flop input synchronizer
- 16-byte receive FIFO
- Sticky overrun and framing-error flags
- Three-bit LED output register
- Four-cycle sampled reset input

UART is configured for 115200 baud at a 27 MHz input clock. Integer clock
division gives 234 clocks per bit, or about 115384.6 baud.

## Software flow

The monitor occupies the lower 2 KiB of RAM. An uploaded application uses
`0x800..0xdff`, with the last 512 bytes reserved for stack. Startup code sets
SP, clears BSS, calls `main`, and loops if `main` returns.

Applications are compiled on the PC for `rv32i/ilp32`. The build converts the
binary to hexadecimal words and wraps it in a small UART command stream. The
monitor checks the range and a 32-bit additive checksum before jumping to it.

This is a development loader for trusted images, not a secure boot mechanism.

## ISA scope

Implemented instructions:

- LUI, AUIPC
- ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
- ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
- LB, LBU, LH, LHU, LW, SB, SH, SW
- BEQ, BNE, BLT, BGE, BLTU, BGEU
- JAL, JALR

Not implemented: FENCE, ECALL/EBREAK traps, CSRs, exceptions, interrupts,
privileged modes, compressed instructions, atomics, floating point, vectors,
or RV32M multiply/divide instructions.

The decoder does not yet reject every reserved encoding. Software should be
compiled with `-march=rv32i -mabi=ilp32`.
