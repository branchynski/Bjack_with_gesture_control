/*
 * Module name:   top_gesture
 * Author:        Bartłomiej Raczyński
 * Version:       1.2
 * Last modified: 2026-06-12
 * Description:   Integrating wrapper: SPI IMU, cyclic buffer,
 * HLS 1D-CNN accelerator, and FSM controller.
 *
 * Changes v1.2:
 * - Fixed the packing order of scaled_data_in.
 * HLS packs input[0] into the LSB, so gx (input[0]) must be
 * at bits [15:0], and az (input[5]) at [95:80].
 * The previous version sent {gx,gy,gz,ax,ay,az} which put
 * gx on the MSB — each channel received another channel's weights.
 * - CONFIDENCE_MARGIN lowered from 1000 to 300.
 * The value 1000 caused the FSM to never detect a gesture
 * when logit differences were in the hundreds.
 */

import ai_type_pkg::*;

module top_gesture (
    input  logic clk,
    input  logic rst_n,

    output logic cs_n,
    output logic sclk,
    output logic mosi,
    input  logic miso,

    output gesture_out gesture
);

    timeunit 1ns;
    timeprecision 1ps;

    logic        data_ready;
    logic [95:0] data_in;

    /*
     * scaled_data_in: 
     * Correct packing: input[5] at MSB, input[0] at LSB:
     * bits[95:80] = az = input[5]
     * bits[79:64] = ay = input[4]
     * bits[63:48] = ax = input[3]
     * bits[47:32] = gz = input[2]
     * bits[31:16] = gy = input[1]
     * bits[15:0]  = gx = input[0]
     */
    logic [95:0] scaled_data_in;

    assign scaled_data_in = {
        data_in[47:32],   
        data_in[31:16],   
        data_in[15:0],    
        data_in[95:80],   
        data_in[79:64],   
        data_in[63:48]    
    };

    logic [95:0] input_layer_TDATA;
    logic        input_layer_TREADY;
    logic        input_layer_TVALID;

    logic [47:0] layer15_out_TDATA;
    logic        layer15_out_TREADY;
    logic        layer15_out_TVALID;

    logic ap_done;
    logic ap_idle;
    logic ap_ready;
    logic ap_start;

    logic start_inference;

    top_sensor u_top_sensor (
        .clk       (clk),
        .rst_n     (rst_n),
        .cs_n      (cs_n),
        .sclk      (sclk),
        .mosi      (mosi),
        .miso      (miso),
        .gyro_x    (data_in[63:48]),
        .gyro_y    (data_in[79:64]),
        .gyro_z    (data_in[95:80]),
        .acc_x     (data_in[15:0]),
        .acc_y     (data_in[31:16]),
        .acc_z     (data_in[47:32]),
        .data_ready(data_ready)
    );

    sliding_window_buffer #(
        .DATA_WIDTH  (96),
        .WINDOW_SIZE (208),
        .STEP_SIZE   (20)
    ) u_sliding_window_buffer (
        .clk             (clk),
        .rst_n           (rst_n),
        .data_in         (scaled_data_in),
        .wr_en           (data_ready),
        .m_axis_tdata    (input_layer_TDATA),
        .m_axis_tvalid   (input_layer_TVALID),
        .m_axis_tready   (input_layer_TREADY),
        .start_inference (start_inference)
    );

    ML_sensor u_ml_sensor (
        .input_layer_TDATA  (input_layer_TDATA),
        .input_layer_TREADY (input_layer_TREADY),
        .input_layer_TVALID (input_layer_TVALID),
        .layer15_out_TDATA  (layer15_out_TDATA),
        .layer15_out_TREADY (layer15_out_TREADY),
        .layer15_out_TVALID (layer15_out_TVALID),
        .ap_clk             (clk),
        .ap_rst_n           (rst_n),
        .ap_done            (ap_done),
        .ap_idle            (ap_idle),
        .ap_ready           (ap_ready),
        .ap_start           (ap_start)
    );

    model_controller_fsm #(
        .VOTE_THRESHOLD    (5),
        .FLUSH_INFERENCES  (20),
        .CONFIDENCE_MARGIN (16'sd300)
    ) u_model_controller_fsm (
        .clk                (clk),
        .rst_n              (rst_n),
        .ap_done            (ap_done),
        .ap_idle            (ap_idle),
        .ap_ready           (ap_ready),
        .ap_start           (ap_start),
        .start_inference    (start_inference),
        .layer15_out_TDATA  (layer15_out_TDATA),
        .layer15_out_TREADY (layer15_out_TREADY),
        .layer15_out_TVALID (layer15_out_TVALID),
        .gesture            (gesture)
    );

endmodule