# RV32I UART monitor and C uploads

The FPGA boots a resident monitor from the lower 2 KiB of its 4 KiB RAM. The
monitor receives checksummed RV32I words through UART, writes them to the
application region, and jumps to the validated entry point.

## UART MMIO

| Address | Access | Meaning |
|---|---|---|
| `0x80000000` | write | Transmit low byte |
| `0x80000000` | read | Read and pop oldest RX FIFO byte |
| `0x80000004` | read | UART status bits |
| `0x80000008` | write | Three LED bits |

UART status is bit 0 TX busy, bit 1 RX byte available, bit 2 RX FIFO full,
bit 3 RX overrun, and bit 4 RX framing error. The RX FIFO holds 16 bytes.

## First-time monitor build and FPGA programming

```powershell
cd C:\Users\vahid\Downloads\fpga_riscv\fpga_riscv\sw
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

This compiles `crt0.S + uart.c + monitor.c` and updates
`gowin\firmware.hex`. Rebuild the Gowin project and program the FPGA. This
step is only needed again when the RTL or monitor changes.

The Dock key uses T10, a dual-purpose SSPI pin. In Gowin, enable **Project ->
Configuration -> Place & Route -> Dual-Purpose Pin -> Use SSPI as regular IO**
before Place & Route. The checked-in process configuration already records
this setting.

Open Tera Term at **115200 baud, 8 data bits, no parity, 1 stop bit, no flow
control**. Enable local echo if you want to see what you type; the monitor
does not echo received bytes. A successful boot displays:

```text
RV32I UART monitor
L addr words sum + 8-hex words
D addr words | G addr | H
App: 00000800..00000DFF
>
```

Resetting the board always returns to the monitor.

## Compile and run a C program

Raw C text cannot execute directly on the RV32I core: C needs a compiler, and
the 4 KiB SoC does not have room for one. Compile C on the PC, then use Tera
Term to transport the resulting RV32I machine words:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_app.ps1 `
  -Source .\hello.c -OutputName hello_upload
```

The application is linked at `0x00000800`. In Tera Term choose **File -> Send
File**, select `sw\build\hello_upload.uart`, and send it as text with no line
delay. The file contains the load command, checksummed words, and final go
command. The monitor prints `OK ... WORDS`, then `GO 00000800`; the uploaded
program starts immediately.

To test receive from an uploaded C application instead, build `echo.c`:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_app.ps1 `
  -Source .\echo.c -OutputName echo_upload
```

Send `build\echo_upload.uart`, then type in Tera Term; the application reads
each byte with `uart_getc()` and transmits it back.

Application code and static data must fit in `0x800..0xDFF` (1536 bytes).
`0xE00..0xFFF` is reserved for the downward-growing stack. `build_app.ps1`
fails at link time if the static image is too large. Uploaded programs own the
CPU and do not return to the monitor; press reset when finished.

## Enter machine code manually

`L` takes a start address, hexadecimal word count, and 32-bit additive
checksum. It then consumes exactly that many eight-digit hexadecimal words.
For example, this program waits for TX idle, prints `!`, and loops:

```text
L 00000800 00000007 810bdb55
800002b7
0042a303
00137313
fe031ce3
02100513
00a2a023
0000006f
G 00000800
```

The monitor enables `G` only after a valid load and matching checksum. Use
`D 00000800 7` to dump seven words. Addresses, counts, words, and checksums are
hexadecimal.

## Verify in simulation

```powershell
cd ..\sim
powershell -ExecutionPolicy Bypass -File .\run_monitor_sim.ps1
```

The test serializes every input bit through `uart_rx`, loads and checks a small
program, executes it, and passes only when that program transmits `!`.
