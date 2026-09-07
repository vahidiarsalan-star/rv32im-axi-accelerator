# Memory map

## FPGA SoC

| Address | Use |
| --- | --- |
| `0x00000000..0x000007ff` | Resident monitor |
| `0x00000800..0x00000dff` | Uploaded application |
| `0x00000e00..0x00000fff` | Application stack |
| `0x80000000` | UART data: write TX, read and pop RX |
| `0x80000004` | UART status |
| `0x80000008` | LED output |

UART status bits:

| Bit | Meaning |
| ---: | --- |
| 0 | TX busy |
| 1 | RX data available |
| 2 | RX FIFO full |
| 3 | RX overrun, sticky until reset |
| 4 | RX framing error, sticky until reset |

Software must wait for TX idle before writing and RX ready before reading.

The current address decoder only checks address bit 31 for RAM versus MMIO and
uses the low index bits inside each region. Addresses outside the intended map
can therefore alias. This is acceptable for the current controlled firmware but
should be tightened before adding a bus.

## UART monitor protocol

All values are hexadecimal.

```text
L <address> <word-count> <checksum>
<8-digit word>
...
G <address>
```

`L` accepts an aligned, nonempty image that fits inside the application
region. The checksum is the 32-bit sum of every word. `G` only accepts the
start address of the last valid image.

Other commands:

- `D <address> <word-count>` dumps RAM.
- `H` prints help.

A failed load clears the valid-image flag. Words already received are not rolled
back. Uploaded code runs until reset.
