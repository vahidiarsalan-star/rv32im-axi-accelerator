# Memory map and software contract

## SoC address map

| Address / region | Size | Access and side effects |
| --- | --- | --- |
| `0x00000000..0x000007ff` | 2048 bytes | Resident monitor code, constants, data, BSS |
| `0x00000800..0x00000dff` | 1536 bytes | Uploaded application's code/static data/BSS |
| `0x00000e00..0x00000fff` | 512 bytes | Stack budget; initial SP = `0x1000` |
| `0x80000000` | 32-bit register | Write low byte to TX if idle; read pops one RX byte if available |
| `0x80000004` | 32-bit register | Read UART status; no clear-on-read behavior |
| `0x80000008` | 3-bit output | Write LED bits; reading returns zero |

UART status: bit 0 TX busy, bit 1 RX nonempty, bit 2 RX full, bit 3 sticky RX
overrun, bit 4 sticky framing error; upper bits are zero. Poll bit 1 before
reading data: an empty FIFO read has no useful data contract. A TX write while
busy is dropped. Use aligned 32-bit MMIO accesses as in [uart.c](../sw/uart.c).

**Decode boundary:** `dmem_addr[31]` distinguishes RAM from MMIO. RAM uses only
the low word-index bits, so low-half addresses outside 4 KiB alias into RAM.
MMIO compares only the low address byte, so registers alias in the upper half.
Instruction fetch also indexes RAM directly. These are implementation facts,
not reserved address windows enforced by hardware.

The CPU-only testbench uses a separate 16 KiB model with scratch at `0x800` and
TOHOST at `0x1000`; TOHOST is **not** an FPGA peripheral. A value of 1 means
success, and any other value is the direct failing-test ID.

## Startup and image format

Startup sets SP, clears BSS by word stores, calls `main`, and loops if `main`
returns. Code and initialized data are already in RAM; no ROM-to-RAM copy is
needed. Link scripts bound static image use but do not measure stack high-water
or enforce stack isolation at runtime. The portable compiler flags disable
small-data addressing and linker relaxation because startup does not set `gp`.

Firmware `.hex` files have one 32-bit word per line. Four binary bytes are packed
little-endian into each word. Monitor images are padded to 1024 words with
`0x00000013` (ADDI x0,x0,0). UART application images use an ASCII transport:

```text
L 00000800 00000001 00000013
00000013
G 00000800
```

This illustrates the format only: the one-word NOP image is not a useful program.
Use a generated `hello.uart` or `echo.uart` for the demo.

## Monitor commands

| Command | Contract |
| --- | --- |
| `L address count sum` then `count` words | Aligned nonempty image wholly inside the upload region; modulo-2^32 sum over words |
| `G address` | Requires a previously checksum-valid image and its exact start address; one-way jump |
| `D address count` | Dump aligned words wholly within 4 KiB RAM |
| `H` | Print command help |

All numeric inputs are hexadecimal. CR or LF terminates command lines. Each
payload word has eight hex digits. A new load first clears `image_valid`;
bad range, malformed input, or checksum mismatch keeps execution disabled.
Words are written as they arrive, so rejection does not roll back modified RAM.
The loader has no receive timeout; an incomplete payload waits for more bytes.

The checksum is not a signature, and the loader does not sandbox uploaded code.
This is a local development interface for trusted images. UART error status is
available to software, but the monitor does not implement robust stream
resynchronization or recovery on every framing/overflow condition.
