# Simulation and regression

Recommended command from the repository root:

```sh
python sim/run_tests.py
```

Use `--rtl-only` without GCC and `--waves` for CPU VCD files. All generated
images, executables, logs and `summary.json` go under `build/verification/`.
The runner builds from source and rejects nonzero exits, missing pass markers,
and timeouts. Two intentional-failure checks verify this behavior.

| File | Role |
| --- | --- |
| [gen_test.py](gen_test.py) | Original assembler, selected-ISA interpreter, baseline program |
| [gen_regression.py](gen_regression.py) | Directed cases and deterministic ALU streams |
| [tb_top.v](tb_top.v) | CPU harness, TOHOST checks, optional traces and event counters |
| [sim_memory.v](sim_memory.v) | 16 KiB two-read-path test memory |
| [tb_uart.v](tb_uart.v) | All UART byte values, false start and framing checks |
| [uart_test_tasks.vh](uart_test_tasks.vh) | Serial stimulus and independent TX pin sampling |
| [tb_uart_monitor.v](tb_uart_monitor.v) | Loader rejection/acceptance, RAM and serial output |
| [tb_uart_application.v](tb_uart_application.v) | Fresh C applications uploaded and exercised over serial |
| [tb_c_firmware.v](tb_c_firmware.v) | Standalone C execution smoke test with always-ready MMIO |

The original `run_sim.ps1` and Makefile remain for the baseline flow. Run them
inside `sim/`. `make wave` enables the baseline VCD. `make monitor` expects a
monitor image built first; the root regression is the complete automatic flow.

See [verification](../docs/VERIFICATION.md) for test scope and untested areas;
[results](../docs/RESULTS.md) contains a recorded run.
