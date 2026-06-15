/**
 * Testbench name: top_gesture_tb
 * Author:        Bartłomiej Raczyński
 * Version:       2.0
 * Last modified: 2026-06-07
 * Description:  Testbench for the top_gesture module, simulating the entire gesture recognition system.
 */

import ai_type_pkg::*;

module top_gesture_tb;

    timeunit 1ns;
    timeprecision 1ps;

    logic clk;
    logic rst_n;
    logic cs_n;
    logic sclk;
    logic mosi;
    logic miso;
    gesture_out gesture;

    top_gesture uut (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(cs_n),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .gesture(gesture)
    );

    initial begin
        clk = 0;
        forever #7.69 clk = ~clk; 
    end

    int fd;
    int status;
    string dummy_header;
    
    real ts, gx, gy, gz, ax, ay, az; 
    
    logic signed [15:0] gx_int, gy_int, gz_int, ax_int, ay_int, az_int;

    int TARGET_SAMPLES = 1000;
    int sample_count = 0;

    initial begin
        rst_n = 0;
        miso = 0;
        #100;
        rst_n = 1;
        #100;
        $display("=================================================");
        $display("START SIMULATION: Reading data with auto-looping...");
        $display("=================================================");

        while (sample_count < TARGET_SAMPLES) begin
            fd = $fopen("../top_gesture/swiper.csv", "r");
            if (fd == 0) begin
                $error("ERROR: Cannot open file knock.csv! Check that the file exists in sim/build or sim/top_gesture.");
                $finish;
            end

            status = $fgets(dummy_header, fd);

            while (!$feof(fd) && sample_count < TARGET_SAMPLES) begin
                status = $fscanf(fd, "%f,%f,%f,%f,%f,%f,%f\n", ts, gx, gy, gz, ax, ay, az);
                
                if (status == 7) begin
                    gx_int = int'(gx);
                    gy_int = int'(gy);
                    gz_int = int'(gz);
                    ax_int = int'(ax);
                    ay_int = int'(ay);
                    az_int = int'(az);

                    //$display("DEBUG: TS=%f | GX=%0d, GY=%0d, GZ=%0d", ts, gx_int, gy_int, gz_int);

                    @(posedge clk); 
                    force uut.data_in = {gz_int, gy_int, gx_int, az_int, ay_int, ax_int};
                    force uut.data_ready = 1'b1;
                    @(posedge clk);
                    force uut.data_ready = 1'b0;

                    repeat(10000) @(posedge clk); 
                    
                    sample_count++;
                end
            end

            $fclose(fd);
            
            if (sample_count < TARGET_SAMPLES) begin
                $display("INFO: Reached end of CSV. Reopening to generate more samples. (Current samples: %0d/%0d)", sample_count, TARGET_SAMPLES);
            end
        end

        $display("Finished generating %0d samples. Waiting for pipelines and voting to finish...", TARGET_SAMPLES);
        
        repeat(50000) @(posedge clk); 

        $display("=================================================");
        $display("END OF SIMULATION.");
        $display("=================================================");
        $finish;
    end

    gesture_out prev_gesture = NOTHING;
    always @(posedge clk) begin
        if (gesture != prev_gesture) begin
            if (gesture != NOTHING) begin
                $display(">>> [T=%0t ns] DETECTED: %s (Cooldown timer started!) <<<", $time, gesture.name());
            end else begin
                $display("--- [T=%0t ns] SYSTEM IDLE: %s (Cooldown finished or reset) ---", $time, gesture.name());
            end
            prev_gesture = gesture;
        end
    end

    always_ff @(posedge clk) begin
        if (uut.layer15_out_TVALID && uut.layer15_out_TREADY) begin
            $display("SCORES: nothing=%0d swipe=%0d knock=%0d | votes N=%0d S=%0d K=%0d cnt=%0d",
                    uut.u_model_controller_fsm.score_nothing,
                    uut.u_model_controller_fsm.score_swipe,
                    uut.u_model_controller_fsm.score_knock,
                    uut.u_model_controller_fsm.votes_nothing_nxt,
                    uut.u_model_controller_fsm.votes_swipe_nxt,
                    uut.u_model_controller_fsm.votes_knock_nxt,
                    uut.u_model_controller_fsm.vote_cnt_nxt);
        end
    end

    /*
    initial begin
        forever @(posedge clk) begin
            if (uut.ap_start)
                $display("T=%0t | >>> AP_START (Inference Begun) <<<", $time);

            if (uut.ap_done)
                $display("T=%0t | AP_DONE | raw_out=%h", $time, uut.layer15_out_TDATA);

            if (uut.layer15_out_TVALID && uut.layer15_out_TREADY)
                $display("T=%0t | OUT handshake OK | data=%h", $time, uut.layer15_out_TDATA);

            if (uut.input_layer_TVALID && uut.input_layer_TREADY)
                $display("T=%0t | IN  handshake OK | data=%h", $time, uut.input_layer_TDATA);
        end
    end
    */
endmodule