/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Piotr Kaczmarczyk
 *
 * Description:
 * Vga timing controller.
 */

 module vga_timing 
    (
        input  logic clk,
        input  logic rst_n,
        vga_if.out vga_out
    );

    timeunit 1ns;
    timeprecision 1ps;

    import vga_pkg::*;


    /**
     * Local variables and signals
     */

    logic [10:0] vcount_nxt, hcount_nxt;
    logic vsync_nxt, vblnk_nxt, hsync_nxt, hblnk_nxt;


    /**
     * Internal logic
     */

    always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vga_out.vcount <= 11'b0;
        vga_out.vsync <= 1'b0;
        vga_out.vblnk <= 1'b0;
        vga_out.hcount <= 11'b0;
        vga_out.hsync <= 1'b0;
        vga_out.hblnk <= 1'b0;
    end else begin
        vga_out.hcount <= hcount_nxt;
        vga_out.vcount <= vcount_nxt;
        vga_out.hsync <= hsync_nxt;
        vga_out.vsync <= vsync_nxt;
        vga_out.hblnk <= hblnk_nxt;
        vga_out.vblnk <= vblnk_nxt;
    end
    end

    always_comb begin
        hcount_nxt = vga_out.hcount;
        vcount_nxt = vga_out.vcount;

        if (vga_out.hcount == HOR_TOTAL_TIME - 1) begin
            hcount_nxt = 11'b0;

            if (vga_out.vcount == VER_TOTAL_TIME - 1) begin
                vcount_nxt = 11'b0;
            end
            else begin
                vcount_nxt = vga_out.vcount + 1;
            end

        end
        else begin
            hcount_nxt = vga_out.hcount + 1;
        end

        // Generowanie HSYNC
        hsync_nxt = ((vga_out.hcount+1) >= HOR_SYNC_START) && ((vga_out.hcount+1) < (HOR_SYNC_START + HOR_SYNC_TIME));
        
        // Generowanie VSYNC
        vsync_nxt = (((((vga_out.vcount+1) >= VER_SYNC_START) && (vga_out.hcount == (HOR_TOTAL_TIME - 1))) 
        && ((vga_out.vcount +1) < (VER_SYNC_START + VER_SYNC_TIME))) 
        || (vga_out.hcount != (HOR_TOTAL_TIME - 1) && (vga_out.vcount >= (VER_SYNC_START)) && (vga_out.vcount < ((VER_SYNC_START + VER_SYNC_TIME)))));

        // Generowanie HBLNK
        hblnk_nxt = ((vga_out.hcount+1) >= HOR_BLANK_START) && ((vga_out.hcount+1) < (HOR_BLANK_START + HOR_BLANK_TIME));
        
        // Generowanie VBLNK
        vblnk_nxt = (((((vga_out.vcount+1) >= VER_BLANK_START) && (vga_out.hcount == (HOR_TOTAL_TIME - 1))) 
        && ((vga_out.vcount +1) < (VER_BLANK_START + VER_BLANK_TIME))) 
        || (vga_out.hcount != (HOR_TOTAL_TIME - 1) && (vga_out.vcount >= (VER_BLANK_START)) && (vga_out.vcount < ((VER_BLANK_START + VER_BLANK_TIME)))));
    end

    assign vga_out.rgb = 12'h000;


endmodule
