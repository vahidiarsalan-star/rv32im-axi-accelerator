# Simulation flow for the RV32I core (Icarus Verilog).
#   make        -> generate program.hex, compile, and run the self-checking test
#   make wave   -> same, and leave tb_top.vcd for GTKWave
#   make clean  -> remove build artifacts
#
# Requires: iverilog + vvp on PATH, and a Python 3 interpreter.
# (program.hex is produced/validated by the golden ISS in gen_test.py.)

RTL    := ../rtl
PYTHON ?= python
SRCS   := $(RTL)/alu.v $(RTL)/decoder.v $(RTL)/regfile.v $(RTL)/rv32i_core.v \
          sim_memory.v tb_top.v
C_SRCS := $(RTL)/alu.v $(RTL)/decoder.v $(RTL)/regfile.v $(RTL)/rv32i_core.v \
          tb_c_firmware.v
MONITOR_SRCS := $(RTL)/alu.v $(RTL)/decoder.v $(RTL)/regfile.v $(RTL)/rv32i_core.v \
                $(RTL)/uart_tx.v $(RTL)/uart_rx.v $(RTL)/soc_top.v tb_uart_monitor.v

.PHONY: all run cfirmware monitor wave clean

all: run

program.hex: gen_test.py
	$(PYTHON) gen_test.py

tb_top.out: $(SRCS) $(RTL)/riscv_defs.vh
	iverilog -g2012 -I $(RTL) -o $@ $(SRCS)

run: program.hex tb_top.out
	vvp tb_top.out

tb_c_firmware.out: $(C_SRCS) $(RTL)/riscv_defs.vh firmware.hex
	iverilog -g2012 -I $(RTL) -o $@ $(C_SRCS)

cfirmware: tb_c_firmware.out
	vvp tb_c_firmware.out

tb_uart_monitor.out: $(MONITOR_SRCS) $(RTL)/riscv_defs.vh uart_test_tasks.vh monitor.hex
	iverilog -g2012 -I $(RTL) -I . -s tb_uart_monitor -o $@ $(MONITOR_SRCS)

monitor: tb_uart_monitor.out
	vvp tb_uart_monitor.out

wave: program.hex tb_top.out
	vvp tb_top.out +WAVES
	@echo "Open tb_top.vcd in GTKWave to inspect the pipeline."

clean:
	rm -f tb_top.out tb_c_firmware.out tb_uart_monitor.out tb_top.vcd program.hex
