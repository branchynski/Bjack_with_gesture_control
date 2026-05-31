/********************************************************************************
 * Module Name:    bjack_fsm
 * Author:         Eryk Rutka
 * Date:           2026-05-31
 * Version:        1.1
 * Description:    
 * This module implements the main control unit (Finite State Machine) 
 * for a digital card game. It manages the core game loop, 
 * managing state transitions between the initial idle screen, card dealing, 
 * the player's decision phase (Hit/Stand), the dealer's turn, and the 
 * final outcome evaluation.
 ********************************************************************************/
 import bjack_pkg::*;

 module bjack_fsm(
     input  logic clk,
     input  logic rst_n,       
     input  logic btn_start,
     input  logic btn_hit,
     input  logic btn_stand,
     input  logic bust,        
     input  logic deal_done,   
     input  logic dealer_done, 
     
     output logic busy,
     output logic sig_deal_enable,
     output logic sig_player_led,     // <-- Tu pewnie brakowało przecinka!
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
             
             DEAL_INITIAL: state_nxt = (deal_done == 1'b1) ? PLAYER_TURN : DEAL_INITIAL;
             
             PLAYER_TURN:  state_nxt = (bust == 1'b1)      ? GAME_OVER : 
                                       (btn_stand == 1'b1) ? DEALER_TURN : 
                                       PLAYER_TURN; 
             
             DEALER_TURN:  state_nxt = (dealer_done == 1'b1) ? EVALUATE : DEALER_TURN;
             
             EVALUATE:     state_nxt = GAME_OVER; 
             
             GAME_OVER:    state_nxt = (btn_start == 1'b1) ? IDLE : GAME_OVER; 
             
             default:      state_nxt = IDLE;
         endcase
     end
 
     always_comb begin
         busy             = (state != IDLE) && (state != GAME_OVER);
         sig_deal_enable  = (state == DEAL_INITIAL);
         sig_player_led   = (state == PLAYER_TURN);
         sig_dealer_turn  = (state == DEALER_TURN);
         sig_update_money = (state == EVALUATE);
     end
 
 endmodule