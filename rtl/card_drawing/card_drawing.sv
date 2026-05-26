/********************************************************************************
 * Module Name:    card_drawing
 * Author:         Eryk Rutka
 * Date:           2026-05-15
 * Version:        1.0
 * * Description:    
 * This module implements pseudo-random drawing card algorithm, based on LFSR 
 * (Linear-Feedback Shift Register).
 ********************************************************************************/

import bjack_pkg::*;

module card_drawing( 
    input logic         clk,
    input logic         rst_n,   
    input logic         card_req,

    output logic [5:0]  card_value,
    output logic        card_valid
); 

logic [15:0] lfsr_reg;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        lfsr_reg <= 16'd1;
        card_valid <= 1'b0; 
    end else begin
        lfsr_reg <= {lfsr_reg[14:0], lfsr_reg[15] ^ lfsr_reg[13] ^ lfsr_reg[12] ^ lfsr_reg[10]};
        card_valid <= card_req; 
    end
end

always_comb begin 
    card_value = lfsr_reg % CARD_DECK; 
end

endmodule