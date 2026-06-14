/**
 * Module name: top_menu
 * Author:      Bartlomiej Raczynski / Eryk Rutka
 * Version:     1.5 
 * Description: Main start menu top-level module. Draws buttons, 
 * gesture-based selection, and arcade instructions.
 * The scaled title is generated inside draw_start.sv.
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
 
     /* Pipeline for text overlays */
     vga_if vga_bg();
     vga_if vga_inst1();
     vga_if vga_inst2();
     vga_if vga_text_start();
 
     /* 1. Draw background, scaled title, buttons, and handle selection logic */
     draw_start u_draw_start (
         .clk(clk), 
         .rst_n(rst_n),
         .vga_in(vga_in_main), 
         .vga_out(vga_bg), 
         .active(is_start_screen),
         .gesture_in(current_gesture),
         .event_start_game(go_to_game), 
         .event_show_credits(go_to_credits)
     );
 
     /* 2. Instruction: Swipe to select (Bottom left) */
     top_string #(
         .X_POS(50), .Y_POS(730), .ROM_DELAY(2), .TEXT("\x1A SWIPE - SELECT")
     ) str_inst1 (
         .clk(clk), .rst_n(rst_n), .vga_in(vga_bg), .vga_out(vga_inst1)
     );
 
     /* 3. Instruction: Knock to enter */
     top_string #(
         .X_POS(250), .Y_POS(730), .ROM_DELAY(2), .TEXT("\x19 KNOCK - ENTER")
     ) str_inst2 (
         .clk(clk), .rst_n(rst_n), .vga_in(vga_inst1), .vga_out(vga_inst2)
     );
 
     /* 4. START button text */
     top_string #(
         .X_POS(470), .Y_POS(432), .ROM_DELAY(2), .TEXT("START")
     ) str_start (
         .clk(clk), .rst_n(rst_n), .vga_in(vga_inst2), .vga_out(vga_text_start)
     );
 
     /* 5. CREDITS button text and final output */
     top_string #(
         .X_POS(450), .Y_POS(552), .ROM_DELAY(2), .TEXT("CREDITS")
     ) str_cred (
         .clk(clk), .rst_n(rst_n), .vga_in(vga_text_start), .vga_out(vga_out_main)
     );
 
 endmodule