/**
 * Module name: draw_start
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-31
 * Description:   Draws the start screen background and buttons, processes gesture navigation and selection.
 */

 import vga_pkg::*;
 import ai_type_pkg::*;
 
 module draw_start (
     input  logic clk,
     input  logic rst_n,
 
     vga_if.in  vga_in,
     vga_if.out vga_out,
     
     input  logic active,
     
     input  gesture_out gesture_in,
     
     output logic event_start_game,
     output logic event_show_credits
 );
 
     timeunit 1ns;
     timeprecision 1ps;
 
     /* --- UI parameters (Resolution 1024x768) --- */
     localparam START_X_MIN = 384, START_X_MAX = 640;
     localparam START_Y_MIN = 400, START_Y_MAX = 480;
 
     localparam CRED_X_MIN = 384, CRED_X_MAX = 640;
     localparam CRED_Y_MIN = 520, CRED_Y_MAX = 600;
 
     localparam COLOR_BG       = 12'h0_6_0; 
     localparam COLOR_BTN_IDLE = 12'h2_2_2; 
     localparam COLOR_BTN_HOV  = 12'hC_A_5; 
 
     logic [11:0] rgb_nxt;
     
     (* keep = "true" *) logic [11:0] dummy_rgb;
     assign dummy_rgb = vga_in.rgb;
 
     gesture_out gesture_q;
     logic swipe_pulse;
     logic knock_pulse;
 
     always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             gesture_q <= NOTHING;
         end else begin
             gesture_q <= gesture_in;
         end
     end
 
     // Respond only to a new gesture change
     assign swipe_pulse = (gesture_in == SWIPE_RIGHT) && (gesture_q != SWIPE_RIGHT);
     assign knock_pulse = (gesture_in == KNOCK) && (gesture_q != KNOCK);
 
     // --- Menu state (button selection) ---
     // 0 = START, 1 = CREDITS
     logic btn_select; 
 
     always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             btn_select <= 1'b0; // Default selected START
             event_start_game <= 1'b0;
             event_show_credits <= 1'b0;
         end else if (active) begin
             // Clear output pulses
             event_start_game <= 1'b0;
             event_show_credits <= 1'b0;
 
             if (swipe_pulse) begin
                 btn_select <= ~btn_select; // Toggle selection
             end
 
             if (knock_pulse) begin
                 if (btn_select == 1'b0) event_start_game <= 1'b1;
                 else                    event_show_credits <= 1'b1;
             end
         end
     end
 
     // --- Drawing logic (positioning) ---
     logic is_start_pixel;
     logic is_cred_pixel;
     
     always_comb begin
         is_start_pixel = (vga_in.hcount >= START_X_MIN && vga_in.hcount <= START_X_MAX) &&
                          (vga_in.vcount >= START_Y_MIN && vga_in.vcount <= START_Y_MAX);
                          
         is_cred_pixel  = (vga_in.hcount >= CRED_X_MIN && vga_in.hcount <= CRED_X_MAX) &&
                          (vga_in.vcount >= CRED_Y_MIN && vga_in.vcount <= CRED_Y_MAX);
     end
 
     // --- VGA output registers (pipeline) ---
     always_ff @(posedge clk or negedge rst_n) begin : bg_ff_blk
         if (!rst_n) begin
             vga_out.vcount <= '0;
             vga_out.vsync  <= '0;
             vga_out.vblnk  <= '0;
             vga_out.hcount <= '0;
             vga_out.hsync  <= '0;
             vga_out.hblnk  <= '0;
             vga_out.rgb    <= '0;
         end else begin
             vga_out.vcount <= vga_in.vcount;
             vga_out.vsync  <= vga_in.vsync;
             vga_out.vblnk  <= vga_in.vblnk;
             vga_out.hcount <= vga_in.hcount;
             vga_out.hsync  <= vga_in.hsync;
             vga_out.hblnk  <= vga_in.hblnk;
             vga_out.rgb    <= rgb_nxt;
         end
     end
 
     // --- Color generator ---
     always_comb begin : bg_comb_blk
         if (vga_in.vblnk || vga_in.hblnk) begin           
             rgb_nxt = 12'h0_0_0;                   
         end else begin
             if (active) begin
                 if (is_start_pixel) begin
                     // If btn_select == 0, highlight in gold
                     rgb_nxt = (btn_select == 1'b0) ? COLOR_BTN_HOV : COLOR_BTN_IDLE;
                 end else if (is_cred_pixel) begin
                     // If btn_select == 1, highlight in gold
                     rgb_nxt = (btn_select == 1'b1) ? COLOR_BTN_HOV : COLOR_BTN_IDLE;
                 end else begin
                     // Background
                     rgb_nxt = COLOR_BG;              
                 end
             end else begin
                 // If screen inactive, pass through image from previous module
                 rgb_nxt = vga_in.rgb;                   
             end                                   
         end
     end
 
 endmodule