# AXI / INT8 accelerator proposal — not implemented

This is an interface-design sketch for a future milestone. There is currently
no AXI RTL, MAC datapath, DMA engine, DDR controller, or accelerator benchmark.

## First bounded workload

Start with a signed INT8 dot product and signed 32-bit accumulation. Compare
every output against a software reference before optimizing throughput. For a
fixed bound of K <= 4096, the maximum sum of absolute product magnitudes is
4096 × 128 × 128 = 67,108,864, within signed 32-bit range. A larger bound,
bias addition, requantization, or accumulation across jobs needs an explicit
overflow/rounding contract.

Begin with CPU-populated local buffers. External-memory bandwidth and DMA are
separate milestones; adding them before a correct small engine would obscure
which subsystem causes a failure.

## Candidate control register map

The base address is intentionally not wired into the current SoC.

| Offset | Register | Proposed role |
| --- | --- | --- |
| `0x00` | CTRL | Start command; later interrupt enable if an interrupt path exists |
| `0x04` | STATUS | Busy, sticky done, error; clear semantics must be specified |
| `0x08` | SRC_A | Source A buffer address / index |
| `0x0c` | SRC_B | Source B buffer address / index |
| `0x10` | DST | Destination address / index |
| `0x14` | LEN | Element count with validated upper bound |
| `0x18` | MODE | Reserved for explicitly supported modes |

Snapshot parameters at accepted start. Specify whether writes while busy are
rejected or deferred. Define alignment, byte strobes, reset/abort behavior,
invalid ranges and sticky-status clearing before writing software drivers.

## AXI4-Lite verification obligations

- AW and W channels can arrive separately; buffer each and commit one register
  write only after both are accepted.
- Hold BVALID/RVALID and response payloads stable while the receiver is not ready.
- Produce exactly one response per accepted transaction; test independent
  channel stalls and back-to-back traffic.
- Apply WSTRB to writable bytes and return defined responses for invalid offsets.
- Define reset behavior for outstanding transactions and avoid duplicate start pulses.

The existing CPU has a zero-wait memory interface, so adding AXI also needs a
bridge and a CPU-side stall/response contract. Wiring addresses into an AXI
module without this contract is not a complete integration.

## Benchmark contract

Report software reference cycles, hardware compute cycles, transfer cycles,
launch/poll overhead, and total wall-clock latency on the same workload and
memory placement. State vector length, data type, accumulation rules and clock.
Speedup must include data movement if software performs it. Keep PPA results
tied to a routed source revision.
