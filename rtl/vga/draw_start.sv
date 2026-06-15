/**
 * Module name: draw_start
 * Author:      Bartlomiej Raczynski / Eryk Rutka
 * Version:     2.0 (Hardcoded Scaled Title)
 * Description: Draws the start screen background, buttons, and scaled title.
 * Processes gesture navigation and selection.
 * Title scaling is implemented using pure bit-slicing for synthesis.
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
 
     /* UI parameters (Resolution 1024x768) */
     localparam START_X_MIN = 384, START_X_MAX = 640;
     localparam START_Y_MIN = 400, START_Y_MAX = 480;
 
     localparam CRED_X_MIN = 384, CRED_X_MAX = 640;
     localparam CRED_Y_MIN = 520, CRED_Y_MAX = 600;
 
     /* Title Box (15 chars * 32px = 480px width, centered at X=272) */
     localparam TITLE_X_MIN = 272, TITLE_X_MAX = 752; 
     localparam TITLE_Y_MIN = 150, TITLE_Y_MAX = 214; 
 
     localparam COLOR_BG       = 12'h0_6_0; 
     localparam COLOR_BTN_IDLE = 12'h2_2_2; 
     localparam COLOR_BTN_HOV  = 12'hC_A_5; 
     localparam COLOR_TITLE    = 12'h0_0_0; 
 
     logic [11:0] rgb_bg;
 
     gesture_out gesture_q;
     logic swipe_pulse;
     logic knock_pulse;
 
     /* Gesture edge detection */
     always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             gesture_q <= NOTHING;
         end else begin
             gesture_q <= gesture_in;
         end
     end
 
     assign swipe_pulse = (gesture_in == SWIPE_RIGHT) && (gesture_q != SWIPE_RIGHT);
     assign knock_pulse = (gesture_in == KNOCK) && (gesture_q != KNOCK);
 
     /* Menu state (button selection) */
     logic btn_select; 
 
     always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             btn_select <= 1'b0; 
             event_start_game <= 1'b0;
             event_show_credits <= 1'b0;
         end else if (active) begin
             event_start_game <= 1'b0;
             event_show_credits <= 1'b0;
 
             if (swipe_pulse) begin
                 btn_select <= ~btn_select; 
             end
 
             if (knock_pulse) begin
                 if (btn_select == 1'b0) event_start_game <= 1'b1;
                 else                    event_show_credits <= 1'b1;
             end
         end
     end
 
     /* Drawing logic (positioning) */
     logic is_start_pixel;
     logic is_cred_pixel;
     logic in_title_box;
     
     logic [7:0] target_char;
     logic [10:0] rom_addr;
     logic [2:0] char_x_bit;
     logic [3:0] char_y_line;
 
     logic [10:0] title_x_diff;
     logic [10:0] title_y_diff;
 
     always_comb begin
         is_start_pixel = (vga_in.hcount >= START_X_MIN && vga_in.hcount <= START_X_MAX) &&
                          (vga_in.vcount >= START_Y_MIN && vga_in.vcount <= START_Y_MAX);
                          
         is_cred_pixel  = (vga_in.hcount >= CRED_X_MIN && vga_in.hcount <= CRED_X_MAX) &&
                          (vga_in.vcount >= CRED_Y_MIN && vga_in.vcount <= CRED_Y_MAX);
 
         in_title_box = (vga_in.hcount >= TITLE_X_MIN && vga_in.hcount < TITLE_X_MAX) &&
                        (vga_in.vcount >= TITLE_Y_MIN && vga_in.vcount < TITLE_Y_MAX);
 
         title_x_diff = vga_in.hcount - 11'd272;
         title_y_diff = vga_in.vcount - 11'd150;
 
         /* Title generation (Scale x4 via wire slicing) */
         target_char = 8'h20; 
         char_x_bit = '0; 
         char_y_line = '0; 
         rom_addr = '0;
 
         if (active && in_title_box) begin
             /* Slice bits to simulate division by 4 */
             char_x_bit  = title_x_diff[4:2]; 
             char_y_line = title_y_diff[5:2];
             
             /* Slice bits to simulate division by 32 (character index) */
             case (title_x_diff[9:5])
                 0:  target_char = 8'h42; /* B */
                 1:  target_char = 8'h4A; /* J */
                 2:  target_char = 8'h41; /* A */
                 3:  target_char = 8'h43; /* C */
                 4:  target_char = 8'h4B; /* K */
                 5:  target_char = 8'h20; /* */
                 6:  target_char = 8'h43; /* C */
                 7:  target_char = 8'h41; /* A */
                 8:  target_char = 8'h52; /* R */
                 9:  target_char = 8'h44; /* D */
                 10: target_char = 8'h20; /* */
                 11: target_char = 8'h47; /* G */
                 12: target_char = 8'h41; /* A */
                 13: target_char = 8'h4D; /* M */
                 14: target_char = 8'h45; /* E */
                 default: target_char = 8'h20;
             endcase
             rom_addr = {target_char[6:0], char_y_line};
         end
 
         /* Background Color logic */
         if (vga_in.vblnk || vga_in.hblnk) begin           
             rgb_bg = 12'h0_0_0;                   
         end else begin
             if (active) begin
                 if (is_start_pixel) begin
                     rgb_bg = (btn_select == 1'b0) ? COLOR_BTN_HOV : COLOR_BTN_IDLE;
                 end else if (is_cred_pixel) begin
                     rgb_bg = (btn_select == 1'b1) ? COLOR_BTN_HOV : COLOR_BTN_IDLE;
                 end else begin
                     rgb_bg = COLOR_BG;              
                 end
             end else begin
                 /* Passthrough when inactive */
                 rgb_bg = vga_in.rgb;                   
             end                                   
         end
     end
 
     /* ROM instance for title font */
     logic [7:0] rom_pixels;
     font_rom u_font_rom (
         .clk(clk), 
         .addr(rom_addr), 
         .char_line_pixels(rom_pixels)
     );
 
     /* Delay line to match ROM latency (1 clock cycle) */
     localparam DEL_W = 11 + 11 + 1 + 1 + 1 + 1 + 12 + 1 + 3; 
     logic [DEL_W-1:0] delay_in, delay_out;
 
     assign delay_in = {
         vga_in.hcount, vga_in.vcount, vga_in.hsync, vga_in.vsync, vga_in.hblnk, vga_in.vblnk, 
         rgb_bg, 
         in_title_box, char_x_bit
     };
 
     logic [10:0] d_hcount, d_vcount;
     logic d_hsync, d_vsync, d_hblnk, d_vblnk;
     logic [11:0] d_rgb_bg;
     logic d_in_title_box;
     logic [2:0] d_char_x_bit;
 
     assign {
         d_hcount, d_vcount, d_hsync, d_vsync, d_hblnk, d_vblnk, 
         d_rgb_bg, 
         d_in_title_box, d_char_x_bit
     } = delay_out;
 
     delay #(
         .WIDTH(DEL_W), 
         .CLK_DEL(1)
     ) u_delay (
         .clk(clk), 
         .rst_n(rst_n), 
         .din(delay_in), 
         .dout(delay_out)
     );
 
     /* Final output registers (paintbrush) */
     always_ff @(posedge clk or negedge rst_n) begin : output_ff_blk
         if (!rst_n) begin
             vga_out.vcount <= '0;
             vga_out.vsync  <= '0;
             vga_out.vblnk  <= '0;
             vga_out.hcount <= '0;
             vga_out.hsync  <= '0;
             vga_out.hblnk  <= '0;
             vga_out.rgb    <= '0;
         end else begin
             vga_out.hcount <= d_hcount;
             vga_out.vsync  <= d_vsync;
             vga_out.vblnk  <= d_vblnk;
             vga_out.vcount <= d_vcount;
             vga_out.hsync  <= d_hsync;
             vga_out.hblnk  <= d_hblnk;
             
             /* Draw title text if active */
             if (active && d_in_title_box && rom_pixels[7 - d_char_x_bit]) begin
                 vga_out.rgb <= COLOR_TITLE;
             end else begin
                 vga_out.rgb <= d_rgb_bg;
             end
         end
     end
 
 endmodule