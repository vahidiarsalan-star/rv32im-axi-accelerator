// 32x32 register file. x0 hardwired to 0.
// Two async read ports, one sync write port. Write-first (read returns
// newly written value in same cycle) to simplify WB->ID forwarding.
module regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata,
    input  wire [4:0]  raddr1,
    input  wire [4:0]  raddr2,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);
    reg [31:0] regs [0:31];
    integer i;
    initial for (i = 0; i < 32; i = i + 1) regs[i] = 32'b0;

    always @(posedge clk)
        if (we && waddr != 5'b0)
            regs[waddr] <= wdata;

    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 :
                    (we && (waddr == raddr1)) ? wdata : regs[raddr1];
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 :
                    (we && (waddr == raddr2)) ? wdata : regs[raddr2];
endmodule
