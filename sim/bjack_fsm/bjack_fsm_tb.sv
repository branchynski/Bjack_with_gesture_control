/********************************************************************************
 * Module Name:     tb_bjack_fsm
 * Author:          Eryk Rutka
 * Version:         1.0
 * Last modified:   2026-05-13
 * Description:     Testbench verifying the card game FSM behavior. 
 * It simulates two main game scenarios: a standard game loop 
 * (Hit & Stand) and an immediate player bust condition.
 ********************************************************************************/

 module bjack_fsm_tb();

    timeunit 1ns;
    timeprecision 1ps;

    logic clk;
    logic rst_n;
    logic btn_start;
    logic btn_hit;
    logic btn_stand;
    logic bust;
    logic deal_done;
    logic dealer_done;

    logic busy;
    logic sig_deal_enable;
    logic sig_player_led;

    bjack_fsm uut (
        .clk(clk),
        .rst_n(rst_n),
        .btn_start(btn_start),
        .btn_hit(btn_hit),
        .btn_stand(btn_stand),
        .bust(bust),
        .deal_done(deal_done),
        .dealer_done(dealer_done),
        .busy(busy),
        .sig_deal_enable(sig_deal_enable),
        .sig_player_led(sig_player_led)
    );

    always #5 clk = ~clk;
    
    initial begin
        $display("--- Starting Blackjack FSM Simulation ---");

        /* Init signals */
        clk = 0;
        rst_n = 0; 
        btn_start = 0;
        btn_hit = 0;
        btn_stand = 0;
        bust = 0;
        deal_done = 0;
        dealer_done = 0;

        #20;
        rst_n = 1; 
        $display("[%0t ns] Reset released. FSM in IDLE.      | busy: %b, deal_en: %b, led: %b", $time, busy, sig_deal_enable, sig_player_led);
        #20;

        /* --- Scenario 1: Normal Play (Hit & Stand) ---*/
        $display("[%0t ns] --- RUNNING SCENARIO 1: Normal Play ---", $time);

        btn_start = 1; 
        #10;           
        btn_start = 0; 
        $display("[%0t ns] START -> DEAL_INITIAL.            | busy: %b, deal_en: %b, led: %b", $time, busy, sig_deal_enable, sig_player_led);
        
        #30;

        deal_done = 1;
        #10;
        deal_done = 0;
        $display("[%0t ns] Deal done -> PLAYER_TURN.         | busy: %b, deal_en: %b, led: %b", $time, busy, sig_deal_enable, sig_player_led);

        #20;

        btn_hit = 1;
        #10;
        btn_hit = 0;
        $display("[%0t ns] Hit.                              | busy: %b, deal_en: %b, led: %b", $time, busy, sig_deal_enable, sig_player_led);
        
        #30;

        btn_stand = 1;
        #10;
        btn_stand = 0;
        $display("[%0t ns] Stand -> DEALER_TURN.             | busy: %b, deal_en: %b, led: %b", $time, busy, sig_deal_enable, sig_player_led);
        
        #40;

        dealer_done = 1;
        #10;
        dealer_done = 0;
        $display("[%0t ns] Dealer done -> EVALUATE -> OVER.  | busy: %b, deal_en: %b, led: %b", $time, busy, sig_deal_enable, sig_player_led);

        #40;

        btn_start = 1;
        #10;
        btn_start = 0;
        $display("[%0t ns] OVER -> IDLE.       | busy: %b, deal_en: %b, led: %b", $time, busy, sig_deal_enable, sig_player_led);
        #20;

        /* --- Scenario 2: Player Bust ---*/
        $display("[%0t ns] --- RUNNING SCENARIO 2: Player Bust ---", $time);

        btn_start = 1;
        #10;
        btn_start = 0;
        $display("[%0t ns] START -> DEAL_INITIAL.            | busy: %b, deal_en: %b, led: %b", $time, busy, sig_deal_enable, sig_player_led);
        
        #30;

        deal_done = 1;
        #10;
        deal_done = 0;
        $display("[%0t ns] Deal done -> PLAYER_TURN.         | busy: %b, deal_en: %b, led: %b", $time, busy, sig_deal_enable, sig_player_led);
        
        #20;

        btn_hit = 1;
        #10;
        btn_hit = 0;
        $display("[%0t ns] Hit.                              | busy: %b, deal_en: %b, led: %b", $time, busy, sig_deal_enable, sig_player_led);
        
        #10; 
        
        bust = 1; /* Player score > 21 */
        #10;
        bust = 0; 
        $display("[%0t ns] Bust flag! -> GAME_OVER.          | busy: %b, deal_en: %b, led: %b", $time, busy, sig_deal_enable, sig_player_led);

        #40;

        $display("[%0t ns] --- Simulation Complete ---", $time);
        $finish; 
    end

endmodule