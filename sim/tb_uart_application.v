// Upload a compiled C application and check what it emits on the serial TX pin.
`timescale 1ns/1ps
module tb_uart_application;
    localparam integer UART_DIV = 10;
    reg clk = 0, rst_n_btn = 0, uart_rx_pin = 1;
    wire uart_tx_pin;
    wire [2:0] led;
    always #5 clk = ~clk;
    soc_top #(.CLK_HZ(100_000_000), .BAUD(10_000_000), .RAMWORDS(1024),
              .MEM_FILE("monitor.hex")) dut (.*);
    `include "uart_test_tasks.vh"
    reg [7:0] upload_bytes [0:8191];
    integer byte_count, index;
    reg [1023:0] upload_file;
    reg saw_sum = 0, saw_difference = 0;
    always @(negedge clk) begin
        if (response_matches(transcript_tail, "37 + 12 = 49\015\n")) saw_sum = 1;
        if (response_matches(transcript_tail, "37 - 12 = 25\015\n")) saw_difference = 1;
    end
    initial begin
        if (!$value$plusargs("UPLOAD=%s", upload_file) ||
            !$value$plusargs("BYTES=%d", byte_count)) $fatal(1, "Missing upload arguments");
        if (byte_count <= 0 || byte_count > 8192) $fatal(1, "Invalid upload length");
        $readmemh(upload_file, upload_bytes, 0, byte_count - 1);
        repeat (8) @(negedge clk); rst_n_btn = 1;
        wait (prompt_count == 1);
        repeat (2*UART_DIV) @(negedge clk);
        for (index = 0; index < byte_count; index = index + 1) send_byte(upload_bytes[index]);
        if ($test$plusargs("ECHO")) begin
            wait (response_matches(transcript_tail, "GO 00000800\015\n"));
            repeat (2000) @(negedge clk);
            send_text("Echo OK!\015\n");
            wait (response_matches(transcript_tail, "Echo OK!\015\n"));
            $display("\n*** UART ECHO APP PASS ***");
        end else begin
            wait (saw_sum && saw_difference && response_matches(transcript_tail, "tick\015\n"));
            $display("\n*** UART HELLO APP PASS ***");
        end
        $finish;
    end
    initial begin
        repeat (2000000) @(posedge clk);
        $fatal(1, "UART APPLICATION TIMEOUT");
    end
endmodule
