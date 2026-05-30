/**
 * Module name:   top_gesture
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-30
 * Description:  module for the hardware AI gesture 
 * recognition system. This wrapper integrates four main sub-systems:
 * 1. SPI master interface for raw IMU data acquisition.
 * 2. 96-bit circular buffer (FIFO) for clock domain and rate matching.
 * 3. Vivado HLS 1D-CNN hardware accelerator.
 * 4. FSM controller managing inference cycles and AXI4-Stream handshakes.
 */

import ai_type_pkg::*;

module top_gesture (
    input logic clk,
    input logic rst_n,

    output logic cs_n,
    output logic sclk,
    output logic mosi,
    input  logic miso,

    output gesture_out gesture
    );

    timeunit 1ns;
    timeprecision 1ps;
    /**
     * Local variables and signals
     */

    logic data_ready;

    logic [95:0] data_in; 
    /* [15:0] acc_x 
       [31:16] acc_y 
       [47:32] acc_z
       [63:48] gyro_x 
       [79:64] gyro_y 
       [95:80] gyro_z
    */

    logic full_buffer;
    logic buffer_empty;

    logic [95 : 0] input_layer_TDATA;
    logic input_layer_TREADY;
    logic input_layer_TVALID;
    logic [47 : 0] layer15_out_TDATA;
    logic layer15_out_TREADY;
    logic layer15_out_TVALID;
    logic ap_done;
    logic ap_idle;
    logic ap_ready;
    logic ap_start;

    /**
     * Signals assignments
     */

    assign input_layer_TVALID = ~buffer_empty; 

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
        .gyro_x(data_in[63:48]),
        .gyro_y(data_in[79:64]),
        .gyro_z(data_in[95:80]),
        .acc_x(data_in[15:0]),
        .acc_y(data_in[31:16]),
        .acc_z(data_in[47:32]),
        .data_ready(data_ready)
    );

    ring_buffer #(
        .DATA_WIDTH (96),
        .DEPTH (128), 
        .ADDR_WIDTH (7)    
    ) u_ring_buffer (
        .clk(clk),
        .rst_n(rst_n),

        .data_in(data_in),
        .wr_en(data_ready),
        .full(full_buffer),
        .rd_en(input_layer_TREADY & ~buffer_empty),
        .data_out(input_layer_TDATA),
        .empty(buffer_empty) 
    );    

    ml_sensor u_ml_sensor (
        .input_layer_TDATA(input_layer_TDATA),
        .input_layer_TREADY(input_layer_TREADY),
        .input_layer_TVALID(input_layer_TVALID),
        .layer15_out_TDATA(layer15_out_TDATA),
        .layer15_out_TREADY(layer15_out_TREADY),
        .layer15_out_TVALID(layer15_out_TVALID),
        .ap_clk(clk),
        .ap_rst_n(rst_n),
        .ap_done(ap_done),
        .ap_idle(ap_idle),
        .ap_ready(ap_ready),
        .ap_start(ap_start)
    );

    model_controller_fsm u_model_controller_fsm (
        .clk (clk),
        .rst_n (rst_n),

        .ap_done (ap_done),
        .ap_idle (ap_idle),
        .ap_ready (ap_ready),
        .ap_start (ap_start),
        .layer15_out_TDATA (layer15_out_TDATA),
        .layer15_out_TREADY (layer15_out_TREADY),
        .layer15_out_TVALID (layer15_out_TVALID),
        .gesture (gesture)
    );


endmodule