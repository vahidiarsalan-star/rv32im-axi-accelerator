// End-to-end test: serial bytes enter uart_rx, the resident C monitor loads
// four RV32I words into RAM, validates their checksum, and jumps to them.  The
// uploaded program writes '!' through the real UART TX MMIO path.
`timescale 1ns/1ps
module tb_uart_monitor;
    localparam integer UART_DIV = 10;

    reg clk = 1'b0;
    reg rst_n_btn = 1'b0;
    reg uart_rx_pin = 1'b1;
    wire uart_tx_pin;
    wire [2:0] led;

    always #5 clk = ~clk;

    soc_top #(
        .CLK_HZ(1_000_000),
        .BAUD(100_000),
        .RAMWORDS(1024),
        .MEM_FILE("monitor.hex")
    ) dut (
        .clk(clk),
        .rst_n_btn(rst_n_btn),
        .uart_rx_pin(uart_rx_pin),
        .uart_tx_pin(uart_tx_pin),
        .led(led)
    );

    task automatic send_byte(input [7:0] value);
        integer bit_number;
        begin
            @(negedge clk);
            uart_rx_pin = 1'b0;
            repeat (UART_DIV) @(posedge clk);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                @(negedge clk);
                uart_rx_pin = value[bit_number];
                repeat (UART_DIV) @(posedge clk);
            end
            @(negedge clk);
            uart_rx_pin = 1'b1;
            repeat (UART_DIV) @(posedge clk);
        end
    endtask

    task automatic send_text(input string value);
        integer index;
        begin
            for (index = 0; index < value.len(); index = index + 1)
                send_byte(value[index]);
        end
    endtask

    reg saw_prompt = 1'b0;
    reg saw_bang = 1'b0;
    always @(posedge clk) begin
        // Every firmware UART write is accepted only after it observes !busy.
        if (dut.uart_wr && !dut.uart_busy) begin
            $write("%c", dut.dmem_wdata[7:0]);
            if (dut.dmem_wdata[7:0] == ">") saw_prompt <= 1'b1;
            if (dut.dmem_wdata[7:0] == "!") saw_bang <= 1'b1;
        end
    end

    initial begin
        repeat (8) @(posedge clk);
        rst_n_btn = 1'b1;

        wait (saw_prompt);
        // Uploaded image at 0x800:
        //   lui t0,0x80000; wait: lw t1,4(t0); bnez t1,wait
        //   addi a0,zero,'!'; sw a0,0(t0); j .
        // The G command is sent in the same uninterrupted stream, exercising
        // the RX FIFO while the monitor prints its OK response.
        send_text("L 00000800 00000006 80f86a42\n");
        send_text("800002b7\n0042a303\nfe031ee3\n02100513\n00a2a023\n0000006f\n");
        send_text("G 00000800\n");

        wait (saw_bang);
        if (dut.ram[12'h200] !== 32'h800002b7 ||
            dut.ram[12'h201] !== 32'h0042a303 ||
            dut.ram[12'h202] !== 32'hfe031ee3 ||
            dut.ram[12'h203] !== 32'h02100513 ||
            dut.ram[12'h204] !== 32'h00a2a023 ||
            dut.ram[12'h205] !== 32'h0000006f) begin
            $display("\n*** UART MONITOR RAM MISMATCH ***");
            $fatal(1);
        end
        $display("\n*** UART MONITOR PASS ***");
        $finish;
    end

    integer cycles = 0;
    always @(posedge clk) begin
        cycles = cycles + 1;
        if (cycles > 500000) begin
            $display("\n*** UART MONITOR TIMEOUT ***");
            $fatal(1);
        end
    end
endmodule
