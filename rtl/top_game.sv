/**
 * Module name:   top_game
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-07
 * Description:  Top-level module for sensor input, game interface, and game logic
 */

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

    logic [15:0] gyro_x; 
    logic [15:0] gyro_y; 
    logic [15:0] gyro_z;
    logic [15:0] acc_x; 
    logic [15:0] acc_y; 
    logic [15:0] acc_z;
    logic data_ready;

    /**
     * Signals assignments
     */

    /**
     * Submodules instances
     */
    top_sensor u_top_sensor (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(cs_n),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .gyro_x(gyro_x),
        .gyro_y(gyro_y),
        .gyro_z(gyro_z),
        .acc_x(acc_x),
        .acc_y(acc_y),
        .acc_z(acc_z),
        .data_ready(data_ready)
    );

endmodule
