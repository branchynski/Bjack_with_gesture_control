/**
 * Module name:   top_game
 * Author:        Bartłomiej Raczyński
 * Version:       1.1
 * Last modified: 2026-05-30
 * Description:  Top-level module for sensor input, game interface, and game logic
 */


import ai_type_pkg::*;

module top_game (
        input  logic clk,
        input  logic rst_n,
        output logic cs_n,
        output logic sclk,
        output logic mosi,
        input  logic miso
    );

    timeunit 1ns;
    timeprecision 1ps;

    /**
     * Local variables and signals
     */

    gesture_out gesture;

    /**
     * Signals assignments
     */

    /**
     * Submodules instances
     */
    top_gesture u_top_gesture (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(cs_n),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .gesture(gesture)
    );

endmodule
