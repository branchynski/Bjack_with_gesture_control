/********************************************************************************
 * Module Name:    draw_game_over
 * Author:         Eryk Rutka / Bartłomiej Raczyński
 * Date:           2026-06-14
 * Version:        1.0
 * Description:    
 * End-screen overlay. Dims the background and displays the final scores, 
 * win/loss statuses with money changes, and gesture instructions.
 * Transparent when sig_game_over is low.
 ********************************************************************************/

 import vga_pkg::*;

 module draw_game_over (
     input  logic clk,
     input  logic rst_n,
     
     input  logic sig_game_over,
     
     // Game results
     input  logic [5:0] p0_score,
     input  logic [5:0] p1_score,
     input  logic [5:0] d_score,
     
     input  logic p0_win,
     input  logic p0_draw,
     input  logic p1_win,
     input  logic p1_draw,
     
     vga_if.in  vga_in,
     vga_if.out vga_out
 );
 
     timeunit 1ns;
     timeprecision 1ps;
 
     // --- Results panel dimensions ---
     localparam PANEL_X = 250;
     localparam PANEL_W = 524;
     localparam PANEL_Y = 150;
     localparam PANEL_H = 468;
 
     // --- Text positioning logic ---
     logic in_panel, in_border;
     logic in_title, in_d_score, in_p0_score, in_p0_res, in_p1_score, in_p1_res;
     logic in_instr1, in_instr2;
     
     logic [7:0] target_char;
     logic [10:0] rom_addr;
     logic [2:0] char_x_bit;
     logic [3:0] char_y_line; 
 
     always_comb begin
         in_panel = (vga_in.hcount >= PANEL_X && vga_in.hcount < PANEL_X + PANEL_W &&
                     vga_in.vcount >= PANEL_Y && vga_in.vcount < PANEL_Y + PANEL_H);
         in_border = in_panel && (vga_in.hcount < PANEL_X + 4 || vga_in.hcount >= PANEL_X + PANEL_W - 4 ||
                                  vga_in.vcount < PANEL_Y + 4 || vga_in.vcount >= PANEL_Y + PANEL_H - 4);
 
         in_title = 1'b0; in_d_score = 1'b0; 
         in_p0_score = 1'b0; in_p0_res = 1'b0; 
         in_p1_score = 1'b0; in_p1_res = 1'b0;
         in_instr1 = 1'b0; in_instr2 = 1'b0;
         
         target_char = 8'h20; char_x_bit = '0; char_y_line = '0; rom_addr = '0;
 
         if (sig_game_over && in_panel && !in_border) begin
             // --- Title: "GAME OVER" (Y: 180) ---
             if (vga_in.vcount >= 180 && vga_in.vcount < 212 && vga_in.hcount >= 440 && vga_in.hcount < 584) begin
                 in_title = 1'b1;
                 char_x_bit = (vga_in.hcount - 440) >> 1; char_y_line = (vga_in.vcount - 180) >> 1;
                 case ((vga_in.hcount - 440) >> 4)
                     0: target_char=8'h47; 1: target_char=8'h41; 2: target_char=8'h4D; 3: target_char=8'h45;
                     4: target_char=8'h20; 5: target_char=8'h4F; 6: target_char=8'h56; 7: target_char=8'h45; 8: target_char=8'h52;
                     default: target_char=8'h20;
                 endcase
             end
             // --- "DEALER: XX" (Y: 260) ---
             else if (vga_in.vcount >= 260 && vga_in.vcount < 292 && vga_in.hcount >= 300 && vga_in.hcount < 460) begin
                 in_d_score = 1'b1;
                 char_x_bit = (vga_in.hcount - 300) >> 1; char_y_line = (vga_in.vcount - 260) >> 1;
                 case ((vga_in.hcount - 300) >> 4)
                     0: target_char=8'h44; 1: target_char=8'h45; 2: target_char=8'h41; 3: target_char=8'h4C;
                     4: target_char=8'h45; 5: target_char=8'h52; 6: target_char=8'h3A; 7: target_char=8'h20;
                     8: target_char=8'h30 + (d_score / 10); 9: target_char=8'h30 + (d_score % 10);
                     default: target_char=8'h20;
                 endcase
             end
             // --- "P0: XX" (Y: 340) ---
             else if (vga_in.vcount >= 340 && vga_in.vcount < 372 && vga_in.hcount >= 300 && vga_in.hcount < 396) begin
                 in_p0_score = 1'b1;
                 char_x_bit = (vga_in.hcount - 300) >> 1; char_y_line = (vga_in.vcount - 340) >> 1;
                 case ((vga_in.hcount - 300) >> 4)
                     0: target_char=8'h50; 1: target_char=8'h30; 2: target_char=8'h3A; 3: target_char=8'h20;
                     4: target_char=8'h30 + (p0_score / 10); 5: target_char=8'h30 + (p0_score % 10);
                     default: target_char=8'h20;
                 endcase
             end
             // --- P0 result: "WON +$100" / "LOST -$100" (Y: 340, X: 500) ---
             else if (vga_in.vcount >= 340 && vga_in.vcount < 372 && vga_in.hcount >= 500 && vga_in.hcount < 660) begin
                 in_p0_res = 1'b1;
                 char_x_bit = (vga_in.hcount - 500) >> 1; char_y_line = (vga_in.vcount - 340) >> 1;
                 case ((vga_in.hcount - 500) >> 4)
                     0: target_char= p0_draw ? 8'h44 : (p0_win ? 8'h57 : 8'h4C); // D / W / L
                     1: target_char= p0_draw ? 8'h52 : (p0_win ? 8'h4F : 8'h4F); // R / O / O
                     2: target_char= p0_draw ? 8'h41 : (p0_win ? 8'h4E : 8'h53); // A / N / S
                     3: target_char= p0_draw ? 8'h57 : (p0_win ? 8'h20 : 8'h54); // W /   / T
                     4: target_char= 8'h20;
                     5: target_char= p0_draw ? 8'h20 : (p0_win ? 8'h2B : 8'h2D); //   / + / -
                     6: target_char= p0_draw ? 8'h20 : 8'h24;                    //   / $ / $
                     7: target_char= p0_draw ? 8'h20 : 8'h31;                    // 1
                     8: target_char= p0_draw ? 8'h20 : 8'h30;                    // 0
                     9: target_char= p0_draw ? 8'h20 : 8'h30;                    // 0
                     default: target_char=8'h20;
                 endcase
             end
             // --- "P1: XX" (Y: 420) ---
             else if (vga_in.vcount >= 420 && vga_in.vcount < 452 && vga_in.hcount >= 300 && vga_in.hcount < 396) begin
                 in_p1_score = 1'b1;
                 char_x_bit = (vga_in.hcount - 300) >> 1; char_y_line = (vga_in.vcount - 420) >> 1;
                 case ((vga_in.hcount - 300) >> 4)
                     0: target_char=8'h50; 1: target_char=8'h31; 2: target_char=8'h3A; 3: target_char=8'h20;
                     4: target_char=8'h30 + (p1_score / 10); 5: target_char=8'h30 + (p1_score % 10);
                     default: target_char=8'h20;
                 endcase
             end
             // --- P1 result: "WON +$100" / "LOST -$100" (Y: 420, X: 500) ---
             else if (vga_in.vcount >= 420 && vga_in.vcount < 452 && vga_in.hcount >= 500 && vga_in.hcount < 660) begin
                 in_p1_res = 1'b1;
                 char_x_bit = (vga_in.hcount - 500) >> 1; char_y_line = (vga_in.vcount - 420) >> 1;
                 case ((vga_in.hcount - 500) >> 4)
                     0: target_char= p1_draw ? 8'h44 : (p1_win ? 8'h57 : 8'h4C); 
                     1: target_char= p1_draw ? 8'h52 : (p1_win ? 8'h4F : 8'h4F); 
                     2: target_char= p1_draw ? 8'h41 : (p1_win ? 8'h4E : 8'h53); 
                     3: target_char= p1_draw ? 8'h57 : (p1_win ? 8'h20 : 8'h54); 
                     4: target_char= 8'h20;
                     5: target_char= p1_draw ? 8'h20 : (p1_win ? 8'h2B : 8'h2D); 
                     6: target_char= p1_draw ? 8'h20 : 8'h24;                    
                     7: target_char= p1_draw ? 8'h20 : 8'h31;                    
                     8: target_char= p1_draw ? 8'h20 : 8'h30;                    
                     9: target_char= p1_draw ? 8'h20 : 8'h30;                    
                     default: target_char=8'h20;
                 endcase
             end
             // --- Instruction 1: KNOCK (Y: 520) ---
             else if (vga_in.vcount >= 520 && vga_in.vcount < 552 && vga_in.hcount >= 360 && vga_in.hcount < 664) begin
                 in_instr1 = 1'b1;
                 char_x_bit = (vga_in.hcount - 360) >> 1; char_y_line = (vga_in.vcount - 520) >> 1;
                 case ((vga_in.hcount - 360) >> 4)
                     0: target_char=8'h19; // Arrow down
                     1: target_char=8'h20; 2: target_char=8'h4B; 3: target_char=8'h4E; 4: target_char=8'h4F;
                     5: target_char=8'h43; 6: target_char=8'h4B; 7: target_char=8'h20; 8: target_char=8'h2D;
                     9: target_char=8'h20; 10:target_char=8'h50; 11:target_char=8'h4C; 12:target_char=8'h41;
                     13:target_char=8'h59; 14:target_char=8'h20; 15:target_char=8'h41; 16:target_char=8'h47;
                     17:target_char=8'h41; 18:target_char=8'h49; 19:target_char=8'h4E;
                     default: target_char=8'h20;
                 endcase
             end
             // --- Instruction 2: SWIPE (Y: 560) ---
             else if (vga_in.vcount >= 560 && vga_in.vcount < 592 && vga_in.hcount >= 360 && vga_in.hcount < 648) begin
                 in_instr2 = 1'b1;
                 char_x_bit = (vga_in.hcount - 360) >> 1; char_y_line = (vga_in.vcount - 560) >> 1;
                 case ((vga_in.hcount - 360) >> 4)
                     0: target_char=8'h1A; //  Arrow right
                     1: target_char=8'h20; 2: target_char=8'h53; 3: target_char=8'h57; 4: target_char=8'h49;
                     5: target_char=8'h50; 6: target_char=8'h45; 7: target_char=8'h20; 8: target_char=8'h2D;
                     9: target_char=8'h20; 10:target_char=8'h45; 11:target_char=8'h58; 12:target_char=8'h49;
                     13:target_char=8'h54; 14:target_char=8'h20; 15:target_char=8'h54; 16:target_char=8'h4F;
                     17:target_char=8'h20; 18:target_char=8'h4D; 19:target_char=8'h45; 20:target_char=8'h4E;
                     21:target_char=8'h55;
                     default: target_char=8'h20;
                 endcase
             end
             rom_addr = {target_char[6:0], char_y_line};
         end
     end
 
     // --- ROM ---
     logic [7:0] rom_pixels;
     font_rom u_font_rom (
         .clk(clk), .addr(rom_addr), .char_line_pixels(rom_pixels)
     );
 
     // --- Delay ---
     localparam DEL_W = 11 + 11 + 1 + 1 + 1 + 1 + 12 + 8 + 3 + 4; 
     logic [DEL_W-1:0] delay_in, delay_out;
 
     // (Dimming) - darker backgeround
     logic [11:0] dimmed_bg;
     assign dimmed_bg = {1'b0, vga_in.rgb[11:9], 1'b0, vga_in.rgb[7:5], 1'b0, vga_in.rgb[3:1]};
 
     assign delay_in = {
         vga_in.hcount, vga_in.vcount, vga_in.hsync, vga_in.vsync, vga_in.hblnk, vga_in.vblnk, 
         (sig_game_over ? dimmed_bg : vga_in.rgb), 
         in_panel, in_border, in_title, in_d_score, in_p0_score, in_p1_score, in_instr1, in_instr2,
         char_x_bit, in_p0_res, in_p1_res, p0_win, p0_draw, p1_win, p1_draw
     };
 
     logic [10:0] d_hcount, d_vcount;
     logic d_hsync, d_vsync, d_hblnk, d_vblnk;
     logic [11:0] d_rgb;
     logic d_in_panel, d_in_border, d_in_title, d_in_d_score, d_in_p0_score, d_in_p1_score, d_in_instr1, d_in_instr2;
     logic [2:0] d_char_x_bit;
     logic d_in_p0_res, d_in_p1_res, d_p0_win, d_p0_draw, d_p1_win, d_p1_draw;
 
     assign {
         d_hcount, d_vcount, d_hsync, d_vsync, d_hblnk, d_vblnk, 
         d_rgb, 
         d_in_panel, d_in_border, d_in_title, d_in_d_score, d_in_p0_score, d_in_p1_score, d_in_instr1, d_in_instr2,
         d_char_x_bit, d_in_p0_res, d_in_p1_res, d_p0_win, d_p0_draw, d_p1_win, d_p1_draw
     } = delay_out;
 
     delay #(.WIDTH(DEL_W), .CLK_DEL(1)) u_delay (
         .clk(clk), .rst_n(rst_n), .din(delay_in), .dout(delay_out)
     );
 
     // --- Final Painting ---
     always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             vga_out.hcount <= '0; vga_out.vcount <= '0; vga_out.hsync <= '0;
             vga_out.vsync <= '0; vga_out.hblnk <= '0; vga_out.vblnk <= '0; vga_out.rgb <= '0;
         end else begin
             vga_out.hcount <= d_hcount; vga_out.vcount <= d_vcount;
             vga_out.hsync <= d_hsync; vga_out.vsync <= d_vsync;
             vga_out.hblnk <= d_hblnk; vga_out.vblnk <= d_vblnk;
 
             if (sig_game_over) begin
                 if (d_in_border) vga_out.rgb <= 12'hF_A_0; // Frame - gold
                 else if (d_in_panel) begin
                     if (d_in_title && rom_pixels[7 - d_char_x_bit]) vga_out.rgb <= 12'hF_F_0; // GAME OVER - yellow
                     else if ((d_in_d_score || d_in_p0_score || d_in_p1_score) && rom_pixels[7 - d_char_x_bit]) vga_out.rgb <= 12'hF_F_F; // Points - white
                     else if (d_in_p0_res && rom_pixels[7 - d_char_x_bit]) vga_out.rgb <= d_p0_draw ? 12'h8_8_8 : (d_p0_win ? 12'h0_F_0 : 12'hF_0_0);
                     else if (d_in_p1_res && rom_pixels[7 - d_char_x_bit]) vga_out.rgb <= d_p1_draw ? 12'h8_8_8 : (d_p1_win ? 12'h0_F_0 : 12'hF_0_0);
                     else if ((d_in_instr1 || d_in_instr2) && rom_pixels[7 - d_char_x_bit]) vga_out.rgb <= 12'h0_F_F; // Instructions - cyan
                     else vga_out.rgb <= 12'h1_1_2; // Panel background
                 end else begin
                     vga_out.rgb <= d_rgb; // Darker background
                 end
             end else begin
                 vga_out.rgb <= d_rgb; // Normal Game
             end
         end
     end
 endmodule