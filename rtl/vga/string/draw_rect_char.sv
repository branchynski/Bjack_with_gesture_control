/**
 * Module name: draw_rect_char
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-31
 * Description:   Draws a character rectangle from a font bitmap into the VGA stream.
 */

import vga_pkg::*;

module draw_rect_char #(
    parameter X_POS = 64,
    parameter Y_POS = 64,
    parameter ROM_DELAY = 2
    )(
        input  logic clk,
        input  logic rst_n,

        input logic [7:0] char_line_pixel,
        output logic [7:0] char_xy,
        output logic [3:0] char_line,

        vga_if.in vga_in,

        vga_if.out vga_out
    );

    timeunit 1ns;
    timeprecision 1ps;


    /**
     * Local variables and signals
     */

    typedef struct packed {
    logic [10:0] hcount;
    logic        hsync;
    logic        hblnk;
    logic [10:0] vcount;
    logic        vsync;
    logic        vblnk;
    logic [11:0] rgb;
    logic        in_rect;   
    } vga_sync_t;

    vga_sync_t pipe_in, pipe_out;

    logic [11:0] rgb_nxt = vga_in.rgb;

    logic bit_on;

    logic [7:0] local_x;
    logic [6:0] local_y;



    /**
     * Internal logic
     */

    always_comb begin : prepare_pipeline
        pipe_in.hcount = vga_in.hcount;
        pipe_in.hsync  = vga_in.hsync;
        pipe_in.hblnk  = vga_in.hblnk;
        pipe_in.vcount = vga_in.vcount;
        pipe_in.vsync  = vga_in.vsync;
        pipe_in.vblnk  = vga_in.vblnk;
        pipe_in.rgb    = vga_in.rgb;
        
        pipe_in.in_rect = (vga_in.hcount >= X_POS) &&
                          (vga_in.hcount < X_POS + 256) && 
                          (vga_in.vcount >= Y_POS) && 
                          (vga_in.vcount < Y_POS + 128);

        local_x = 8'(vga_in.hcount - X_POS);
        local_y = 7'(vga_in.vcount - Y_POS);
    end

    delay #(
        .WIDTH($bits(vga_sync_t)), 
        .CLK_DEL(ROM_DELAY)
    ) u_vga_delay (
        .clk(clk),
        .rst_n(rst_n),
        .din(pipe_in),
        .dout(pipe_out)
    );

    always_ff @(posedge clk, negedge rst_n) begin 
        if (!rst_n) begin
            char_xy   <= '0;
            char_line <= '0;
        end else begin
            char_xy   <= {local_y[6:4], local_x[7:3]}; 
            char_line <= local_y[3:0];
        end
    end

    always_comb begin : apply_pixels_comb
        if (pipe_out.in_rect) begin
            bit_on = char_line_pixel[ ~pipe_out.hcount[2:0] ];
        end else begin
            bit_on = 1'b0;
        end
        
        rgb_nxt = bit_on ? 12'h000 : pipe_out.rgb;
    end

    always_ff @(posedge clk, negedge rst_n) begin : output_ff_blk
        if (!rst_n) begin
            vga_out.vcount <= '0;
            vga_out.vsync  <= '0;
            vga_out.vblnk  <= '0;
            vga_out.hcount <= '0;
            vga_out.hsync  <= '0;
            vga_out.hblnk  <= '0;
            vga_out.rgb    <= '0;
        end else begin
            vga_out.hcount <= pipe_out.hcount;
            vga_out.hsync  <= pipe_out.hsync;
            vga_out.hblnk  <= pipe_out.hblnk;
            vga_out.vcount <= pipe_out.vcount;
            vga_out.vsync  <= pipe_out.vsync;
            vga_out.vblnk  <= pipe_out.vblnk;
            vga_out.rgb    <= rgb_nxt;
        end
    end

endmodule
