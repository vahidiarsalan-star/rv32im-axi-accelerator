# FPGA status

Target board: Sipeed Tang Primer 20K with Dock
FPGA: Gowin GW2A-LV18PG256C8/I7
Input clock: 27 MHz

| Signal | Pin |
| --- | --- |
| Clock | H11 |
| Reset button | T10 |
| UART TX | M11 |
| UART RX | T13 |
| LEDs | N16, N14, L14 |

The Gowin project is [gowin/riscv_pipeline20.gprj](../gowin/riscv_pipeline20.gprj).
Before rebuilding, generate a fresh monitor image:

```sh
python sw/build.py --target monitor --update-board-image
```

T10 is a dedicated SSPI pin. In the Gowin Place & Route settings, enable
**Use SSPI as regular IO** before running placement.

The saved historical run synthesized but placement stopped with:

```text
ERROR (PR2028): The constrained location is useless in current package
ERROR (PR2017): 'rst_n_btn' cannot be placed according to constraint,
                for the location is a dedicated pin (SSPI)
```

That run used an older source list, so I am not using its resource numbers as
current results.

## Board bring-up checklist

1. Run the complete simulation regression.
2. Rebuild `gowin/firmware.hex`.
3. Confirm the exact device and `soc_top` as the top module.
4. Enable SSPI as regular I/O.
5. Run synthesis, placement, routing, and timing analysis.
6. Check inferred RAM, utilization, setup/hold slack, and unconstrained paths.
7. Program the board and open UART at 115200 8N1.
8. Upload hello and echo, then capture the terminal output.

There is no current routed timing result or physical-board demo in this
repository. The asynchronous RAM interface is the main FPGA implementation
risk; the next memory revision should use synchronous block RAM and a stall
handshake.
