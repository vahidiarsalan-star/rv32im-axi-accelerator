# Gowin FPGA project

Open [riscv_pipeline20.gprj](riscv_pipeline20.gprj) in Gowin EDA and select
`soc_top` as the top module. The project targets GW2A-LV18PG256C8/I7.

- [tangprimer20k.cst](tangprimer20k.cst): package pins and I/O settings
- [tangprimer20k.sdc](tangprimer20k.sdc): 27 MHz clock constraint
- `firmware.hex`: monitor image loaded into SoC RAM

Rebuild the monitor image with:

```sh
python sw/build.py --target monitor --update-board-image
```

Reset uses T10, which is also an SSPI pin. Enable **Use SSPI as regular IO**
in Place & Route settings. See [docs/FPGA_BRINGUP.md](../docs/FPGA_BRINGUP.md)
for the current build status.
