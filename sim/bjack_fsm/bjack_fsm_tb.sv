/********************************************************************************
 * Module Name:     tb_bjack_fsm
 * Author:          Eryk Rutka
 * Version:         1.2 (Multiplayer Update)
 * Last modified:   2026-06-02
 * Description:     Testbench verifying the card game FSM behavior for TWO players. 
 * It simulates two main game scenarios: a standard game loop 
 * (Hits & Stands for P0 and P1) and bust conditions for both players.
 ********************************************************************************/

 module bjack_fsm_tb();

    timeunit 1ns;
    timeprecision 1ps;

    logic clk;
    logic rst_n;
    logic btn_start;
    
    // Sygnały P0
    logic btn_p0_hit;
    logic btn_p0_stand;
    logic p0_bust;
    
    // Sygnały P1
    logic btn_p1_hit;
    logic btn_p1_stand;
    logic p1_bust;
    
    logic deal_done;
    logic dealer_done;

    // Wyjścia z FSM
    logic busy;
    logic sig_deal_enable;
    logic sig_p0_turn;
    logic sig_p1_turn;
    logic sig_dealer_turn;
    logic sig_update_money;

    bjack_fsm uut (
        .clk(clk),
        .rst_n(rst_n),
        .btn_start(btn_start),
        
        .btn_p0_hit(btn_p0_hit),
        .btn_p0_stand(btn_p0_stand),
        .btn_p1_hit(btn_p1_hit),
        .btn_p1_stand(btn_p1_stand),
        
        .p0_bust(p0_bust),
        .p1_bust(p1_bust),
        .deal_done(deal_done),
        .dealer_done(dealer_done),
        
        .busy(busy),
        .sig_deal_enable(sig_deal_enable),
        .sig_p0_turn(sig_p0_turn),
        .sig_p1_turn(sig_p1_turn),
        .sig_dealer_turn(sig_dealer_turn),
        .sig_update_money(sig_update_money)
    );

    always #5 clk = ~clk;
    
    initial begin
        $display("--- Starting Multiplayer Blackjack FSM Simulation ---");

        /* Init signals */
        clk = 0;
        rst_n = 0; 
        btn_start = 0;
        
        btn_p0_hit = 0; btn_p0_stand = 0; p0_bust = 0;
        btn_p1_hit = 0; btn_p1_stand = 0; p1_bust = 0;
        
        deal_done = 0; dealer_done = 0;

        #20;
        rst_n = 1; 
        $display("[%0t ns] Reset released. FSM in IDLE.      | p0_turn: %b, p1_turn: %b", $time, sig_p0_turn, sig_p1_turn);
        #20;

        /* --- Scenario 1: Normal Play (P0 & P1 Hit & Stand) ---*/
        $display("[%0t ns] --- RUNNING SCENARIO 1: Normal Play (Both Players) ---", $time);

        btn_start = 1; 
        #10;           
        btn_start = 0; 
        $display("[%0t ns] START -> DEAL_INITIAL.            | deal_en: %b", $time, sig_deal_enable);
        
        #30;

        deal_done = 1;
        #10;
        deal_done = 0;
        $display("[%0t ns] Deal done -> P0_TURN.             | p0_turn: %b, p1_turn: %b", $time, sig_p0_turn, sig_p1_turn);

        #20;

        // Ruchy Gracza 0
        btn_p0_hit = 1;
        #10; btn_p0_hit = 0;
        $display("[%0t ns] P0 Hit.                           | p0_turn: %b", $time, sig_p0_turn);
        #30;

        btn_p0_stand = 1;
        #10; btn_p0_stand = 0;
        $display("[%0t ns] P0 Stand -> P1_TURN.              | p0_turn: %b, p1_turn: %b", $time, sig_p0_turn, sig_p1_turn);
        
        #20;

        // Ruchy Gracza 1
        btn_p1_hit = 1;
        #10; btn_p1_hit = 0;
        $display("[%0t ns] P1 Hit.                           | p1_turn: %b", $time, sig_p1_turn);
        #30;

        btn_p1_stand = 1;
        #10; btn_p1_stand = 0;
        $display("[%0t ns] P1 Stand -> DEALER_TURN.          | p1_turn: %b, dealer_turn: %b", $time, sig_p1_turn, sig_dealer_turn);
        
        #40;

        // Krupier kończy
        dealer_done = 1;
        #10;
        dealer_done = 0;
        $display("[%0t ns] Dealer done -> EVALUATE -> OVER.  | eval: %b, busy: %b", $time, sig_update_money, busy);

        #40;

        // Nowa runda
        btn_start = 1;
        #10;
        btn_start = 0;
        $display("[%0t ns] OVER -> IDLE -> DEAL_INITIAL.     | deal_en: %b", $time, sig_deal_enable);
        #30;

        /* --- Scenario 2: Double Bust ---*/
        $display("[%0t ns] --- RUNNING SCENARIO 2: Double Bust ---", $time);

        deal_done = 1;
        #10; deal_done = 0;
        $display("[%0t ns] Deal done -> P0_TURN.             | p0_turn: %b", $time, sig_p0_turn);
        
        #20;

        // Gracz 0 Bust
        btn_p0_hit = 1;
        #10; btn_p0_hit = 0;
        #10; 
        p0_bust = 1; /* P0 score > 21 */
        #10; p0_bust = 0; 
        $display("[%0t ns] P0 Bust! -> P1_TURN.              | p0_turn: %b, p1_turn: %b", $time, sig_p0_turn, sig_p1_turn);

        #30;

        // Gracz 1 Bust
        btn_p1_hit = 1;
        #10; btn_p1_hit = 0;
        #10; 
        p1_bust = 1; /* P1 score > 21 */
        #10; p1_bust = 0; 
        $display("[%0t ns] P1 Bust! -> DEALER_TURN.          | p1_turn: %b, dealer_turn: %b", $time, sig_p1_turn, sig_dealer_turn);

        #40;
        
        dealer_done = 1;
        #10; dealer_done = 0;
        $display("[%0t ns] Dealer done -> EVALUATE -> OVER.  | eval: %b", $time, sig_update_money);

        #40;
        $display("[%0t ns] --- Simulation Complete ---", $time);
        $finish; 
    end

endmodule