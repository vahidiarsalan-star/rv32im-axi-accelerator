// Simple 8N1 UART receiver.
//
// rx_valid and frame_error are one-clock pulses.  The caller must buffer
// rx_data when rx_valid is asserted; soc_top places received bytes in a FIFO.
module uart_rx #(
    parameter CLK_HZ = 27_000_000,
    parameter BAUD   = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        frame_error
);
    localparam integer DIVISOR   = CLK_HZ / BAUD;
    localparam integer HALF_TICK = DIVISOR / 2;

    // Protect the receiver state machine from an asynchronous input.
    reg rx_meta;
    reg rx_sync;

    reg        active;
    reg [3:0]  bit_idx;  // 0=start, 1..8=data, 9=stop
    reg [15:0] clkcnt;
    reg [7:0]  shifter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data     <= 8'b0;
            rx_valid    <= 1'b0;
            frame_error <= 1'b0;
            active      <= 1'b0;
            bit_idx     <= 4'd0;
            clkcnt      <= 16'd0;
            shifter     <= 8'b0;
        end else begin
            rx_valid    <= 1'b0;
            frame_error <= 1'b0;

            if (!active) begin
                // A low level may be a start bit.  Validate it again at its
                // center before accepting any data bits.
                if (!rx_sync) begin
                    active  <= 1'b1;
                    bit_idx <= 4'd0;
                    clkcnt  <= HALF_TICK - 1;
                end
            end else if (clkcnt != 0) begin
                clkcnt <= clkcnt - 16'd1;
            end else begin
                if (bit_idx == 4'd0) begin
                    if (!rx_sync) begin
                        bit_idx <= 4'd1;
                        clkcnt  <= DIVISOR - 1;
                    end else begin
                        // The line returned high: this was a false start.
                        active <= 1'b0;
                    end
                end else if (bit_idx <= 4'd8) begin
                    shifter[bit_idx-1] <= rx_sync;
                    bit_idx <= bit_idx + 4'd1;
                    clkcnt  <= DIVISOR - 1;
                end else begin
                    active <= 1'b0;
                    if (rx_sync) begin
                        rx_data  <= shifter;
                        rx_valid <= 1'b1;
                    end else begin
                        frame_error <= 1'b1;
                    end
                end
            end
        end
    end
endmodule
