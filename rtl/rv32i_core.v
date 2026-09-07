`include "riscv_defs.vh"

// RV32I 5-stage pipeline: IF -> ID -> EX -> MEM -> WB
// - Full forwarding (EX/MEM and MEM/WB -> EX)
// - Load-use hazard stall (1 bubble)
// - Branches/jumps resolved in EX, with IF/ID + ID/EX flush
//
// Memory interface (Phase 1, combinational/async read for simplicity):
//   Instruction: drive imem_addr, receive imem_rdata same cycle.
//   Data:        drive dmem_addr/we/be/wdata, receive dmem_rdata same cycle.
module rv32i_core #(
    parameter [31:0] RESET_PC = 32'h0000_0000
)(
    input  wire        clk,
    input  wire        rst_n,

    // Instruction memory (async read)
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // Data memory (async read, sync write)
    output wire [31:0] dmem_addr,
    output wire [3:0]  dmem_be,     // byte enables for store
    output wire        dmem_we,
    output wire        dmem_re,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata
);
    // ---------------------------------------------------------------
    // Program counter / IF stage
    // ---------------------------------------------------------------
    reg  [31:0] pc;
    wire [31:0] pc_plus4 = pc + 32'd4;

    wire        stall;        // load-use stall (freeze IF/ID + PC)
    wire        branch_taken; // resolved in EX
    wire [31:0] branch_target;

    wire [31:0] next_pc = branch_taken ? branch_target :
                          stall        ? pc            : pc_plus4;

    always @(posedge clk or negedge rst_n)
        if (!rst_n) pc <= RESET_PC;
        else        pc <= next_pc;

    assign imem_addr = pc;

    // ---------------------------------------------------------------
    // IF/ID pipeline register
    // ---------------------------------------------------------------
    reg [31:0] ifid_pc, ifid_inst;
    reg        ifid_valid;

    wire flush_ifid = branch_taken;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ifid_pc <= 32'b0; ifid_inst <= 32'h00000013; ifid_valid <= 1'b0; // NOP
        end else if (flush_ifid) begin
            ifid_inst <= 32'h00000013; ifid_valid <= 1'b0; // bubble
        end else if (!stall) begin
            ifid_pc <= pc; ifid_inst <= imem_rdata; ifid_valid <= 1'b1;
        end
        // if stall: hold current IF/ID
    end

    // ---------------------------------------------------------------
    // ID stage: decode + regfile
    // ---------------------------------------------------------------
    wire [31:0] id_imm;
    wire [4:0]  id_rs1, id_rs2, id_rd;
    wire [3:0]  id_alu_op;
    wire        id_alu_src_a, id_alu_src_b;
    wire [1:0]  id_wb_sel;
    wire        id_reg_write, id_mem_read, id_mem_write;
    wire        id_is_branch, id_is_jal, id_is_jalr;
    wire [2:0]  id_funct3;
    wire        id_illegal;

    decoder dec (
        .inst(ifid_inst), .imm(id_imm),
        .rs1(id_rs1), .rs2(id_rs2), .rd(id_rd),
        .alu_op(id_alu_op), .alu_src_a(id_alu_src_a), .alu_src_b(id_alu_src_b),
        .wb_sel(id_wb_sel), .reg_write(id_reg_write),
        .mem_read(id_mem_read), .mem_write(id_mem_write),
        .is_branch(id_is_branch), .is_jal(id_is_jal), .is_jalr(id_is_jalr),
        .funct3(id_funct3), .illegal(id_illegal)
    );

    // Writeback signals (declared here, driven in WB section)
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    wire [31:0] id_rdata1, id_rdata2;
    regfile rf (
        .clk(clk), .we(wb_reg_write), .waddr(wb_rd), .wdata(wb_data),
        .raddr1(id_rs1), .raddr2(id_rs2),
        .rdata1(id_rdata1), .rdata2(id_rdata2)
    );

    // ---------------------------------------------------------------
    // Load-use hazard detection (ID/EX is a load whose rd feeds ID)
    // ---------------------------------------------------------------
    reg [4:0] idex_rs1, idex_rs2, idex_rd;
    reg       idex_mem_read;

    assign stall = idex_mem_read && (idex_rd != 5'b0) &&
                   ((idex_rd == id_rs1) || (idex_rd == id_rs2)) &&
                   ifid_valid;

    // Inject bubble into ID/EX on stall or branch flush
    wire id_bubble = stall || branch_taken || !ifid_valid;

    // ---------------------------------------------------------------
    // ID/EX pipeline register
    // ---------------------------------------------------------------
    reg [31:0] idex_pc, idex_imm, idex_r1, idex_r2;
    reg [3:0]  idex_alu_op;
    reg        idex_alu_src_a, idex_alu_src_b;
    reg [1:0]  idex_wb_sel;
    reg        idex_reg_write, idex_mem_write;
    reg        idex_is_branch, idex_is_jal, idex_is_jalr;
    reg [2:0]  idex_funct3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idex_reg_write <= 0; idex_mem_read <= 0; idex_mem_write <= 0;
            idex_is_branch <= 0; idex_is_jal <= 0; idex_is_jalr <= 0;
            idex_rd <= 0; idex_rs1 <= 0; idex_rs2 <= 0;
            idex_pc <= 0; idex_imm <= 0; idex_r1 <= 0; idex_r2 <= 0;
            idex_alu_op <= 0; idex_alu_src_a <= 0; idex_alu_src_b <= 0;
            idex_wb_sel <= 0; idex_funct3 <= 0;
        end else begin
            idex_pc        <= ifid_pc;
            idex_imm       <= id_imm;
            idex_r1        <= id_rdata1;
            idex_r2        <= id_rdata2;
            idex_rs1       <= id_rs1;
            idex_rs2       <= id_rs2;
            idex_rd        <= id_rd;
            idex_alu_op    <= id_alu_op;
            idex_alu_src_a <= id_alu_src_a;
            idex_alu_src_b <= id_alu_src_b;
            idex_wb_sel    <= id_wb_sel;
            idex_funct3    <= id_funct3;
            // control bits killed on bubble
            idex_reg_write <= id_bubble ? 1'b0 : id_reg_write;
            idex_mem_read  <= id_bubble ? 1'b0 : id_mem_read;
            idex_mem_write <= id_bubble ? 1'b0 : id_mem_write;
            idex_is_branch <= id_bubble ? 1'b0 : id_is_branch;
            idex_is_jal    <= id_bubble ? 1'b0 : id_is_jal;
            idex_is_jalr   <= id_bubble ? 1'b0 : id_is_jalr;
        end
    end

    // ---------------------------------------------------------------
    // EX stage: forwarding, ALU, branch resolution
    // ---------------------------------------------------------------
    // Forwarding sources (declared before the forward mux that uses them)
    reg [4:0]  exmem_rd;
    reg        exmem_reg_write;
    reg [31:0] exmem_alu;
    reg [1:0]  exmem_wb_sel;
    reg [31:0] exmem_pc4;      // assigned in EX/MEM register block
    reg [31:0] load_data;      // computed combinationally in MEM stage

    // Value the EX/MEM instruction will write back (available in MEM stage).
    // For loads this is the freshly read/extended data; for JAL/JALR it is PC+4.
    // (declared as wires below after load_data; use function of already-known regs)
    wire [31:0] exmem_fwd = (exmem_wb_sel == `WB_MEM) ? load_data :
                            (exmem_wb_sel == `WB_PC4) ? exmem_pc4  :
                                                        exmem_alu;

    // Forward mux for rs1 / rs2 operands
    reg [31:0] fwd_r1, fwd_r2;
    always @(*) begin
        // rs1
        if (exmem_reg_write && exmem_rd != 5'b0 && exmem_rd == idex_rs1)
            fwd_r1 = exmem_fwd;
        else if (wb_reg_write && wb_rd != 5'b0 && wb_rd == idex_rs1)
            fwd_r1 = wb_data;
        else
            fwd_r1 = idex_r1;
        // rs2
        if (exmem_reg_write && exmem_rd != 5'b0 && exmem_rd == idex_rs2)
            fwd_r2 = exmem_fwd;
        else if (wb_reg_write && wb_rd != 5'b0 && wb_rd == idex_rs2)
            fwd_r2 = wb_data;
        else
            fwd_r2 = idex_r2;
    end

    wire [31:0] alu_a = (idex_alu_src_a == `ASRC_PC)  ? idex_pc  : fwd_r1;
    wire [31:0] alu_b = (idex_alu_src_b == `BSRC_IMM) ? idex_imm : fwd_r2;

    wire [31:0] alu_y;
    wire        alu_zero;
    alu u_alu (.op(idex_alu_op), .a(alu_a), .b(alu_b), .y(alu_y), .zero(alu_zero));

    // Branch comparison uses forwarded register operands
    wire signed [31:0] s1 = fwd_r1;
    wire signed [31:0] s2 = fwd_r2;
    reg  branch_cond;
    always @(*) begin
        case (idex_funct3)
            3'b000: branch_cond = (fwd_r1 == fwd_r2);   // BEQ
            3'b001: branch_cond = (fwd_r1 != fwd_r2);   // BNE
            3'b100: branch_cond = (s1 < s2);            // BLT
            3'b101: branch_cond = (s1 >= s2);           // BGE
            3'b110: branch_cond = (fwd_r1 < fwd_r2);    // BLTU
            3'b111: branch_cond = (fwd_r1 >= fwd_r2);   // BGEU
            default: branch_cond = 1'b0;
        endcase
    end

    assign branch_taken = idex_is_jal || idex_is_jalr ||
                          (idex_is_branch && branch_cond);
    assign branch_target = idex_is_jalr ? ((fwd_r1 + idex_imm) & ~32'b1)
                                        : (idex_pc + idex_imm);

    wire [31:0] ex_pc4 = idex_pc + 32'd4;

    // ---------------------------------------------------------------
    // EX/MEM pipeline register
    // ---------------------------------------------------------------
    reg [31:0] exmem_r2;
    reg        exmem_mem_read, exmem_mem_write;
    reg [2:0]  exmem_funct3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exmem_reg_write <= 0; exmem_mem_read <= 0; exmem_mem_write <= 0;
            exmem_rd <= 0; exmem_alu <= 0; exmem_r2 <= 0; exmem_pc4 <= 0;
            exmem_wb_sel <= 0; exmem_funct3 <= 0;
        end else begin
            exmem_reg_write <= idex_reg_write;
            exmem_mem_read  <= idex_mem_read;
            exmem_mem_write <= idex_mem_write;
            exmem_rd        <= idex_rd;
            exmem_alu       <= alu_y;
            exmem_r2        <= fwd_r2;
            exmem_pc4       <= ex_pc4;
            exmem_wb_sel    <= idex_wb_sel;
            exmem_funct3    <= idex_funct3;
        end
    end

    // ---------------------------------------------------------------
    // MEM stage: data memory access with byte/half/word support
    // ---------------------------------------------------------------
    assign dmem_addr = {exmem_alu[31:2], 2'b00};
    assign dmem_re   = exmem_mem_read;

    // Store byte-enable + data alignment
    reg [3:0]  be;
    reg [31:0] wdata;
    always @(*) begin
        be = 4'b0000; wdata = exmem_r2;
        case (exmem_funct3[1:0])
            2'b00: begin // SB
                case (exmem_alu[1:0])
                    2'b00: begin be = 4'b0001; wdata = {24'b0, exmem_r2[7:0]}; end
                    2'b01: begin be = 4'b0010; wdata = {16'b0, exmem_r2[7:0], 8'b0}; end
                    2'b10: begin be = 4'b0100; wdata = {8'b0, exmem_r2[7:0], 16'b0}; end
                    2'b11: begin be = 4'b1000; wdata = {exmem_r2[7:0], 24'b0}; end
                endcase
            end
            2'b01: begin // SH
                if (exmem_alu[1]) begin be = 4'b1100; wdata = {exmem_r2[15:0], 16'b0}; end
                else              begin be = 4'b0011; wdata = {16'b0, exmem_r2[15:0]}; end
            end
            default: begin // SW
                be = 4'b1111; wdata = exmem_r2;
            end
        endcase
    end
    assign dmem_be    = exmem_mem_write ? be : 4'b0000;
    assign dmem_we    = exmem_mem_write;
    assign dmem_wdata = wdata;

    // Load data extraction (sign/zero extend)
    always @(*) begin
        case (exmem_funct3)
            3'b000: begin // LB
                case (exmem_alu[1:0])
                    2'b00: load_data = {{24{dmem_rdata[7]}},  dmem_rdata[7:0]};
                    2'b01: load_data = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'b10: load_data = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    default: load_data = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end
            3'b001: load_data = exmem_alu[1] ? {{16{dmem_rdata[31]}}, dmem_rdata[31:16]}
                                             : {{16{dmem_rdata[15]}}, dmem_rdata[15:0]}; // LH
            3'b100: begin // LBU
                case (exmem_alu[1:0])
                    2'b00: load_data = {24'b0, dmem_rdata[7:0]};
                    2'b01: load_data = {24'b0, dmem_rdata[15:8]};
                    2'b10: load_data = {24'b0, dmem_rdata[23:16]};
                    default: load_data = {24'b0, dmem_rdata[31:24]};
                endcase
            end
            3'b101: load_data = exmem_alu[1] ? {16'b0, dmem_rdata[31:16]}
                                             : {16'b0, dmem_rdata[15:0]};  // LHU
            default: load_data = dmem_rdata; // LW
        endcase
    end

    // ---------------------------------------------------------------
    // MEM/WB pipeline register
    // ---------------------------------------------------------------
    reg [31:0] memwb_alu, memwb_load, memwb_pc4;
    reg [1:0]  memwb_wb_sel;
    reg [4:0]  memwb_rd;
    reg        memwb_reg_write;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            memwb_reg_write <= 0; memwb_rd <= 0;
            memwb_alu <= 0; memwb_load <= 0; memwb_pc4 <= 0; memwb_wb_sel <= 0;
        end else begin
            memwb_reg_write <= exmem_reg_write;
            memwb_rd        <= exmem_rd;
            memwb_alu       <= exmem_alu;
            memwb_load      <= load_data;
            memwb_pc4       <= exmem_pc4;
            memwb_wb_sel    <= exmem_wb_sel;
        end
    end

    // ---------------------------------------------------------------
    // WB stage
    // ---------------------------------------------------------------
    assign wb_reg_write = memwb_reg_write;
    assign wb_rd        = memwb_rd;
    assign wb_data      = (memwb_wb_sel == `WB_MEM) ? memwb_load :
                          (memwb_wb_sel == `WB_PC4) ? memwb_pc4  :
                                                      memwb_alu;
endmodule
