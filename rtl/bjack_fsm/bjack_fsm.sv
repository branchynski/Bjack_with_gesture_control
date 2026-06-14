/********************************************************************************
 * Module Name:    bjack_fsm
 * Author:         Eryk Rutka
 * Date:           2026-06-14
 * Version:        1.3 (End Screen & Gesture Exits)
 * Description:    
 * FSM updated to support dedicated GAME_OVER outputs and dual exit paths
 * (Play Again via HIT, Exit to Menu via STAND).
 ********************************************************************************/
 import bjack_pkg::*;

 module bjack_fsm(
     input  logic clk,
     input  logic rst_n,       
     input  logic btn_start,
     
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
     output logic sig_update_money,
     output logic sig_game_over,      // NOWE: Aktywuje ekran końcowy
     output logic sig_exit_to_menu    // NOWE: Budzi ekran startowy po wyjściu
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
             
             // NOWE: Dwie ścieżki wyjścia sterowane gestami gracza zerowego (Mastera)
             GAME_OVER: begin
                 if (btn_p0_hit)        state_nxt = DEAL_INITIAL; // Zagraj ponownie (KNOCK)
                 else if (btn_p0_stand) state_nxt = IDLE;         // Wyjdź do menu (SWIPE)
                 else                   state_nxt = GAME_OVER;
             end
             
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
         sig_game_over    = (state == GAME_OVER);
         sig_exit_to_menu = (state == GAME_OVER) && btn_p0_stand;
     end
 
 endmodule