// Bit-serial RX -> C monitor -> RAM -> CPU -> bit-serial TX.
`timescale 1ns/1ps
module tb_uart_monitor;
    localparam integer UART_DIV = 10;
    reg clk = 0, rst_n_btn = 0, uart_rx_pin = 1;
    wire uart_tx_pin;
    wire [2:0] led;
    always #5 clk = ~clk;
    soc_top #(.CLK_HZ(100_000_000), .BAUD(10_000_000), .RAMWORDS(1024),
              .MEM_FILE("monitor.hex")) dut (.*);
    `include "uart_test_tasks.vh"

    initial begin
        repeat (8) @(negedge clk); rst_n_btn = 1;
        wait (prompt_count == 1);
        repeat (2*UART_DIV) @(negedge clk);
        send_text("G 00000800\n");
        wait (response_matches(transcript_tail, "ERR NO IMAGE\015\n"));
        wait (prompt_count == 2);
        send_text("L 00000000 00000001 00000013\n");
        wait (response_matches(transcript_tail, "ERR RANGE\015\n"));
        wait (prompt_count == 3);
        send_text("L 00000800 00000001 00000000\n00000013\n");
        wait (response_matches(transcript_tail, "ERR SUM 00000013\015\n"));
        wait (prompt_count == 4);
        send_text("G 00000800\n");
        wait (response_matches(transcript_tail, "ERR NO IMAGE\015\n"));
        wait (prompt_count == 5);
        send_text("L 00000800 00000006 80f86a42\n");
        send_text("800002b7\n0042a303\nfe031ee3\n02100513\n00a2a023\n0000006f\n");
        send_text("G 00000800\n");
        wait (transcript_tail[7:0] == "!");
        if (dut.ram[512] !== 32'h800002b7 || dut.ram[513] !== 32'h0042a303 ||
            dut.ram[514] !== 32'hfe031ee3 || dut.ram[515] !== 32'h02100513 ||
            dut.ram[516] !== 32'h00a2a023 || dut.ram[517] !== 32'h0000006f)
            $fatal(1, "Uploaded RAM image mismatch");
        $display("\n*** UART MONITOR PASS *** (negative commands + serial TX + RAM)");
        $finish;
    end
    initial begin
        repeat (1000000) @(posedge clk);
        $fatal(1, "UART MONITOR TIMEOUT");
    end
endmodule
