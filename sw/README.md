# Firmware, C applications, and serial loading

The resident monitor runs in the lower 2 KiB of a 4 KiB SoC RAM. It receives
checksummed machine words, loads an application at `0x800`, and makes a one-way
jump into that image. The PC compiles C; the soft CPU executes the resulting
RV32I instructions.

## Portable build

From the repository root, with Python 3 and GNU bare-metal RISC-V GCC/binutils:

```sh
python sw/build.py
python sim/run_tests.py
```

The first command builds monitor, uploaded hello and echo, and a standalone
hello image into `sw/build/`. The regression builds its own fresh images in
`build/verification/`, so it does not rely on a stale checked-in binary.

`riscv32-unknown-elf-` and `riscv64-unknown-elf-` prefixes are detected; set
`RISCV_PREFIX` to select another compatible prefix. Both use RV32I/ILP32, no
standard library, and no implicit start files. Small-data addressing and linker
relaxation are disabled because startup does not initialize `gp`.

For an individual image or an intentional board-image update:

```sh
python sw/build.py --target hello
python sw/build.py --target monitor --update-board-image
```

The checked-in `gowin/firmware.hex` is a convenience boot image; rebuild it with
the chosen compiler before a new hardware run.

## Board demo

Follow [FPGA bring-up](../docs/FPGA_BRINGUP.md) to apply the pin/clock constraints
and SSPI-as-regular-IO option, rebuild the FPGA, and establish a valid routed
image. Physical-board validation is still an open milestone.

1. Open a serial terminal at **115200 baud, 8N1, no flow control**.
2. Reset the board and wait for `RV32I UART monitor` and the `>` prompt.
3. Send `sw/build/hello.uart` as a text file. It contains the load header, word
   payload, and `G 00000800` command.
4. Expect the arithmetic demo to print 49 and 25, then `tick`; the application
   also toggles the LED register.
5. Reset, send `sw/build/echo.uart`, and type text to exercise receive and transmit.

The simulation regression performs these software/RTL workflows through serial
pins. It does not replace the physical-board check above.

## Source map

| File | Purpose |
| --- | --- |
| [monitor.c](monitor.c) | L/D/G/H parser, range checks, checksum and jump |
| [uart.c](uart.c), [uart.h](uart.h) | Volatile MMIO polling and formatting without hardware division |
| [crt0.S](crt0.S), [crt0_app.S](crt0_app.S) | Stack initialization, BSS clearing, main entry |
| [link_monitor.ld](link_monitor.ld) | Monitor's 2 KiB allocation |
| [link_app.ld](link_app.ld) | 1536-byte application allocation; 512-byte stack budget |
| [link.ld](link.ld) | Standalone 4 KiB image for the C smoke test |
| [hello.c](hello.c), [echo.c](echo.c) | Arithmetic/LED and bidirectional UART examples |
| [build.py](build.py) | Portable compiler, binary, hex, upload and size workflow |

Application code, static data and BSS must fit below `0xe00`. Link-time checks
bound static allocation; they do not prove runtime stack usage fits. Avoid
division, floating point and library calls unless their runtime support is
explicitly supplied. Uploaded applications own the CPU; reset returns to the
resident monitor.

## Existing Windows scripts

The original `build.ps1` and `build_app.ps1` remain available. Run them from
`sw/` using PowerShell; for example:

```powershell
.\build_app.ps1 -Source .\hello.c -OutputName hello_upload
```

`build.ps1` updates `gowin/firmware.hex` and `sim/monitor.hex`.
`gen_firmware.py` is an earlier hand-assembled firmware generator and can
overwrite the board boot image; it is not used by the current regression.
`build_machine_sample.ps1` writes an inspectable hand-coded upload example.

See the [memory map and protocol](../docs/MEMORY_MAP.md) for exact registers,
address aliases, sticky flags and loader failure semantics.
