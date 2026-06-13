/**
 * Module name: top_menu
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-31
 * Description:   Main start menu top-level module that draws menu buttons and handles gesture-based selection.
 */

import vga_pkg::*;
import ai_type_pkg::*;

module top_menu (
    input  logic clk,
    input  logic rst_n,
    
    /* VGA input/output interfaces */
    vga_if.in  vga_in_main,
    vga_if.out vga_out_main,
    
    /* Gestures from vision module */
    input gesture_out current_gesture,
    
    /* Start screen active flag */
    input logic is_start_screen,
    
    /* Signals to game state machine */
    output logic go_to_game,
    output logic go_to_credits
);

    /* Internal signals connecting modules in pipeline (daisy-chain) */
    vga_if vga_start_bg();
    vga_if vga_text_start();

    /* 1. Draw background, buttons and handle selection logic */
    draw_start u_draw_start (
        .clk(clk),
        .rst_n(rst_n),
        .vga_in(vga_in_main),
        .vga_out(vga_start_bg), 
        .active(is_start_screen),
        .gesture_in(current_gesture),
        .event_start_game(go_to_game),
        .event_show_credits(go_to_credits)
    );

    /* 2. Overlay text on START button */
    top_string #(
        .X_POS(470),  
        .Y_POS(432),
        .ROM_DELAY(1),
        .TEXT("START")
    ) str_start (
        .clk(clk),
        .rst_n(rst_n),
        .vga_in(vga_start_bg),   /* Input with drawn buttons */
        .vga_out(vga_text_start) /* Output with START text */
    );

    /* 3. Overlay text on CREDITS button and output final image */
    top_string #(
        .X_POS(450),  
        .Y_POS(552),
        .ROM_DELAY(2),
        .TEXT("CREDITS")
    ) str_cred (
        .clk(clk),
        .rst_n(rst_n),
        .vga_in(vga_text_start), /* Input from previous text */
        .vga_out(vga_out_main)   /* Final output image */
    );

endmodule