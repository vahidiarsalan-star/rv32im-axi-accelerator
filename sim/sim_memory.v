// Simple unified memory model for simulation.
// Async read on both ports (instruction + data), sync byte-write on data port.
// Word-addressable internally; byte enables handled for stores.
module sim_memory #(
    parameter WORDS   = 4096,               // 16 KB
    parameter ADDR_W  = 32
)(
    input  wire              clk,
    // instruction read port
    input  wire [ADDR_W-1:0] imem_addr,
    output wire [31:0]       imem_rdata,
    // data port
    input  wire [ADDR_W-1:0] dmem_addr,
    input  wire [3:0]        dmem_be,
    input  wire              dmem_we,
    input  wire [31:0]       dmem_wdata,
    output wire [31:0]       dmem_rdata
);
    reg [31:0] mem [0:WORDS-1];

    localparam IDX = $clog2(WORDS);
    wire [IDX-1:0] iw = imem_addr[IDX+1:2];
    wire [IDX-1:0] dw = dmem_addr[IDX+1:2];

    assign imem_rdata = mem[iw];
    assign dmem_rdata = mem[dw];

    // Synchronous, byte-addressable write on the data port.
    always @(posedge clk) begin
        if (dmem_we) begin
            if (dmem_be[0]) mem[dw][7:0]   <= dmem_wdata[7:0];
            if (dmem_be[1]) mem[dw][15:8]  <= dmem_wdata[15:8];
            if (dmem_be[2]) mem[dw][23:16] <= dmem_wdata[23:16];
            if (dmem_be[3]) mem[dw][31:24] <= dmem_wdata[31:24];
        end
    end
endmodule
