Jasne, robimy wersję w pigułce. Krótko, zwięźle i na temat:

```systemverilog
/********************************************************************************
 * Module Name:    draw_bg
 * Author:         Eryk Rutka
 * Date:           2026-05-31
 * Version:        1.0
 * Description:    
 * Generates the solid dark green background (casino table) for the VGA display.
 * Functionality:
 * - Passes through VGA synchronization and coordinate signals.
 * - Outputs black (12'h0_0_0) during blanking and dark green (12'h0_8_0) 
 * during the active display region.
 ********************************************************************************/
import vga_pkg::*;

(* use_dsp = "no" *)
module draw_bg (
    input  logic clk,
    input  logic rst_n,

    vga_if.in vga_in,
    vga_if.out vga_out
);

    timeunit 1ns;
    timeprecision 1ps;

    logic [11:0] rgb_nxt;
    
    (* keep = "true" *) logic [11:0] dummy_rgb;
    assign dummy_rgb = vga_in.rgb;

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

    always_comb begin : bg_comb_blk
        if (vga_in.vblnk || vga_in.hblnk) begin             
            rgb_nxt = 12'h0_0_0;                    
        end else begin                              
            rgb_nxt = 12'h0_8_0;               
        end
    end

endmodule