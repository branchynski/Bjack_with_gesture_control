/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
 *
 * Modified by: Piotr Kaczmarczyk / Eryk Rutka
 * 2026  AGH University of Science and Technology
 * MTM UEC2
 * * Description:
 * The project top module. Integrates VGA rendering with Blackjack logic.
 */

 module top_vga (
    input  logic clk,
    input  logic rst_n,

    // --- Przyciski sterujące grą ---
    input  logic btn_start,
    input  logic btn_hit,
    input  logic btn_stand,

    inout  logic ps2_clk,
    inout  logic ps2_data,
    input  logic clk_100MHz,

    output logic vs,
    output logic hs,
    output logic [3:0] r,
    output logic [3:0] g,
    output logic [3:0] b
);

    timeunit 1ns;
    timeprecision 1ps;

    /**
     * Local variables and signals
     */
     
    /* VGA signals from timing */
    vga_if vga_tim();

    /* VGA signals from background */
    vga_if vga_bg();

    /* VGA signals from cards */
    vga_if vga_cards();

    // --- Kable łączące FSM z Datapathem ---
    logic p0_bust_sig;
    logic p1_bust_sig;
    logic deal_done_sig;
    logic dealer_done_sig;
    
    logic sig_deal_enable_sig;
    logic sig_p0_turn_sig;
    logic sig_p1_turn_sig;
    logic sig_dealer_turn_sig;
    logic sig_update_money_sig; // Dodany kabel zaktualizowany w Twoim FSM
    logic busy_sig;

    // --- Kable łączące LFSR z Datapathem ---
    logic [5:0] card_val_sig;
    logic card_valid_sig;
    logic card_req_sig;

    // --- Kable łączące Datapath z modułem rysującym (VGA) ---
    logic [5:0] dpath_p0_cards [0:4];
    logic [5:0] dpath_p1_cards [0:4];
    logic [5:0] dpath_dealer_cards [0:4];
    logic [2:0] dpath_p0_cnt;
    logic [2:0] dpath_p1_cnt;
    logic [2:0] dpath_dealer_cnt;

    /**
     * Signals assignments
     */

    
    assign vs = vga_cards.vsync;
    assign hs = vga_cards.hsync;
    assign {r,g,b} = vga_cards.rgb;


    /**
     * Submodules instances
     */

    // --- 1. GENERATOR KART (LFSR) ---
    card_drawing u_card_drawing (
        .clk(clk),
        .rst_n(rst_n),
        .card_req(card_req_sig),
        .card_value(card_val_sig),
        .card_valid(card_valid_sig)
    );

    // --- 2. MASZYNA STANÓW (FSM) ---
    bjack_fsm u_bjack_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .btn_start(btn_start),
        
        // Podpinamy fizyczne przyciski do Gracza 0. Gracz 1 jest "sztuczny" na potrzeby testów.
        .btn_p0_hit(btn_hit),
        .btn_p0_stand(btn_stand),
        .btn_p1_hit(1'b0),
        .btn_p1_stand(1'b0),
        
        .p0_bust(p0_bust_sig),
        .p1_bust(p1_bust_sig),
        .deal_done(deal_done_sig),
        .dealer_done(dealer_done_sig),
        
        .busy(busy_sig),
        .sig_deal_enable(sig_deal_enable_sig),
        .sig_p0_turn(sig_p0_turn_sig),
        .sig_p1_turn(sig_p1_turn_sig),
        .sig_dealer_turn(sig_dealer_turn_sig),
        .sig_update_money(sig_update_money_sig)
    );

    // --- 3. ŚCIEŻKA DANYCH (DATAPATH) ---
    bjack_datapath u_bjack_datapath (
        .clk(clk),
        .rst_n(rst_n),
        .sig_deal_enable(sig_deal_enable_sig),
        .sig_p0_turn(sig_p0_turn_sig),
        .sig_p1_turn(sig_p1_turn_sig),
        .sig_dealer_turn(sig_dealer_turn_sig),
        
        .btn_p0_hit(btn_hit),
        .btn_p1_hit(1'b0),
        .btn_start(btn_start),
        
        .p0_bust(p0_bust_sig),
        .p1_bust(p1_bust_sig),
        .deal_done(deal_done_sig),
        .dealer_done(dealer_done_sig),
        
        .card_value(card_val_sig),
        .card_valid(card_valid_sig),
        .card_req(card_req_sig),
        
        .p0_cards(dpath_p0_cards),
        .p1_cards(dpath_p1_cards),
        .dealer_cards(dpath_dealer_cards),
        .p0_card_cnt(dpath_p0_cnt),
        .p1_card_cnt(dpath_p1_cnt),
        .dealer_card_cnt(dpath_dealer_cnt),

        .is_master(1'b1),               
        .uart_card_valid(1'b0),         
        .uart_card_val(6'd0),           
        .uart_card_dst(2'd0),           
        .uart_new_game(1'b0)           
    );

    // --- 4. MODUŁY VGA ---
    vga_timing u_vga_timing (
        .clk(clk),
        .rst_n(rst_n),
        .vga_out(vga_tim)
    );
    
    draw_bg u_draw_bg (
        .clk(clk),
        .rst_n(rst_n),
        .p1_money(16'd25), 
        .p2_money(16'd30), 
        .vga_in(vga_tim),
        .vga_out(vga_bg)
    );

    // MODUŁ RYSUJĄCY
    card_generator u_card_generator (
        .clk(clk),
        .rst_n(rst_n),
        .p0_cards(dpath_p0_cards),
        .p1_cards(dpath_p1_cards),
        .dealer_cards(dpath_dealer_cards),
        .p0_card_cnt(dpath_p0_cnt),
        .p1_card_cnt(dpath_p1_cnt),
        .dealer_card_cnt(dpath_dealer_cnt),
        .vga_in(vga_bg),
        .vga_out(vga_cards)
    );

endmodule