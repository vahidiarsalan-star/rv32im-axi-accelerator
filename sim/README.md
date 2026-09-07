# Simulation

Run the full regression from the repository root:

```sh
python sim/run_tests.py
```

Useful options:

```sh
python sim/run_tests.py --rtl-only
python sim/run_tests.py --waves
```

Generated files go to `build/verification/`.

| File | Purpose |
| --- | --- |
| [run_tests.py](run_tests.py) | Main build and test runner |
| [gen_test.py](gen_test.py) | Small assembler, interpreter, and baseline program |
| [gen_regression.py](gen_regression.py) | Directed and seeded CPU programs |
| [tb_top.v](tb_top.v) | CPU pass/fail harness |
| [tb_uart.v](tb_uart.v) | UART byte and framing tests |
| [tb_uart_monitor.v](tb_uart_monitor.v) | Monitor protocol and upload test |
| [tb_uart_application.v](tb_uart_application.v) | Hello and echo application tests |
| [tb_c_firmware.v](tb_c_firmware.v) | Standalone C smoke test |

See [docs/VERIFICATION.md](../docs/VERIFICATION.md) for the coverage and known gaps.
