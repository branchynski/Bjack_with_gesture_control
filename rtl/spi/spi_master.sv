/**
 * Module name:   spi_master
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-07
 * Description:  SPI master module for serial communication with configurable data width, handling data transmission and reception.
 */

module spi_master #(
    parameter logic [7:0] DATA_WIDTH = 8
) (
    input logic clk,
    input logic rst_n,
    input logic spi_ce_x2,

    input logic start,
    output logic busy,
    output logic valid,

    output logic [DATA_WIDTH-1:0] data_out,
    input  logic [DATA_WIDTH-1:0] data_in,

    output logic sclk,
    output logic mosi,
    input  logic miso
);
    /* Local variables and signals */
    typedef enum logic [1:0] {
        IDLE, 
        TRANSFER, 
        DONE
    } state_t;

    state_t state, state_nxt;

    logic [DATA_WIDTH-1:0] bit_cnt, bit_cnt_nxt;
    logic [DATA_WIDTH-1:0] shift_tx, shift_tx_nxt;
    logic [DATA_WIDTH-1:0] shift_rx, shift_rx_nxt;
    logic sclk_nxt;

    logic busy_nxt, valid_nxt, mosi_nxt;
    logic [DATA_WIDTH-1:0] data_out_nxt;


    /* State Sequencer Logic */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            bit_cnt  <= '0;
            shift_tx <= '0;
            shift_rx <= '0;

            busy <= 1'b0;
            valid <= 1'b0;
            data_out <= '0;
            sclk <= 1'b0;
            mosi <= 1'b0;
        end else begin
            state    <= state_nxt;
            bit_cnt  <= bit_cnt_nxt;
            shift_tx <= shift_tx_nxt;
            shift_rx <= shift_rx_nxt;

            busy <= busy_nxt;
            valid <= valid_nxt;
            data_out <= data_out_nxt;
            sclk <= sclk_nxt;
            mosi <= mosi_nxt;
        end
    end

    /* Next State Decode Logic */
    always_comb begin
        state_nxt    = state;
        bit_cnt_nxt  = bit_cnt;

        case (state)
            IDLE: begin
                if (start) begin
                    state_nxt    = TRANSFER;
                    bit_cnt_nxt  = '0;  
                end
            end

            TRANSFER: begin
                if (spi_ce_x2) begin
                    if (sclk == 1'b1) begin
                        bit_cnt_nxt = bit_cnt + 1;
                        if (bit_cnt == DATA_WIDTH - 1) begin
                            state_nxt = DONE;
                        end 
                    end
                end
            end

            DONE: begin
                state_nxt = IDLE; 
            end
            
            default: state_nxt = IDLE;
        endcase
    end

    /* Output Decode Logic */

    always_comb begin
        shift_tx_nxt = shift_tx;
        shift_rx_nxt = shift_rx;
        sclk_nxt     = sclk;
        
        busy_nxt = 1'b0;
        valid_nxt = 1'b0;

        data_out_nxt = shift_rx;
        mosi_nxt = shift_tx[DATA_WIDTH-1]; 
        sclk_nxt = sclk;

        case (state)
            IDLE: begin
                sclk_nxt = 1'b0;
                if (start) begin
                    shift_tx_nxt = data_in;                    
                end
            end

            TRANSFER: begin
                busy_nxt = 1'b1;
                if (spi_ce_x2) begin
                    sclk_nxt = ~sclk; 

                    if (sclk == 1'b0) begin
                        shift_rx_nxt = {shift_rx[DATA_WIDTH-2:0], miso};
                    end else begin
                        if (bit_cnt != DATA_WIDTH - 1) begin
                            shift_tx_nxt = {shift_tx[DATA_WIDTH-2:0], 1'b0};
                        end
                    end
                end
            end

            DONE: begin
                valid_nxt     = 1'b1;     
                busy_nxt      = 1'b1;
                sclk_nxt  = 1'b0; 
            end
        endcase
    end

endmodule