# FPGA implementation and board bring-up

## Checked-in target

- Sipeed Tang Primer 20K with Dock; Gowin GW2A-LV18PG256C8/I7.
- `soc_top` is the top module; 27 MHz input clock with no PLL instantiated.
- [Gowin project](../gowin/riscv_pipeline20.gprj),
  [pin constraints](../gowin/tangprimer20k.cst), and
  [clock constraint](../gowin/tangprimer20k.sdc).

| Signal | Package pin | RTL / constraint intent |
| --- | --- | --- |
| `clk` | H11 | 27 MHz input |
| `rst_n_btn` | T10 | Active-low button, pull-up; shared SSPI pin |
| `uart_tx_pin` | M11 | Serial TX toward USB-UART bridge |
| `uart_rx_pin` | T13 | Serial RX from bridge, pull-up |
| `led[0:2]` | N16, N14, L14 | Three output bits |

These pin assignments come from the existing project constraints. Confirm the
board revision, Dock schematic, voltage banks, and polarity before programming.

## Rebuild procedure

1. Run `python sim/run_tests.py` and retain its source digest and logs.
2. Run `python sw/build.py --target monitor --update-board-image` to explicitly
   regenerate `gowin/firmware.hex` for the selected toolchain.
3. Open the `.gprj`, select `soc_top`, and confirm the exact target part.
4. In Place & Route configuration, enable **Use SSPI as regular IO** for T10.
   Machine-specific `.gprj.user` and generated `impl/` state are intentionally
   excluded; apply this setting in a fresh project environment.
5. Synthesize, inspect inferred memories and warnings, then place and route.
   The SDC declares a 37.037 ns clock period; that constraint is a target, not
   evidence that timing has closed.
6. Before treating the result as deployable, review fit, clock paths,
   unconstrained paths, input/reset synchronization, and setup/hold results.
7. Program the board and capture a reset-to-monitor terminal session at
   115200 baud, 8N1, no flow control. Upload hello, check 49/25/tick and LEDs,
   then reset, upload echo, and confirm bidirectional traffic.

Do not treat a successfully synthesized netlist as proof of a working board.
The current asynchronous RAM interface may consume substantial register/mux
resources; measure mapping rather than assuming BSRAM inference.

## Historical implementation evidence

The original project contained a Gowin V1.9.11.03 Education run dated
2026-08-01. Synthesis generated a netlist. Placement then stopped with PR2028
and PR2017 because `rst_n_btn` used a dedicated SSPI location. Its source list
predates the current RX-enabled SoC, so its utilization cannot be attributed
to this revision.

[Archived excerpt](evidence/gowin-2026-08-01.md) preserves the relevant errors
with source filenames and checksums. There is no current successful routed
report, verified Fmax, power measurement, or physical-board capture in this
repository. Those are acceptance criteria for the next milestone.

## Evidence to capture for the next revision

Record commit/source digest, board revision, Gowin version/part/options, clock
constraints, synthesis and routed utilization, worst setup/hold slack, and
unconstrained path review. Include a terminal transcript and a board photo or
logic-analyzer capture tied to that build. Do not combine resource numbers from
one netlist with functional claims from another.
