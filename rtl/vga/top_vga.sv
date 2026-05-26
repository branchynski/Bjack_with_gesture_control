/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
 *
 * Modified by: Eryk Rutka
 * date: 2026-05-18
 * 2025  AGH University of Science and Technology
 * MTM UEC2
 * Piotr Kaczmarczyk
 *
 * Description:
 * The project top module.
 */

 module top_vga (
    input  logic clk,
    input  logic rst_n,

    inout ps2_clk,
    inout ps2_data,
    input clk_100MHz,

    output logic vs,
    output logic hs,
    output logic [3:0] r,
    output logic [3:0] g,
    output logic [3:0] b
);

timeunit 1ns;
timeprecision 1ps;

/**
 * Local variables and signals
 */
// VGA signals from timing
vga_if vga_tim();

// VGA signals from background
vga_if vga_bg();

/**
 * Submodules instances
 */

vga_timing u_vga_timing (
    .clk,
    .rst_n,

    .vga_out  (vga_tim)
);

draw_bg u_draw_bg (
    .clk,
    .rst_n,

    .vga_in  (vga_tim),

    .vga_out  (vga_bg)
);

endmodule
