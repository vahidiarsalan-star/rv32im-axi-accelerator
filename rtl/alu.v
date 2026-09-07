`include "riscv_defs.vh"

module alu (
    input  wire [3:0]  op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y,
    output wire        zero
);
    wire [4:0] shamt = b[4:0];
    always @(*) begin
        case (op)
            `ALU_ADD : y = a + b;
            `ALU_SUB : y = a - b;
            `ALU_SLL : y = a << shamt;
            `ALU_SLT : y = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            `ALU_SLTU: y = (a < b) ? 32'd1 : 32'd0;
            `ALU_XOR : y = a ^ b;
            `ALU_SRL : y = a >> shamt;
            `ALU_SRA : y = $signed(a) >>> shamt;
            `ALU_OR  : y = a | b;
            `ALU_AND : y = a & b;
            `ALU_BSEL: y = b;
            default  : y = 32'b0;
        endcase
    end
    assign zero = (y == 32'b0);
endmodule
