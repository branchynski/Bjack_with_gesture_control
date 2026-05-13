/********************************************************************************
 * Package Name:   blackjack_pkg
 * Author:         Eryk Rutka
 * Date:           2026-05-13
 * Version:        1.0
 * * Description:   
 * This package contains data types, parameters for card game.
 ********************************************************************************/

 package bjack_fsm_pkg;

    typedef enum logic [2:0] {
        IDLE, 
        DEAL_INITIAL, 
        PLAYER_TURN, 
        DEALER_TURN, 
        EVALUATE, 
        GAME_OVER
    } fsm_state_t;

   
    localparam logic [4:0] MAX_SCORE    = 5'd21; 
    localparam logic [4:0] DEALER_STAND = 5'd17; 

endpackage