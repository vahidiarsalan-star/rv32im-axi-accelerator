// Board-style smoke test for the C firmware image.
// It supplies the RAM and MMIO used by soc_top, and passes when main() emits
// its first "tick\r\n" through the UART data register.
`timescale 1ns/1ps
module tb_c_firmware;
    reg clk = 1'b0, rst_n = 1'b0;
    always #5 clk = ~clk;

    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_be;
    wire        dmem_we, dmem_re;

    rv32i_core dut (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_be(dmem_be), .dmem_we(dmem_we),
        .dmem_re(dmem_re), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata)
    );

    reg [31:0] ram [0:4095];
    wire [11:0] iw = imem_addr[13:2];
    wire [11:0] dw = dmem_addr[13:2];
    assign imem_rdata = ram[iw];
    // Model UART as always ready; serial timing is covered by separate tests.
    assign dmem_rdata = (dmem_addr == 32'h8000_0004) ? 32'b0 : ram[dw];

    always @(posedge clk) begin
        if (dmem_we && !dmem_addr[31]) begin
            if (dmem_be[0]) ram[dw][7:0]   <= dmem_wdata[7:0];
            if (dmem_be[1]) ram[dw][15:8]  <= dmem_wdata[15:8];
            if (dmem_be[2]) ram[dw][23:16] <= dmem_wdata[23:16];
            if (dmem_be[3]) ram[dw][31:24] <= dmem_wdata[31:24];
        end
    end

    integer i;
    initial begin
        for (i = 0; i < 4096; i = i + 1) ram[i] = 32'h00000013;
        $readmemh("firmware.hex", ram, 0, 1023);
        repeat (4) @(negedge clk);
        rst_n = 1'b1;
    end

    reg [2:0] tick_state = 3'd0;
    always @(posedge clk) begin
        if (rst_n && dmem_we && dmem_addr == 32'h8000_0000) begin
            $write("%c", dmem_wdata[7:0]);
            case (tick_state)
                3'd0: tick_state <= (dmem_wdata[7:0] == "t") ? 3'd1 : 3'd0;
                3'd1: tick_state <= (dmem_wdata[7:0] == "i") ? 3'd2 : 3'd0;
                3'd2: tick_state <= (dmem_wdata[7:0] == "c") ? 3'd3 : 3'd0;
                3'd3: tick_state <= (dmem_wdata[7:0] == "k") ? 3'd4 : 3'd0;
                3'd4: tick_state <= (dmem_wdata[7:0] == 8'h0d) ? 3'd5 : 3'd0;
                default: if (dmem_wdata[7:0] == 8'h0a) begin
                    $display("\n*** C FIRMWARE PASS ***");
                    $finish;
                end else tick_state <= 3'd0;
            endcase
        end
    end

    integer cycles = 0;
    always @(posedge clk) begin
        if (rst_n) begin
            cycles = cycles + 1;
            if (cycles > 2000000) begin
                $display("*** C FIRMWARE TIMEOUT ***");
                $fatal(1);
            end
        end
    end
endmodule
