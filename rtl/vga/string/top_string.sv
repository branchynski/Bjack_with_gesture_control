/**
 * Module name: top_string
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-31
 * Description:   Text overlay module that draws a string using character ROM and font ROM.
 */

module top_string #(
    parameter X_POS = 64,
    parameter Y_POS = 64,
    parameter ROM_DELAY = 2,
    parameter string TEXT = "Test"
    )(
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

    logic [10:0] string_addr;
    logic [7:0] char_line_pixel;
    logic [7:0] char_xy;


    /**
     * Signals assignments
     */


    /**
     * Submodules instances
     */

    draw_rect_char (
        .X_POS(X_POS),
        .Y_POS(Y_POS),
        .ROM_DELAY(ROM_DELAY)
    ) u_draw_rect_char (
        .clk,
        .rst_n,
        .char_line_pixel(char_line_pixel),
        .char_xy (char_xy),
        .char_line (string_addr[3:0]),
        .vga_in (vga_in),
        .vga_out (vga_out)
    );

    font_rom u_font_rom (
        .clk,
        .addr(string_addr),
        .char_line_pixels(char_line_pixel)
    );

    char_rom #(
        .TEXT(TEXT)
        ) u_char_rom (
        .char_xy (char_xy),
        .char_code (string_addr[10:4])
    );

endmodule
