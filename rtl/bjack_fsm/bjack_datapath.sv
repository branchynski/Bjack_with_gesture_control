/********************************************************************************
 * Module Name:    bjack_datapath
 * Author:         Eryk Rutka
 * Date:           2026-05-31
 * Version:        1.1 (Vivado Import Fix)
 * Description:    
 * Main datapath for the Blackjack game. Handles pulling cards from LFSR, 
 * storing them in memory arrays for the VGA renderer, calculating scores, 
 * and managing bust/win conditions.
 ********************************************************************************/

 module bjack_datapath (
    input  logic clk,
    input  logic rst_n,

    // --- Sygnały sterujące z FSM ---
    input  logic sig_deal_enable, 
    input  logic sig_player_turn, 
    input  logic sig_dealer_turn, 
    input  logic btn_hit,         
    input  logic btn_start,       

    // --- Sygnały zwrotne do FSM ---
    output logic bust,
    output logic deal_done,
    output logic dealer_done,

    // --- Połączenie z LFSR (card_drawing) ---
    input  logic [5:0] card_value,
    input  logic card_valid,
    output logic card_req,

    // --- Połączenie z VGA (draw_cards) ---
    output logic [5:0] player_cards [0:4],
    output logic [5:0] dealer_cards [0:4],
    output logic [2:0] player_card_cnt,
    output logic [2:0] dealer_card_cnt
);

    timeunit 1ns;
    timeprecision 1ps;

    // --- PRZENIESIONY IMPORT (bezpieczny dla Vivado) ---
    import bjack_pkg::*;

    // --- Zmienne wewnętrzne ---
    logic [2:0] init_deal_step; 
    logic req_pending;          
    
    // Surowe punkty
    logic [5:0] p_score, d_score;
    logic p_has_ace, d_has_ace;

    // --- Funkcja do wyciągania wartości punktowej karty (0-51) ---
    function automatic logic [3:0] get_points(input logic [5:0] c_val);
        logic [3:0] rank;
        rank = c_val % 13;
        if (rank == 0) return 4'd11;           // As (domyślnie 11)
        else if (rank > 0 && rank < 10) return rank + 1; // Karty 2-10
        else return 4'd10;                     // J, Q, K
    endfunction

    // --- Główna logika sterująca ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_card_cnt <= '0;
            dealer_card_cnt <= '0;
            init_deal_step  <= '0;
            card_req        <= 1'b0;
            req_pending     <= 1'b0;
            bust            <= 1'b0;
            deal_done       <= 1'b0;
            dealer_done     <= 1'b0;
            
            for (int i=0; i<5; i++) begin
                player_cards[i] <= '0;
                dealer_cards[i] <= '0;
            end
        end else begin
            // Czyszczenie rundy
            if (btn_start) begin
                player_card_cnt <= '0;
                dealer_card_cnt <= '0;
                init_deal_step  <= '0;
                bust            <= 1'b0;
                deal_done       <= 1'b0;
                dealer_done     <= 1'b0;
                req_pending     <= 1'b0;
            end

            card_req <= 1'b0; 

            // 1. FAZA ROZDANIA POCZĄTKOWEGO (DEAL_INITIAL)
            if (sig_deal_enable && !deal_done) begin
                if (!req_pending && init_deal_step < 4) begin
                    card_req <= 1'b1;
                    req_pending <= 1'b1;
                end
                
                if (card_valid && req_pending) begin
                    req_pending <= 1'b0;
                    if (init_deal_step == 0 || init_deal_step == 2) begin
                        player_cards[player_card_cnt] <= card_value;
                        player_card_cnt <= player_card_cnt + 1;
                    end else begin
                        dealer_cards[dealer_card_cnt] <= card_value;
                        dealer_card_cnt <= dealer_card_cnt + 1;
                    end
                    init_deal_step <= init_deal_step + 1;
                end
                
                if (init_deal_step == 4) begin
                    deal_done <= 1'b1;
                end
            end

            // 2. TURA GRACZA (PLAYER_TURN)
            if (sig_player_turn) begin
                if (btn_hit && !req_pending && player_card_cnt < 5) begin
                    card_req <= 1'b1;
                    req_pending <= 1'b1;
                end
                
                if (card_valid && req_pending) begin
                    req_pending <= 1'b0;
                    player_cards[player_card_cnt] <= card_value;
                    player_card_cnt <= player_card_cnt + 1;
                end
                
                if (p_score > 21 && !p_has_ace) bust <= 1'b1;
                else if (p_score > 31 && p_has_ace) bust <= 1'b1; 
            end

            // 3. TURA KRUPIERA (DEALER_TURN)
            if (sig_dealer_turn && !dealer_done) begin
                logic [5:0] current_d_score;
                current_d_score = d_has_ace && (d_score > 21) ? d_score - 10 : d_score;

                if (current_d_score < 17 && dealer_card_cnt < 5) begin
                    if (!req_pending) begin
                        card_req <= 1'b1;
                        req_pending <= 1'b1;
                    end
                    
                    if (card_valid && req_pending) begin
                        req_pending <= 1'b0;
                        dealer_cards[dealer_card_cnt] <= card_value;
                        dealer_card_cnt <= dealer_card_cnt + 1;
                    end
                end else if (!req_pending) begin 
                    dealer_done <= 1'b1;
                end
            end
        end
    end

    // --- Asynchroniczne liczenie punktów ---
    always_comb begin
        p_score = '0;
        p_has_ace = 1'b0;
        d_score = '0;
        d_has_ace = 1'b0;

        for (int i = 0; i < 5; i++) begin
            if (i < player_card_cnt) begin
                p_score = p_score + get_points(player_cards[i]);
                if (player_cards[i] % 13 == 0) p_has_ace = 1'b1;
            end
        end

        for (int i = 0; i < 5; i++) begin
            if (i < dealer_card_cnt) begin
                d_score = d_score + get_points(dealer_cards[i]);
                if (dealer_cards[i] % 13 == 0) d_has_ace = 1'b1;
            end
        end
    end

endmodule