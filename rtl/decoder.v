`include "riscv_defs.vh"

// Combinational instruction decoder: produces immediate + all control signals.
module decoder (
    input  wire [31:0] inst,
    output reg  [31:0] imm,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,
    output reg  [3:0]  alu_op,
    output reg         alu_src_a,  // ASRC_RS1 / ASRC_PC
    output reg         alu_src_b,  // BSRC_RS2 / BSRC_IMM
    output reg  [1:0]  wb_sel,     // WB_ALU / WB_MEM / WB_PC4
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg         is_branch,
    output reg         is_jal,
    output reg         is_jalr,
    output wire [2:0]  funct3,
    output wire        illegal
);
    wire [6:0] opcode = inst[6:0];
    wire [6:0] funct7 = inst[31:25];
    assign funct3 = inst[14:12];
    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    assign rd  = inst[11:7];

    // Immediate generation
    wire [31:0] i_imm = {{20{inst[31]}}, inst[31:20]};
    wire [31:0] s_imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    wire [31:0] b_imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
    wire [31:0] u_imm = {inst[31:12], 12'b0};
    wire [31:0] j_imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

    reg illegal_r;
    assign illegal = illegal_r;

    always @(*) begin
        // defaults
        imm       = i_imm;
        alu_op    = `ALU_ADD;
        alu_src_a = `ASRC_RS1;
        alu_src_b = `BSRC_IMM;
        wb_sel    = `WB_ALU;
        reg_write = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        is_branch = 1'b0;
        is_jal    = 1'b0;
        is_jalr   = 1'b0;
        illegal_r = 1'b0;

        case (opcode)
            `OP_LUI: begin
                imm = u_imm; alu_op = `ALU_BSEL; alu_src_b = `BSRC_IMM;
                reg_write = 1'b1; wb_sel = `WB_ALU;
            end
            `OP_AUIPC: begin
                imm = u_imm; alu_op = `ALU_ADD;
                alu_src_a = `ASRC_PC; alu_src_b = `BSRC_IMM;
                reg_write = 1'b1; wb_sel = `WB_ALU;
            end
            `OP_JAL: begin
                imm = j_imm; is_jal = 1'b1;
                reg_write = 1'b1; wb_sel = `WB_PC4;
            end
            `OP_JALR: begin
                imm = i_imm; is_jalr = 1'b1;
                reg_write = 1'b1; wb_sel = `WB_PC4;
            end
            `OP_BRANCH: begin
                imm = b_imm; is_branch = 1'b1;
                alu_src_b = `BSRC_RS2; alu_op = `ALU_SUB; // compare via subtract/flags
            end
            `OP_LOAD: begin
                imm = i_imm; alu_op = `ALU_ADD; alu_src_b = `BSRC_IMM;
                mem_read = 1'b1; reg_write = 1'b1; wb_sel = `WB_MEM;
            end
            `OP_STORE: begin
                imm = s_imm; alu_op = `ALU_ADD; alu_src_b = `BSRC_IMM;
                mem_write = 1'b1;
            end
            `OP_IMM: begin
                imm = i_imm; alu_src_b = `BSRC_IMM;
                reg_write = 1'b1; wb_sel = `WB_ALU;
                case (funct3)
                    3'b000: alu_op = `ALU_ADD;                    // ADDI
                    3'b010: alu_op = `ALU_SLT;                    // SLTI
                    3'b011: alu_op = `ALU_SLTU;                   // SLTIU
                    3'b100: alu_op = `ALU_XOR;                    // XORI
                    3'b110: alu_op = `ALU_OR;                     // ORI
                    3'b111: alu_op = `ALU_AND;                    // ANDI
                    3'b001: alu_op = `ALU_SLL;                    // SLLI
                    3'b101: alu_op = funct7[5] ? `ALU_SRA : `ALU_SRL; // SRAI/SRLI
                    default: alu_op = `ALU_ADD;
                endcase
            end
            `OP_REG: begin
                alu_src_b = `BSRC_RS2;
                reg_write = 1'b1; wb_sel = `WB_ALU;
                case (funct3)
                    3'b000: alu_op = funct7[5] ? `ALU_SUB : `ALU_ADD; // SUB/ADD
                    3'b001: alu_op = `ALU_SLL;
                    3'b010: alu_op = `ALU_SLT;
                    3'b011: alu_op = `ALU_SLTU;
                    3'b100: alu_op = `ALU_XOR;
                    3'b101: alu_op = funct7[5] ? `ALU_SRA : `ALU_SRL;
                    3'b110: alu_op = `ALU_OR;
                    3'b111: alu_op = `ALU_AND;
                    default: alu_op = `ALU_ADD;
                endcase
            end
            default: begin
                illegal_r = 1'b1;
            end
        endcase
    end
endmodule
