# Tang Primer 20K FPGA target

Open [riscv_pipeline20.gprj](riscv_pipeline20.gprj) in Gowin EDA. It references
the shared `../rtl` sources and selects GW2A-LV18PG256C8/I7. Select `soc_top`
as the synthesis top.

[tangprimer20k.cst](tangprimer20k.cst) contains pins/IO settings;
[tangprimer20k.sdc](tangprimer20k.sdc) declares the 27 MHz input clock.
`firmware.hex` supplies the default monitor image. Rebuild it from source with:

```sh
python sw/build.py --target monitor --update-board-image
```

Set **Use SSPI as regular IO** for reset pin T10 in the Gowin project configuration.
Generated `impl/` and personal `.gprj.user` state are not committed, so a fresh
environment must apply this option. Preserve a report of chosen tool options
when recording a successful build.

Read the [bring-up guide](../docs/FPGA_BRINGUP.md) for the historical placement
failure, current RAM mapping concern, and the evidence needed for timing/board
claims. The project file alone does not establish FPGA fit or timing closure.
