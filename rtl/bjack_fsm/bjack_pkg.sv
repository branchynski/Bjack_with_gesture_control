/********************************************************************************
 * Package Name:   bjack_pkg
 * Author:         Eryk Rutka
 * Date:           2026-05-15
 * Version:        1.1
 * * Description:   
 * This package contains data types, parameters for card game.
 ********************************************************************************/

 package bjack_pkg;

/* bjack_fsm  */
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

    /*card_drawing*/
    localparam logic [5:0] CARD_DECK = 6'd54;
endpackage