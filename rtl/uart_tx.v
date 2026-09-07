// Simple 8N1 UART transmitter.
// Parameterized by clock frequency and baud rate.
module uart_tx #(
    parameter CLK_HZ = 27_000_000,
    parameter BAUD   = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,   // pulse to begin sending tx_data
    input  wire [7:0] tx_data,
    output reg        tx,         // serial line (idle high)
    output wire       busy
);
    localparam integer DIVISOR = CLK_HZ / BAUD;

    reg [3:0]  bit_idx;
    reg [15:0] clkcnt;
    reg [9:0]  shifter;   // {stop(1), data(8), start(0)}
    reg        active;

    assign busy = active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx      <= 1'b1;
            active  <= 1'b0;
            bit_idx <= 4'd0;
            clkcnt  <= 16'd0;
            shifter <= 10'h3FF;
        end else if (!active) begin
            tx <= 1'b1;
            if (tx_start) begin
                shifter <= {1'b1, tx_data, 1'b0}; // stop, data LSB-first, start
                active  <= 1'b1;
                bit_idx <= 4'd0;
                clkcnt  <= 16'd0;
            end
        end else begin
            if (clkcnt == DIVISOR-1) begin
                clkcnt  <= 16'd0;
                tx      <= shifter[0];
                shifter <= {1'b1, shifter[9:1]};
                bit_idx <= bit_idx + 4'd1;
                if (bit_idx == 4'd9) active <= 1'b0; // 10 bits sent
            end else begin
                clkcnt <= clkcnt + 16'd1;
            end
        end
    end
endmodule
