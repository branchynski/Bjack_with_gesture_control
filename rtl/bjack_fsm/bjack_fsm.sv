/********************************************************************************
 * Module Name:    bjack_fsm
 * Author:         Eryk Rutka
 * Date:           2026-06-02
 * Version:        1.2 (Multiplayer Update)
 * Description:    
 * This module implements the main control unit (Finite State Machine) 
 * for a digital card game. It manages the core game loop, 
 * managing state transitions between the initial idle screen, card dealing, 
 * the players' decision phases (Hit/Stand), the dealer's turn, and the 
 * final outcome evaluation.
 ********************************************************************************/
 import bjack_pkg::*;

 module bjack_fsm(
     input  logic clk,
     input  logic rst_n,       
     input  logic btn_start,
     
     // Podział na dwa zestawy wejść
     input  logic btn_p0_hit,
     input  logic btn_p0_stand,
     input  logic btn_p1_hit,
     input  logic btn_p1_stand,
     input  logic p0_bust,        
     input  logic p1_bust,        
     
     input  logic deal_done,   
     input  logic dealer_done, 
     
     output logic busy,
     output logic sig_deal_enable,
     output logic sig_p0_turn,     
     output logic sig_p1_turn,     
     output logic sig_dealer_turn,
     output logic sig_update_money
 );
 
     fsm_state_t state, state_nxt;
 
     always_ff @(posedge clk, negedge rst_n) begin
         if (!rst_n)
             state <= IDLE;
         else
             state <= state_nxt;
     end
 
     always_comb begin
         case (state)
             IDLE:         state_nxt = (btn_start == 1'b1) ? DEAL_INITIAL : IDLE;
             
             DEAL_INITIAL: state_nxt = (deal_done == 1'b1) ? P0_TURN : DEAL_INITIAL;
             
             P0_TURN:      state_nxt = (p0_bust == 1'b1 || btn_p0_stand == 1'b1) ? P1_TURN : P0_TURN; 
             
             P1_TURN:      state_nxt = (p1_bust == 1'b1 || btn_p1_stand == 1'b1) ? DEALER_TURN : P1_TURN; 
             
             DEALER_TURN:  state_nxt = (dealer_done == 1'b1) ? EVALUATE : DEALER_TURN;
             
             EVALUATE:     state_nxt = GAME_OVER; 
             
             GAME_OVER:    state_nxt = (btn_start == 1'b1) ? IDLE : GAME_OVER; 
             
             default:      state_nxt = IDLE;
         endcase
     end
 
     always_comb begin
         busy             = (state != IDLE) && (state != GAME_OVER);
         sig_deal_enable  = (state == DEAL_INITIAL);
         sig_p0_turn      = (state == P0_TURN);
         sig_p1_turn      = (state == P1_TURN);
         sig_dealer_turn  = (state == DEALER_TURN);
         sig_update_money = (state == EVALUATE);
     end
 
 endmodule