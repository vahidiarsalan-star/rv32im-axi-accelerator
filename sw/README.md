# Software

The PC compiles the firmware; the FPGA CPU runs the resulting RV32I machine
code. The build is freestanding: no operating system, libc, or default startup
files.

## Build

From the repository root:

```sh
python sw/build.py
```

The script finds a compatible GNU RISC-V toolchain and builds:

- `monitor`: resident UART loader
- `hello`: arithmetic and LED demo
- `echo`: UART receive/transmit demo
- `hello_standalone`: smoke-test image linked at reset address

Use `RISCV_PREFIX` to choose a different tool prefix.

```sh
python sw/build.py --target hello
python sw/build.py --target monitor --update-board-image
```

The second command intentionally updates `gowin/firmware.hex`.

## Upload an application

The monitor runs at 115200 baud, 8N1, no flow control. After reset it prints:

```text
RV32I UART monitor
L addr words sum + 8-hex words
D addr words | G addr | H
App: 00000800..00000DFF
>
```

Send `sw/build/hello.uart` as a text file. It contains the load command,
machine words, checksum, and final jump command. The expected output includes:

```text
OK 0000009A WORDS
GO 00000800
RV32I C arithmetic demo
37 + 12 = 49
37 - 12 = 25
tick
```

Reset the board before sending `echo.uart`. Uploaded applications do not
return to the monitor.

## Source files

| File | Purpose |
| --- | --- |
| [monitor.c](monitor.c) | Loader commands, range checks, checksum, and jump |
| [uart.c](uart.c) | Polling UART and number formatting |
| [crt0.S](crt0.S) | Monitor/standalone startup |
| [crt0_app.S](crt0_app.S) | Uploaded application startup |
| [link_monitor.ld](link_monitor.ld) | Lower 2 KiB monitor layout |
| [link_app.ld](link_app.ld) | 1536-byte application and 512-byte stack layout |
| [link.ld](link.ld) | Standalone 4 KiB layout |
| [hello.c](hello.c) | Arithmetic, UART, and LED demo |
| [echo.c](echo.c) | UART echo demo |
| [build.py](build.py) | Portable build and image conversion |

The linker checks static image size. It cannot prove runtime stack usage fits.
Compile with `-march=rv32i -mabi=ilp32`; RV32M is not implemented yet.

The older PowerShell build scripts are kept for Windows use. The main regression
uses `build.py` so the same flow runs locally and in GitHub Actions.
