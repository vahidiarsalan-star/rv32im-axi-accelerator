// SoC top for Tang Primer 20K + Dock (Gowin GW2A-18C, GW2A-LV18PG256C8/I7).
// - rv32i_core
// - 4 KB unified RAM (async read), initialized from firmware.hex
// - Memory-mapped UART TX/RX + LEDs
//
// Memory map:
//   0x0000_0000 .. 0x0000_0FFF : RAM (code + data), 4 KB
//   0x8000_0000                : UART data (write=TX, read=RX FIFO pop)
//   0x8000_0004                : UART status (bit0=TX busy, bit1=RX ready,
//                                bit2=RX FIFO full, bit3=RX overrun,
//                                bit4=RX framing error)
//   0x8000_0008                : LED register   (write; drives on-board LEDs)
module soc_top #(
    parameter CLK_HZ  = 27_000_000,
    parameter BAUD    = 115200,
    // 4 KiB fits as registers for bring-up. A later synchronous BSRAM
    // subsystem will restore a larger memory without consuming DFFs.
    parameter RAMWORDS= 1024,
    parameter MEM_FILE= "firmware.hex"
)(
    input  wire       clk,               // 27 MHz crystal oscillator (pin H11)
    input  wire       rst_n_btn,         // active-low reset button (Dock key T10)
    input  wire       uart_rx_pin,       // from on-board BL702 USB-UART bridge (T13)
    output wire       uart_tx_pin,       // to on-board BL702 USB-UART bridge (M11)
    output wire [2:0] led                // Dock user LEDs (active-high; N16/N14/L14)
);
    // ---- reset synchronizer ----
    reg [3:0] rst_sync = 4'b0;
    always @(posedge clk) rst_sync <= {rst_sync[2:0], rst_n_btn};
    wire rst_n = rst_sync[3];

    // ---- core memory interface ----
    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, core_dmem_rdata;
    wire [3:0]  dmem_be;
    wire        dmem_we, dmem_re;

    rv32i_core #(.RESET_PC(32'h0)) cpu (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_be(dmem_be), .dmem_we(dmem_we),
        .dmem_re(dmem_re), .dmem_wdata(dmem_wdata), .dmem_rdata(core_dmem_rdata)
    );

    // ---- address decode ----
    wire is_mmio = dmem_addr[31];               // 0x8000_0000+ => MMIO
    wire ram_we  = dmem_we & ~is_mmio;

    // ---- 4 KB RAM (async read), init from firmware.hex ----
    // The current async-read CPU interface does not match Gowin BSRAM's
    // inference template, so this is intentionally a small register RAM.
    reg [31:0] ram [0:RAMWORDS-1];
    initial $readmemh(MEM_FILE, ram);

    localparam IDX = $clog2(RAMWORDS);
    wire [IDX-1:0] iw = imem_addr[IDX+1:2];
    wire [IDX-1:0] dw = dmem_addr[IDX+1:2];

    assign imem_rdata = ram[iw];
    wire [31:0] ram_rdata = ram[dw];

    always @(posedge clk) begin
        if (ram_we) begin
            if (dmem_be[0]) ram[dw][7:0]   <= dmem_wdata[7:0];
            if (dmem_be[1]) ram[dw][15:8]  <= dmem_wdata[15:8];
            if (dmem_be[2]) ram[dw][23:16] <= dmem_wdata[23:16];
            if (dmem_be[3]) ram[dw][31:24] <= dmem_wdata[31:24];
        end
    end

    // ---- UART transmitter ----
    wire       uart_busy;
    wire       uart_wr = dmem_we & is_mmio & (dmem_addr[7:0] == 8'h00);
    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart (
        .clk(clk), .rst_n(rst_n),
        .tx_start(uart_wr & ~uart_busy),
        .tx_data(dmem_wdata[7:0]),
        .tx(uart_tx_pin),
        .busy(uart_busy)
    );

    // ---- UART receiver + 16-byte FIFO ----
    // The FIFO absorbs command bytes that arrive while firmware is finishing a
    // response.  Software pops one byte by reading UART_DATA.
    wire [7:0] uart_rx_byte;
    wire       uart_rx_strobe;
    wire       uart_rx_frame_error;
    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart_rx (
        .clk(clk), .rst_n(rst_n), .rx(uart_rx_pin),
        .rx_data(uart_rx_byte), .rx_valid(uart_rx_strobe),
        .frame_error(uart_rx_frame_error)
    );

    reg [7:0] rx_fifo [0:15];
    reg [3:0] rx_wr_ptr;
    reg [3:0] rx_rd_ptr;
    reg [4:0] rx_count;
    reg       rx_overrun;
    reg       rx_frame_error_sticky;

    wire rx_ready = (rx_count != 0);
    wire rx_full  = (rx_count == 16);
    wire uart_rx_rd = dmem_re & is_mmio & (dmem_addr[7:0] == 8'h00);
    wire rx_pop = uart_rx_rd & rx_ready;
    // A simultaneous pop makes room even when the FIFO began the cycle full.
    wire rx_push = uart_rx_strobe & (!rx_full | rx_pop);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_wr_ptr              <= 4'b0;
            rx_rd_ptr              <= 4'b0;
            rx_count               <= 5'b0;
            rx_overrun             <= 1'b0;
            rx_frame_error_sticky  <= 1'b0;
        end else begin
            if (rx_push) begin
                rx_fifo[rx_wr_ptr] <= uart_rx_byte;
                rx_wr_ptr <= rx_wr_ptr + 4'd1;
            end else if (uart_rx_strobe && rx_full) begin
                rx_overrun <= 1'b1;
            end

            if (rx_pop)
                rx_rd_ptr <= rx_rd_ptr + 4'd1;

            case ({rx_push, rx_pop})
                2'b10: rx_count <= rx_count + 5'd1;
                2'b01: rx_count <= rx_count - 5'd1;
                default: rx_count <= rx_count;
            endcase

            if (uart_rx_frame_error)
                rx_frame_error_sticky <= 1'b1;
        end
    end

    // ---- LED register ----
    reg [2:0] led_reg = 3'b000;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) led_reg <= 3'b000;
        else if (dmem_we & is_mmio & (dmem_addr[7:0] == 8'h08))
            led_reg <= dmem_wdata[2:0]; // active-high; invert if your Dock LEDs are active-low
    end
    assign led = led_reg;

    // ---- read-data mux ----
    reg [31:0] mmio_rdata;
    always @(*) begin
        case (dmem_addr[7:0])
            8'h00:   mmio_rdata = {24'b0, rx_fifo[rx_rd_ptr]};
            8'h04:   mmio_rdata = {27'b0, rx_frame_error_sticky,
                                   rx_overrun, rx_full, rx_ready, uart_busy};
            default: mmio_rdata = 32'b0;
        endcase
    end
    assign core_dmem_rdata = is_mmio ? mmio_rdata : ram_rdata;
endmodule
