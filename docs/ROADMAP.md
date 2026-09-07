# Roadmap

## Done

- Five-stage RV32I pipeline
- Forwarding, load-use stall, and branch recovery
- Byte, halfword, and word memory operations
- UART TX/RX with a receive FIFO
- Bare-metal C startup and linker scripts
- Checksummed UART application loader
- Directed and seeded simulation regression
- Compiled hello and echo applications tested over the serial pins
- GitHub Actions verification workflow

## Next

1. Complete FPGA placement and routing with the SSPI reset-pin setting.
2. Replace the asynchronous SoC RAM interface with synchronous block RAM.
3. Add a retirement-valid trace and compare against an independent ISA model.
4. Tighten instruction legality and define alignment/exception behavior.
5. Capture a physical UART/LED board demo tied to a commit.

## RV32M

Add MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, and REMU using a multi-cycle unit
and a pipeline stall handshake. Tests need to cover signed/unsigned high
products, division by zero, minimum signed integer divided by -1, and dependent
instructions on both sides of the unit.

The compiler stays at `-march=rv32i` until all RV32M operations pass.

## AXI accelerator

After the memory interface is stable, add an AXI4-Lite control block and a small
signed INT8 dot-product engine. The first version should use local buffers and
compare every output against a C reference. DMA and external DDR come later.

Measurements should separate compute, transfer, and software overhead. Report
FPGA frequency only from a routed timing result for the same source revision.
