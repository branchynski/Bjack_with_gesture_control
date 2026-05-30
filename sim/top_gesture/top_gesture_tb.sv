/**
 * Testbench name: top_gesture_tb
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-30
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
        forever #5 clk = ~clk;
    end

    int fd;
    int status;
    string dummy_header;
    
    real ts, gx, gy, gz, ax, ay, az; 
    
    logic [15:0] gx_int, gy_int, gz_int, ax_int, ay_int, az_int;
    logic [95:0] payload;

    initial begin
        rst_n = 0;
        miso = 0;
        #100;
        rst_n = 1;
        #100;
        $display("START SIMULATION: Opening data file:");

        fd = $fopen("../top_gesture/knock.csv", "r");
        if (fd == 0) begin
            $error("ERROR: Cannot open file knock.csv! Check that the file exists in sim/build or sim/top_gesture.");
            $finish;
        end

        status = $fgets(dummy_header, fd);

        while (!$feof(fd)) begin
            status = $fscanf(fd, "%f,%f,%f,%f,%f,%f,%f\n", ts, gx, gy, gz, ax, ay, az);
            
            if (status == 7) begin
                gx_int = int'(gx);
                gy_int = int'(gy);
                gz_int = int'(gz);
                ax_int = int'(ax);
                ay_int = int'(ay);
                az_int = int'(az);

                payload = {gz_int, gy_int, gx_int, az_int, ay_int, ax_int};

                force uut.data_in = payload;
                force uut.data_ready = 1'b1;
                
                @(posedge clk);
                force uut.data_ready = 1'b0;

                repeat(10000) @(posedge clk); 
            end
        end

        $fclose(fd);
        $display("Finished reading file. Waiting for pipelines to drain...");
        
        repeat(150000) @(posedge clk); 

        $display("END OF SIMULATION.");
        $finish;
    end

    initial begin
        $monitor("Time: %0t ns | GESTURE DETECTED: %s", $time, gesture.name());
    end
        
    initial begin
        @(posedge rst_n);
        forever @(posedge clk)
            if (uut.data_ready)
                $display("T=%0t | data_ready PULSE | data_in=%h", $time, uut.data_in);
    end 

    initial begin
        forever @(posedge clk) begin

            if (uut.ap_start)
                $display("T=%0t | >>> AP_START <<<", $time);

            if (uut.ap_done)
                $display("T=%0t | AP_DONE | raw_out=%h", $time, uut.layer15_out_TDATA);

            if (uut.layer15_out_TVALID && uut.layer15_out_TREADY)
                $display("T=%0t | OUT handshake OK | data=%h", $time, uut.layer15_out_TDATA);

            if (uut.input_layer_TVALID && uut.input_layer_TREADY)
                $display("T=%0t | IN  handshake OK | data=%h", $time, uut.input_layer_TDATA);

            if (uut.full_buffer)
                $display("T=%0t | BUFFER FULL", $time);
        end
    end

endmodule