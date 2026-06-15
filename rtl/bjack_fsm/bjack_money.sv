/********************************************************************************
 * Module Name:    bjack_money
 * Author:         Eryk Rutka
 * Date:           2026-05-31
 * Version:        1.0
 * Description:
 * Manages the player's balance (Ciepliny). Starts with 100.
 * Updates the balance at the end of the round based on game outcome.
 ********************************************************************************/
 import bjack_pkg::*;

 module bjack_money (
    input  logic clk,
    input  logic rst_n,

    input  logic update_en,
    input  logic win,
    input  logic draw_flag,
    input  logic [7:0] bet_amount,

    output logic [15:0] balance

);
    logic [15:0] balance_nxt;


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            balance <= MONEY;
        end else begin
            balance <= balance_nxt;
        end
    end

    always_comb begin
        balance_nxt = balance;

        if (update_en) begin
            if (draw_flag) begin
                balance_nxt = balance;
            end else if (win) begin
                balance_nxt = balance + bet_amount;
            end else begin

                if (balance >= bet_amount)
                    balance_nxt = balance - bet_amount;
                else
                    balance_nxt = '0;
            end
        end
    end

endmodule