// Receiver false-start/framing checks plus all 256 byte values via TX loopback.
`timescale 1ns/1ps
module tb_uart;
    parameter integer DIV = 10;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    reg tx_start = 0;
    reg [7:0] tx_data = 0;
    wire tx, busy;
    reg manual = 1, manual_rx = 1;
    wire rx = manual ? manual_rx : tx;
    wire [7:0] rx_data;
    wire rx_valid, frame_error;
    uart_tx #(.CLK_HZ(DIV*1000), .BAUD(1000)) transmitter (.*);
    uart_rx #(.CLK_HZ(DIV*1000), .BAUD(1000)) receiver (.*);
    integer received = 0, errors = 0, index;
    reg [7:0] expected;
    always @(posedge clk) begin
        if (rx_valid) begin
            if (manual) $fatal(1, "Malformed frame produced RX data");
            if (rx_data !== expected) $fatal(1, "UART byte mismatch");
            received = received + 1;
        end
        if (frame_error) errors = errors + 1;
    end
    initial begin
        repeat (4) @(negedge clk); rst_n = 1;
        // A short low pulse ends before start-bit center sampling.
        manual_rx = 0;
        repeat (DIV/4) @(negedge clk); manual_rx = 1;
        repeat (2*DIV) @(negedge clk);
        if (received != 0 || errors != 0) $fatal(1, "False start accepted");
        // One all-zero frame with a low stop bit.
        manual_rx = 0;
        repeat (10*DIV) @(negedge clk); manual_rx = 1;
        repeat (12*DIV) @(negedge clk);
        if (errors != 1 || received != 0) $fatal(1, "Framing error not detected exactly once");
        manual = 0;
        for (index = 0; index < 256; index = index + 1) begin
            expected = index;
            tx_data = index;
            tx_start = 1;
            @(negedge clk); tx_start = 0;
            wait (received == index + 1);
            wait (!busy);
            repeat (2*DIV) @(negedge clk);
        end
        if (errors != 1) $fatal(1, "Unexpected UART framing errors");
        $display("*** UART UNIT PASS *** (divisor=%0d bytes=%0d)", DIV, received);
        $finish;
    end
    initial begin
        repeat (1000000) @(posedge clk);
        $fatal(1, "UART UNIT TIMEOUT");
    end
endmodule
