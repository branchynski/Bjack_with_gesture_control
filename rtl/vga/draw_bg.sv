/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Piotr Kaczmarczyk
 * Modified by: Eryk Rutka
 * Date: 2026-05-18
 * Description: 
 * Draw background.
 */

 import vga_pkg::*;

 function logic[11:0] draw_ellipse 
 (input logic [10:0] hcount, input logic [10:0] vcount, 
 input logic [10:0] hor_size, input logic [10:0] ver_size,
 input logic [10:0] hor_middle, input logic [10:0] ver_middle, 
 input logic[11:0] lColor);
     
     logic signed [11:0] dx, dy;
     logic [10:0] abs_dy;
     
     logic [15:0] a, b, x, y; 
     logic [31:0] term1, term2, limit;
 
     dx = $signed({1'b0, hcount}) - $signed({1'b0, hor_middle});
     dy = $signed({1'b0, vcount}) - $signed({1'b0, ver_middle});
     
     abs_dy = (dy < 0) ? -dy[10:0] : dy[10:0];
     if (dx >= 0 && dx <= $signed({1'b0, hor_size}) && abs_dy <= ver_size) begin
         x = dx[7:0] * dx[7:0]; 
         y = abs_dy[7:0] * abs_dy[7:0];
         
         a = hor_size[7:0] * hor_size[7:0];
         b = ver_size[7:0] * ver_size[7:0];
         
         term1 = x * b;
         term2 = y * a;
         limit = a * b;
 
         // elipse equation: x^2*b^2 + y^2*a^2 <= a^2*b^2
         if (term1 + term2 <= limit) begin
             return lColor;    // Czerwona elipsa
         end else begin
             return 12'h8_8_8;    // Szare tło (wewnątrz limitu prostokąta, poza elipsą)
         end
         
     end else begin
         return 12'h8_8_8;        // Szare tło (piksele daleko od elipsy)
     end
     
 endfunction
 
 function logic[11:0] draw_line 
 (input logic [10:0] hcount, input logic [10:0] vcount, 
 input logic [10:0] hor_size, input logic [10:0] ver_size,
 input logic [10:0] hor_middle, input logic [10:0] ver_middle, 
 input logic[11:0] lColor);
     if ((hcount >= hor_middle - hor_size && hcount < hor_middle + hor_size) &&
     (vcount >= ver_middle - ver_size && vcount < ver_middle + ver_size)) begin
         return lColor;    // Red line.
     end else begin
         return 12'h8_8_8;    // Gray background.
     end
     
 endfunction
 
 function logic[11:0] show_B (input logic [10:0] hcount, input logic [10:0] vcount, input logic[11:0] lColor);
     localparam HOR_MIDDLE = HOR_PIXELS / 2;
     localparam VER_MIDDLE = VER_PIXELS / 2;
 
     if (draw_line(hcount, vcount, 20, 50, HOR_MIDDLE, VER_MIDDLE, lColor) == lColor ||
         draw_ellipse(hcount, vcount, 45, 31, HOR_MIDDLE, VER_MIDDLE + 20, lColor) == lColor ||
         draw_ellipse(hcount, vcount, 45, 31, HOR_MIDDLE, VER_MIDDLE - 20, lColor) == lColor) begin
         return 12'hf_0_0;
     end else begin
         return 12'h8_8_8;
     end
 
 endfunction
 
 function logic[11:0] show_R (input logic [10:0] hcount, input logic [10:0] vcount,
     input logic[10:0] hpos, input logic[10:0] vpos,
     input logic[11:0] lColor);
 
     if (draw_line(hcount, vcount, 10, 50, hpos, vpos, lColor) == lColor  ||
         draw_ellipse(hcount, vcount, 45, 31, hpos, vpos - 20, lColor) == lColor ||
         draw_line(hcount, vcount, 5, 5, hpos + 5, vpos + 5, lColor) == lColor || 
         draw_line(hcount, vcount, 5, 5, hpos + 10, vpos + 15, lColor) == lColor || 
         draw_line(hcount, vcount, 5, 5, hpos + 15, vpos + 20, lColor) == lColor || 
         draw_line(hcount, vcount, 5, 5, hpos + 20, vpos + 25, lColor) == lColor || 
         draw_line(hcount, vcount, 5, 5, hpos + 25, vpos + 30, lColor) == lColor || 
         draw_line(hcount, vcount, 5, 5, hpos + 30, vpos + 35, lColor) == lColor ||
         draw_line(hcount, vcount, 5, 5, hpos + 35, vpos + 40, lColor) == lColor ||
         draw_line(hcount, vcount, 5, 5, hpos + 40, vpos + 45, lColor) == lColor ) begin
         return 12'hf_0_0;
     end else begin
         return 12'h8_8_8;
     end
 
 endfunction
 
 function logic[11:0] show_E (input logic [10:0] hcount, input logic [10:0] vcount, input logic[11:0] lColor);
     localparam HOR_MIDDLE = HOR_PIXELS / 2;
     localparam VER_MIDDLE = VER_PIXELS / 2;
 
     if (draw_line(hcount, vcount, 10, 50, HOR_MIDDLE, VER_MIDDLE + 110, lColor) == lColor ||
         draw_line(hcount, vcount, 20, 10, HOR_MIDDLE + 20, VER_MIDDLE + 70, lColor) == lColor ||
         draw_line(hcount, vcount, 20, 10, HOR_MIDDLE + 20, VER_MIDDLE + 110, lColor) == lColor ||
         draw_line(hcount, vcount, 20, 10, HOR_MIDDLE + 20, VER_MIDDLE + 150, lColor) == lColor ) begin
         return 12'hf_0_0;
     end else begin
         return 12'h8_8_8;
     end
 
 endfunction
 
 function logic[11:0] show_initials (input logic [10:0] hcount, input logic [10:0] vcount, input logic[11:0] lColor);
     localparam HOR_MIDDLE = HOR_PIXELS / 2;
     localparam VER_MIDDLE = VER_PIXELS / 2;
 
     if (show_B(hcount, vcount, lColor) == lColor || show_R(hcount, vcount, HOR_MIDDLE + 90, VER_MIDDLE, lColor) == lColor || 
     show_E(hcount, vcount, lColor) == lColor || show_R(hcount, vcount, HOR_MIDDLE + 90, VER_MIDDLE + 110, lColor) == lColor) begin
         return lColor;
     end else begin
         return 12'h8_8_8;
     end
 
 endfunction
 
 function logic[11:0] where_letter (input logic [10:0] hcount, input logic [10:0] vcount, 
     input logic[10:0] xAxis, input logic[10:0] yAxis, 
     input logic[11:0] lColor);
 
     if (show_R(hcount, vcount, xAxis + 90, yAxis, lColor) == lColor) begin
         return lColor;
     end else begin
         return 12'h8_8_8;
     end
 endfunction 
 
 (* use_dsp = "no" *)
 module draw_bg (
         input  logic clk,
         input  logic rst_n,
 
         vga_if.in vga_in,
         vga_if.out vga_out
     );
 
     timeunit 1ns;
     timeprecision 1ps;
 
 
     /**
      * Local variables and signals
      */
 
     logic [11:0] rgb_nxt;
     
     (* keep = "true" *) logic [11:0] dummy_rgb;
     assign dummy_rgb = vga_in.rgb;
 
     /**
      * Internal logic
      */
 
     always_ff @(posedge clk) begin : bg_ff_blk
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
 
     always_comb begin : bg_comb_blk
         if (vga_in.vblnk || vga_in.hblnk) begin             // Blanking region:
             rgb_nxt = 12'h0_0_0;                    // - make it it black.
         end else begin                              // Active region:
             if (vga_in.vcount == 0)                     // - top edge:
                 rgb_nxt = 12'hf_f_0;                // - - make a yellow line.
             else if (vga_in.vcount == VER_PIXELS - 1)   // - bottom edge:
                 rgb_nxt = 12'hf_0_0;                // - - make a red line.
             else if (vga_in.hcount == 0)                // - left edge:
                 rgb_nxt = 12'h0_f_0;                // - - make a green line.
             else if (vga_in.hcount == HOR_PIXELS - 1)   // - right edge:
                 rgb_nxt = 12'h0_0_f;                // - - make a blue line.
 
             // Add your code here. Doac inicjaly gdzies na ekranie
                 //rgb_nxt = show_initials(vga_in.hcount, vga_in.vcount);
                 //rgb_nxt = where_letter(vga_in.hcount, vga_in.vcount, 300, 150, 12'hf_0_0) || where_letter(vga_in.hcount, vga_in.vcount, 150, 200, 12'hf_0_0);
 
             else                                    // The rest of active display pixels:
                 //rgb_nxt = 12'h8_8_8;                // - fill with gray.
                 /*if(where_letter(vga_in.hcount, vga_in.vcount, 300, 150, 12'hf_0_0) == 12'hf_0_0 
                 || where_letter(vga_in.hcount, vga_in.vcount, 150, 200, 12'hf_0_0) == 12'hf_0_0) begin
                     rgb_nxt = 12'hf_0_0;
                 end else begin 
                     rgb_nxt = 12'h8_8_8;
                 end
                 */ 
                 rgb_nxt = show_initials(vga_in.hcount, vga_in.vcount, 12'hf_0_0);
                 
         end
     end
 
 endmodule