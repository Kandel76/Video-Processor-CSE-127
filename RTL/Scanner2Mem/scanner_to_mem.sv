// Bridge from scan_controller pixel output to mem2vga/hmem_access write interface.
// Memory layout -- address = row*160 + byte_index (0--38399 for 320x240).

module scanner_to_mem #(
    parameter int ROWS       = 240,
    parameter int COLS       = 320,
    parameter int DATA_BITS  = 4,
    parameter int PIXEL_BUS_WIDTH = DATA_BITS * COLS   // 1280 for 320 cols x 4 bits
) (
    input  logic clk,
    input  logic rst_n,

    // From the scan controller
    input  logic                       row_data_valid,
    input  logic [PIXEL_BUS_WIDTH-1:0] row_data,
    input  logic [$clog2(ROWS)-1:0]    current_row,

    // To scan_controller (assert when this block has accepted the row)
    output logic                      row_data_ready,

    // To mem2vga / hmem_access write port
    output logic [15:0]               waddr_i,
    output logic [7:0]                wdata_i,
    input  logic                      wready_o
);

    localparam int BYTES_PER_ROW = COLS / 2;   // 160
    localparam int BYTE_IDX_WIDTH = $clog2(BYTES_PER_ROW);

    typedef enum logic { IDLE, DRAIN } state_t;
    state_t state_q, state_d;

    logic [PIXEL_BUS_WIDTH-1:0] row_data_q;
    logic [$clog2(ROWS)-1:0]    row_q;
    logic [BYTE_IDX_WIDTH-1:0]  byte_idx_q, byte_idx_d;

    // Latch row and pixel data when pixel_valid goes high
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_q     <= IDLE;
            byte_idx_q  <= '0;
            row_data_q <= '0;
            row_q       <= '0;
        end else begin
            state_q     <= state_d;
            byte_idx_q  <= byte_idx_d;
            if (state_q == IDLE && row_data_valid) begin
                row_data_q <= row_data;
                row_q        <= current_row;
            end
        end
    end

    // Packed byte -- two consecutive 4-bit pixels -> one 8-bit word
    // byte i = pixels [2*i+1:2*i]  =>  row_data_q[8*i+7 : 8*i]
    assign waddr_i = (row_q * BYTES_PER_ROW) + byte_idx_q;
    assign wdata_i = row_data_q[byte_idx_q * 8 +: 8];

    always_comb begin
        state_d    = state_q;
        byte_idx_d = byte_idx_q;
        row_data_ready = 1'b0;

        case (state_q)
            IDLE: begin
                if (row_data_valid) begin
                    state_d    = DRAIN;
                    byte_idx_d = '0;
                end
            end

            DRAIN: begin
                if (wready_o) begin
                    if (byte_idx_q == BYTES_PER_ROW - 1) begin
                        row_data_ready = 1'b1;
                        state_d     = IDLE;
                        byte_idx_d  = '0;
                    end else begin
                        byte_idx_d = byte_idx_q + 1;
                    end
                end
            end

            default: state_d = IDLE;
        endcase
    end

endmodule
