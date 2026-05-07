/**
 * Module name:   spi_ce_gen
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-07
 * Description:  Clock enable generator for SPI communication, producing pulses at twice the SPI clock frequency from the main clock.
 */

module spi_ce_gen #(
    parameter MAIN_CLK = 100_000_000, 
    parameter SPI_CLK  = 1_000_000    
) (
    input  logic clk,
    input  logic rst_n,
    output logic spi_ce_x2 
);

    localparam DIV_VAL = (MAIN_CLK / (SPI_CLK * 2)) - 1;
    logic [31:0] cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= '0;
            spi_ce_x2 <= 1'b0;
        end else begin
            if (cnt == DIV_VAL) begin
                cnt       <= '0;
                spi_ce_x2 <= 1'b1; 
            end else begin
                cnt       <= cnt + 1;
                spi_ce_x2 <= 1'b0; 
            end
        end
    end

endmodule