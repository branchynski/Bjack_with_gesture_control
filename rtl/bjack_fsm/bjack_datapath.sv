/********************************************************************************
 * Module Name:    bjack_datapath
 * Author:         Eryk Rutka
 * Date:           2026-06-02
 * Version:        2.0 (Multiplayer Support - P0 & P1)
 * Description:    
 * Main datapath for the Blackjack game. Handles pulling cards from LFSR, 
 * storing them in memory arrays for the VGA renderer, calculating scores, 
 * and managing bust/win conditions for TWO independent players.
 ********************************************************************************/

 module bjack_datapath (
    input  logic clk,
    input  logic rst_n,

    // --- Sygnały sterujące z FSM ---
    input  logic sig_deal_enable, 
    input  logic sig_p0_turn,     
    input  logic sig_p1_turn,     
    input  logic sig_dealer_turn, 
    input  logic btn_p0_hit,      
    input  logic btn_p1_hit,      
    input  logic btn_start,       

    // --- Sygnały zwrotne do FSM ---
    output logic p0_bust,         
    output logic p1_bust,         
    output logic deal_done,
    output logic dealer_done,

    // --- Połączenie z LFSR (card_drawing) ---
    input  logic [5:0] card_value,
    input  logic card_valid,
    output logic card_req,

    // --- Połączenie z VGA (card_generator) ---
    output logic [5:0] p0_cards [0:4],
    output logic [5:0] p1_cards [0:4],
    output logic [5:0] dealer_cards [0:4],
    output logic [2:0] p0_card_cnt,
    output logic [2:0] p1_card_cnt,
    output logic [2:0] dealer_card_cnt
);

    timeunit 1ns;
    timeprecision 1ps;

    import bjack_pkg::*;

    // --- Zmienne wewnętrzne ---
    logic [2:0] init_deal_step; 
    logic req_pending;          
    
    // Surowe punkty
    logic [5:0] p0_score, p1_score, d_score;
    logic p0_has_ace, p1_has_ace, d_has_ace;

    // --- Funkcja do wyciągania wartości punktowej karty (0-51) ---
    function automatic logic [3:0] get_points(input logic [5:0] c_val);
        logic [3:0] rank;
        rank = c_val % 13;
        if (rank == 0) return 4'd11;                        // As (domyślnie 11)
        else if (rank > 0 && rank < 10) return rank + 1;    // Karty 2-10
        else return 4'd10;                                  // J, Q, K
    endfunction

    // --- Główna logika sterująca (Maszyna Rejestrowa) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p0_card_cnt <= '0;
            p1_card_cnt <= '0;
            dealer_card_cnt <= '0;
            init_deal_step  <= '0;
            card_req        <= 1'b0;
            req_pending     <= 1'b0;
            p0_bust         <= 1'b0;
            p1_bust         <= 1'b0;
            deal_done       <= 1'b0;
            dealer_done     <= 1'b0;
            
            for (int i=0; i<5; i++) begin
                p0_cards[i] <= '0;
                p1_cards[i] <= '0;
                dealer_cards[i] <= '0;
            end
        end else begin
            if (btn_start) begin
                p0_card_cnt <= '0;
                p1_card_cnt <= '0;
                dealer_card_cnt <= '0;
                init_deal_step  <= '0;
                p0_bust         <= 1'b0;
                p1_bust         <= 1'b0;
                deal_done       <= 1'b0;
                dealer_done     <= 1'b0;
                req_pending     <= 1'b0;
            end

            card_req <= 1'b0; 

            // 1. FAZA ROZDANIA POCZĄTKOWEGO (DEAL_INITIAL)
            if (sig_deal_enable && !deal_done) begin
                if (!req_pending && init_deal_step < 6) begin
                    card_req <= 1'b1;
                    req_pending <= 1'b1;
                end
                
                if (card_valid && req_pending) begin
                    req_pending <= 1'b0;
                    
                    if (init_deal_step == 0 || init_deal_step == 3) begin
                        p0_cards[p0_card_cnt] <= card_value;
                        p0_card_cnt <= p0_card_cnt + 1;
                    end 
                    else if (init_deal_step == 1 || init_deal_step == 4) begin
                        p1_cards[p1_card_cnt] <= card_value;
                        p1_card_cnt <= p1_card_cnt + 1;
                    end 
                    else begin
                        dealer_cards[dealer_card_cnt] <= card_value;
                        dealer_card_cnt <= dealer_card_cnt + 1;
                    end
                    
                    init_deal_step <= init_deal_step + 1;
                end
                
                if (init_deal_step == 6) begin
                    deal_done <= 1'b1;
                end
            end

            // 2. TURA GRACZA 0
            if (sig_p0_turn) begin
                if (btn_p0_hit && !req_pending && p0_card_cnt < 5) begin
                    card_req <= 1'b1;
                    req_pending <= 1'b1;
                end
                
                if (card_valid && req_pending) begin
                    req_pending <= 1'b0;
                    p0_cards[p0_card_cnt] <= card_value;
                    p0_card_cnt <= p0_card_cnt + 1;
                end
                
                if (p0_score > 21 && !p0_has_ace) p0_bust <= 1'b1;
                else if (p0_score > 31 && p0_has_ace) p0_bust <= 1'b1; 
            end

            // 3. TURA GRACZA 1
            if (sig_p1_turn) begin
                if (btn_p1_hit && !req_pending && p1_card_cnt < 5) begin
                    card_req <= 1'b1;
                    req_pending <= 1'b1;
                end
                
                if (card_valid && req_pending) begin
                    req_pending <= 1'b0;
                    p1_cards[p1_card_cnt] <= card_value;
                    p1_card_cnt <= p1_card_cnt + 1;
                end
                
                if (p1_score > 21 && !p1_has_ace) p1_bust <= 1'b1;
                else if (p1_score > 31 && p1_has_ace) p1_bust <= 1'b1; 
            end

            // 4. TURA KRUPIERA (DEALER_TURN)
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
        p0_score = '0;
        p0_has_ace = 1'b0;
        p1_score = '0;
        p1_has_ace = 1'b0;
        d_score = '0;
        d_has_ace = 1'b0;

        for (int i = 0; i < 5; i++) begin
            if (i < p0_card_cnt) begin
                p0_score = p0_score + get_points(p0_cards[i]);
                if (p0_cards[i] % 13 == 0) p0_has_ace = 1'b1;
            end
        end

        for (int i = 0; i < 5; i++) begin
            if (i < p1_card_cnt) begin
                p1_score = p1_score + get_points(p1_cards[i]);
                if (p1_cards[i] % 13 == 0) p1_has_ace = 1'b1;
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