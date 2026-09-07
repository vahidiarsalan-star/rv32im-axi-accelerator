// Testbench for rv32i_core + sim_memory.
// Loads program.hex (word-per-line hex) into memory, runs the core, and stops
// when the program stores a value to the "tohost" address (0x1000):
//   - value 1        => PASS
//   - any other value => FAIL (the generator's direct test ID)
`timescale 1ns/1ps
module tb_top;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;   // 100 MHz

    // core <-> memory wires
    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_be;
    wire        dmem_we, dmem_re;

    localparam TOHOST = 32'h0000_1000;

    rv32i_core #(.RESET_PC(32'h0)) dut (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_be(dmem_be), .dmem_we(dmem_we),
        .dmem_re(dmem_re), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata)
    );

    sim_memory #(.WORDS(4096)) mem (
        .clk(clk),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_be(dmem_be), .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata)
    );

    integer cycles = 0;
    integer i;
    integer stalls = 0;
    integer redirects = 0;
    integer image_words;
    reg [1023:0] program_file;
    initial begin
        for (i = 0; i < 4096; i = i + 1) mem.mem[i] = 32'h00000013; // NOP fill
        if (!$value$plusargs("PROGRAM=%s", program_file)) program_file = "program.hex";
        if ($value$plusargs("WORDS=%d", image_words))
            $readmemh(program_file, mem.mem, 0, image_words - 1);
        else $readmemh(program_file, mem.mem);
        if ($test$plusargs("WAVES")) begin
            $dumpfile("tb_top.vcd");
            $dumpvars(0, tb_top);
        end
        rst_n = 0;
        repeat (4) @(negedge clk);
        rst_n = 1;
    end

    // Watch for a store to TOHOST
    always @(posedge clk) begin
        if (rst_n) begin
            cycles = cycles + 1;
            if (dut.stall) stalls = stalls + 1;
            if (dut.branch_taken) redirects = redirects + 1;
            if (dmem_we && (dmem_addr == TOHOST)) begin
                if (dmem_wdata == 32'd1) begin
                    $display("*** PASS *** (cycles=%0d stalls=%0d redirects=%0d)", cycles, stalls, redirects);
                end else begin
                    $display("*** FAIL *** code=%0d (cycles=%0d)", dmem_wdata, cycles);
                    $fatal(1);
                end
                $finish;
            end
            if (cycles > 100000) begin
                $display("*** TIMEOUT *** no tohost write after %0d cycles", cycles);
                $fatal(1);
            end
        end
    end
endmodule
