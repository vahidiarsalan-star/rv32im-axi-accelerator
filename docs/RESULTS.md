# Test results

Latest local run: **2026-09-07**

```text
19 checks passed
Python 3.14.6
Icarus Verilog 13.0
riscv32-unknown-elf GCC 14.2.0
```

## CPU tests

| Program | Image words | Cycles | Load-stall cycles | Redirects |
| --- | ---: | ---: | ---: | ---: |
| Baseline | 194 | 202 | 1 | 6 |
| Hazards | 73 | 76 | 3 | 2 |
| Memory lanes | 149 | 149 | 0 | 1 |
| Control flow | 135 | 143 | 0 | 10 |
| Immediate edges | 231 | 231 | 0 | 1 |
| Six seeded ALU tests | 245 each | 245 each | 0 | 1 each |

These are testbench cycle counts, not CPI measurements. The programs contain
checks and some instructions that are skipped by branches.

## Firmware size

| Image | Binary size |
| --- | ---: |
| Resident monitor | 1930 bytes + 12 bytes BSS |
| Hello application | 615 bytes |
| Echo application | 327 bytes |

The monitor has 2048 bytes for code and static data. Uploaded applications have
1536 bytes plus a separate 512-byte stack area.

## Serial demo

```text
> ERR NO IMAGE
> ERR RANGE
> ERR SUM 00000013
> OK 00000006 WORDS
> GO 00000800
!
*** UART MONITOR PASS ***
```

```text
> OK 0000009A WORDS
> GO 00000800
RV32I C arithmetic demo
37 + 12 = 49
37 - 12 = 25
tick
*** UART HELLO APP PASS ***
```

The testbench decodes these bytes from the simulated TX pin. FPGA timing and
physical-board results are still pending.
