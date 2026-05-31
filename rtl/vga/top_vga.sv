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
    logic bust_sig;
    logic deal_done_sig;
    logic dealer_done_sig;
    
    logic sig_deal_enable_sig;
    logic sig_player_turn_sig;
    logic sig_dealer_turn_sig;
    logic busy_sig;

    // --- Kable łączące LFSR z Datapathem ---
    logic [5:0] card_val_sig;
    logic card_valid_sig;
    logic card_req_sig;

    // --- Kable łączące Datapath z modułem rysującym (VGA) ---
    logic [5:0] dpath_player_cards [0:4];
    logic [5:0] dpath_dealer_cards [0:4];
    logic [2:0] dpath_player_cnt;
    logic [2:0] dpath_dealer_cnt;

    /**
     * Signals assignments
     */

    // Wyprowadzenie ostatecznego obrazu na fizyczne piny (monitor)
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
        .btn_hit(btn_hit),
        .btn_stand(btn_stand),
        .bust(bust_sig),
        .deal_done(deal_done_sig),
        .dealer_done(dealer_done_sig),
        
        .busy(busy_sig),
        .sig_deal_enable(sig_deal_enable_sig),
        .sig_player_led(sig_player_turn_sig),
        .sig_dealer_turn(sig_dealer_turn_sig)
    );

    // --- 3. ŚCIEŻKA DANYCH (DATAPATH) ---
    bjack_datapath u_bjack_datapath (
        .clk(clk),
        .rst_n(rst_n),
        .sig_deal_enable(sig_deal_enable_sig),
        .sig_player_turn(sig_player_turn_sig),
        .sig_dealer_turn(sig_dealer_turn_sig),
        .btn_hit(btn_hit),
        .btn_start(btn_start),
        
        .bust(bust_sig),
        .deal_done(deal_done_sig),
        .dealer_done(dealer_done_sig),
        
        .card_value(card_val_sig),
        .card_valid(card_valid_sig),
        .card_req(card_req_sig),
        
        .player_cards(dpath_player_cards),
        .dealer_cards(dpath_dealer_cards),
        .player_card_cnt(dpath_player_cnt),
        .dealer_card_cnt(dpath_dealer_cnt)
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
        .vga_in(vga_tim),
        .vga_out(vga_bg)
    );

    // WŁAŚCIWA NAZWA MODUŁU RYSUJĄCEGO
    card_generator u_card_generator (
        .clk(clk),
        .rst_n(rst_n),
        .player_cards(dpath_player_cards),
        .dealer_cards(dpath_dealer_cards),
        .player_card_cnt(dpath_player_cnt),
        .dealer_card_cnt(dpath_dealer_cnt),
        .vga_in(vga_bg),
        .vga_out(vga_cards)
    );

endmodule