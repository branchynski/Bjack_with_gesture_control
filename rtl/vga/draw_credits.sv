/********************************************************************************
 * Module Name:    draw_credits
 * Author:         Eryk Rutka / Bartlomiej Raczynski
 * Date:           2026-06-14
 * Version:        1.2 (Syntax Fix)
 * Description:    Credits overlay. Dims the menu background and displays authors.
 * Exit is handled via SWIPE gesture.
 ********************************************************************************/

 import vga_pkg::*;

 module draw_credits (
     input  logic clk,
     input  logic rst_n,
     input  logic sig_show_credits,
     vga_if.in  vga_in,
     vga_if.out vga_out
 );
 
     timeunit 1ns;
     timeprecision 1ps;
 
     // --- Main panel dimensions ---
     localparam PANEL_X = 250;
     localparam PANEL_W = 524;
     localparam PANEL_Y = 150;
     localparam PANEL_H = 468;
 
     logic in_panel, in_border;
     logic in_title, in_proj, in_eryk, in_bartek, in_agh, in_exit;
     
     logic [7:0] target_char;
     logic [10:0] rom_addr;
     logic [2:0] char_x_bit;
     logic [3:0] char_y_line; 
 
     always_comb begin
         in_panel = (vga_in.hcount >= PANEL_X && vga_in.hcount < PANEL_X + PANEL_W &&
                     vga_in.vcount >= PANEL_Y && vga_in.vcount < PANEL_Y + PANEL_H);
         in_border = in_panel && (vga_in.hcount < PANEL_X + 4 || vga_in.hcount >= PANEL_X + PANEL_W - 4 ||
                                  vga_in.vcount < PANEL_Y + 4 || vga_in.vcount >= PANEL_Y + PANEL_H - 4);
 
         in_title=0; in_proj=0; in_eryk=0; in_bartek=0; in_agh=0; in_exit=0;
         target_char = 8'h20; char_x_bit = '0; char_y_line = '0; rom_addr = '0;
 
         if (sig_show_credits && in_panel && !in_border) begin
             // "CREDITS"
             if (vga_in.vcount >= 180 && vga_in.vcount < 212 && vga_in.hcount >= 456 && vga_in.hcount < 568) begin
                 in_title = 1'b1;
                 char_x_bit = (vga_in.hcount - 456) >> 1; char_y_line = (vga_in.vcount - 180) >> 1;
                 case ((vga_in.hcount - 456) >> 4)
                     0: target_char=8'h43; 1: target_char=8'h52; 2: target_char=8'h45; 3: target_char=8'h44; 
                     4: target_char=8'h49; 5: target_char=8'h54; 6: target_char=8'h53; 
                     default: target_char=8'h20;
                 endcase
             end
             // "PROJECT BY:"
             else if (vga_in.vcount >= 260 && vga_in.vcount < 292 && vga_in.hcount >= 340 && vga_in.hcount < 516) begin
                 in_proj = 1'b1;
                 char_x_bit = (vga_in.hcount - 340) >> 1; char_y_line = (vga_in.vcount - 260) >> 1;
                 case ((vga_in.hcount - 340) >> 4)
                     0: target_char=8'h50; 1: target_char=8'h52; 2: target_char=8'h4F; 3: target_char=8'h4A; 
                     4: target_char=8'h45; 5: target_char=8'h43; 6: target_char=8'h54; 7: target_char=8'h20; 
                     8: target_char=8'h42; 9: target_char=8'h59; 10: target_char=8'h3A; 
                     default: target_char=8'h20;
                 endcase
             end
             // "ERYK RUTKA"
             else if (vga_in.vcount >= 300 && vga_in.vcount < 332 && vga_in.hcount >= 360 && vga_in.hcount < 520) begin
                 in_eryk = 1'b1;
                 char_x_bit = (vga_in.hcount - 360) >> 1; char_y_line = (vga_in.vcount - 300) >> 1;
                 case ((vga_in.hcount - 360) >> 4)
                     0: target_char=8'h45; 1: target_char=8'h52; 2: target_char=8'h59; 3: target_char=8'h4B; 
                     4: target_char=8'h20; 5: target_char=8'h52; 6: target_char=8'h55; 7: target_char=8'h54; 
                     8: target_char=8'h4B; 9: target_char=8'h41; 
                     default: target_char=8'h20;
                 endcase
             end
             // "BARTLOMIEJ RACZYNSKI"
             else if (vga_in.vcount >= 340 && vga_in.vcount < 372 && vga_in.hcount >= 360 && vga_in.hcount < 680) begin
                 in_bartek = 1'b1;
                 char_x_bit = (vga_in.hcount - 360) >> 1; char_y_line = (vga_in.vcount - 340) >> 1;
                 case ((vga_in.hcount - 360) >> 4)
                     0: target_char=8'h42; 1: target_char=8'h41; 2: target_char=8'h52; 3: target_char=8'h54; 
                     4: target_char=8'h4C; 5: target_char=8'h4F; 6: target_char=8'h4D; 7: target_char=8'h49; 
                     8: target_char=8'h45; 9: target_char=8'h4A; 10: target_char=8'h20; 11: target_char=8'h52; 
                     12: target_char=8'h41; 13: target_char=8'h43; 14: target_char=8'h5A; 15: target_char=8'h59; 
                     16: target_char=8'h4E; 17: target_char=8'h53; 18: target_char=8'h4B; 19: target_char=8'h49; 
                     default: target_char=8'h20;
                 endcase
             end
             // "AGH UST 2026"
             else if (vga_in.vcount >= 420 && vga_in.vcount < 452 && vga_in.hcount >= 340 && vga_in.hcount < 532) begin
                 in_agh = 1'b1;
                 char_x_bit = (vga_in.hcount - 340) >> 1; char_y_line = (vga_in.vcount - 420) >> 1;
                 case ((vga_in.hcount - 340) >> 4)
                     0: target_char=8'h41; 1: target_char=8'h47; 2: target_char=8'h48; 3: target_char=8'h20; 
                     4: target_char=8'h55; 5: target_char=8'h53; 6: target_char=8'h54; 7: target_char=8'h20; 
                     8: target_char=8'h32; 9: target_char=8'h30; 10: target_char=8'h32; 11: target_char=8'h36; 
                     default: target_char=8'h20;
                 endcase
             end
             // "-> SWIPE TO EXIT"
             else if (vga_in.vcount >= 520 && vga_in.vcount < 552 && vga_in.hcount >= 390 && vga_in.hcount < 630) begin
                 in_exit = 1'b1;
                 char_x_bit = (vga_in.hcount - 390) >> 1; char_y_line = (vga_in.vcount - 520) >> 1;
                 case ((vga_in.hcount - 390) >> 4)
                     0: target_char=8'h1A; // Right arrow (SWIPE)
                     1: target_char=8'h20; 2: target_char=8'h53; 3: target_char=8'h57; 
                     4: target_char=8'h49; 5: target_char=8'h50; 6: target_char=8'h45; 
                     7: target_char=8'h20; 8: target_char=8'h54; 9: target_char=8'h4F; 
                     10: target_char=8'h20; 11: target_char=8'h45; 12: target_char=8'h58; 
                     13: target_char=8'h49; 14: target_char=8'h54; 
                     default: target_char=8'h20;
                 endcase
             end
             rom_addr = {target_char[6:0], char_y_line};
         end
     end
 
     logic [7:0] rom_pixels;
     font_rom u_font_rom (.clk(clk), .addr(rom_addr), .char_line_pixels(rom_pixels));
 
     localparam DEL_W = 11 + 11 + 1 + 1 + 1 + 1 + 12 + 6 + 3;
     logic [DEL_W-1:0] delay_in, delay_out;
     
     // --- Background dimming logic ---
     logic [11:0] dimmed_bg;
     assign dimmed_bg = {1'b0, vga_in.rgb[11:9], 1'b0, vga_in.rgb[7:5], 1'b0, vga_in.rgb[3:1]};
 
     assign delay_in = {
         vga_in.hcount, vga_in.vcount, vga_in.hsync, vga_in.vsync, vga_in.hblnk, vga_in.vblnk, 
         (sig_show_credits ? dimmed_bg : vga_in.rgb), 
         in_panel, in_border, in_title, in_proj, in_eryk, in_bartek, in_agh, in_exit, char_x_bit
     };
 
     logic [10:0] d_hcount, d_vcount; 
     logic d_hsync, d_vsync, d_hblnk, d_vblnk; 
     logic [11:0] d_rgb;
     logic d_in_panel, d_in_border, d_in_title, d_in_proj, d_in_eryk, d_in_bartek, d_in_agh, d_in_exit; 
     logic [2:0] d_char_x_bit;
 
     assign {d_hcount, d_vcount, d_hsync, d_vsync, d_hblnk, d_vblnk, d_rgb, d_in_panel, d_in_border, d_in_title, d_in_proj, d_in_eryk, d_in_bartek, d_in_agh, d_in_exit, d_char_x_bit} = delay_out;
 
     delay #(.WIDTH(DEL_W), .CLK_DEL(1)) u_delay (.clk(clk), .rst_n(rst_n), .din(delay_in), .dout(delay_out));
 
     // --- Final paintbrush ---
     always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             vga_out.hcount <= '0; vga_out.vcount <= '0; vga_out.hsync <= '0; vga_out.vsync <= '0; vga_out.hblnk <= '0; vga_out.vblnk <= '0; vga_out.rgb <= '0;
         end else begin
             vga_out.hcount <= d_hcount; vga_out.vcount <= d_vcount; vga_out.hsync <= d_hsync; vga_out.vsync <= d_vsync; vga_out.hblnk <= d_hblnk; vga_out.vblnk <= d_vblnk;
             
             if (sig_show_credits) begin
                 if (d_in_border) vga_out.rgb <= 12'h0_A_F; // Cyan border
                 else if (d_in_panel) begin
                     if (d_in_title && rom_pixels[7 - d_char_x_bit]) vga_out.rgb <= 12'hF_F_0;
                     else if (d_in_exit && rom_pixels[7 - d_char_x_bit]) vga_out.rgb <= 12'h0_F_F;
                     else if ((d_in_proj || d_in_eryk || d_in_bartek || d_in_agh) && rom_pixels[7 - d_char_x_bit]) vga_out.rgb <= 12'hF_F_F;
                     else vga_out.rgb <= 12'h1_1_2; // Dark background
                 end else vga_out.rgb <= d_rgb; 
             end else vga_out.rgb <= d_rgb; 
         end
     end
 endmodule