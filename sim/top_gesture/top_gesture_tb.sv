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

    initial begin
        rst_n = 0;
        miso = 0;
        #100;
        rst_n = 1;
        #100;
        $display("=================================================");
        $display("START SIMULATION: Opening data file...");
        $display("=================================================");

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

                // FIX: Force the output ports of the instantiated top_sensor module directly!
                // This overrides the SPI logic driving them, which XSIM allows.
                force uut.u_top_sensor.gyro_x = gx_int;
                force uut.u_top_sensor.gyro_y = gy_int;
                force uut.u_top_sensor.gyro_z = gz_int;
                force uut.u_top_sensor.acc_x  = ax_int;
                force uut.u_top_sensor.acc_y  = ay_int;
                force uut.u_top_sensor.acc_z  = az_int;
                
                // Also force the data_ready signal coming out of the sensor
                force uut.u_top_sensor.data_ready = 1'b1;
                
                @(posedge clk);
                force uut.u_top_sensor.data_ready = 1'b0;

                // Odstęp między próbkami (przyspieszony dla symulacji)
                repeat(10000) @(posedge clk); 
            end
        end

        $fclose(fd);
        $display("Finished reading CSV file. Waiting for pipelines and voting to finish...");
        
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
        
    // Opcjonalne: podgląd skalowania danych
    /*
    initial begin
        @(posedge rst_n);
        forever @(posedge clk)
            if (uut.data_ready)
                $display("T=%0t | RAW IN: GZ=%d | SCALED IN: %h", $time, uut.raw_gyro_z, uut.scaled_data_in);
    end 
    */

    // Monitorowanie komunikacji AXI
    
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
    

endmodule