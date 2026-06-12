/**
 * Module name:   top_game
 * Author:        Bartłomiej Raczyński
 * Version:       1.2
 * Last modified: 2026-06-07
 * Description:  Top-level module for sensor input, game interface, and game logic
 */


import ai_type_pkg::*;

module top_game (
        input  logic clk,
        input  logic rst_n,
        output logic cs_n,
        output logic sclk,
        output logic mosi,
        input  logic miso,

        input logic rx,
        output logic tx,

        input logic sw_master,

        output logic vs,
        output logic hs,
        output logic [3:0] r,
        output logic [3:0] g,
        output logic [3:0] b,

        output logic [2:0] leds,
        input logic [2:0] sw
    );

    timeunit 1ns;
    timeprecision 1ps;

    /**
     * Local variables and signals
     */

    gesture_out gesture, gesture_test, gesture_ai;

    /**
     * Signals assignments
     */

    assign gesture = (sw[2] == 1'b1) ? gesture_test : gesture_ai;

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
        .gesture(gesture_ai)
    );

    top_vga u_top_vga(
        .clk(clk),
        .rst_n(rst_n),
        .current_gesture(gesture),
        .sw_master(sw_master),
        .uart_rx_pin(rx),   
        .uart_tx_pin(tx),   
 
        .vs(vs),
        .hs(hs),
        .r(r),
        .g(g),
        .b(b)
    );

    gesture_monitor u_gesture_monitor (
        .clk(clk),
        .rst_n(rst_n),
        .current_gesture(gesture),
        .leds(leds)
    );

    gesture_tdebug u_gesture_tdebug (
        .clk(clk),
        .rst_n(rst_n),
        .btn_on(sw[2]),
        .btn_knock(sw[1]),
        .btn_swipe(sw[0]),
        .gesture(gesture_test)
    );

endmodule
