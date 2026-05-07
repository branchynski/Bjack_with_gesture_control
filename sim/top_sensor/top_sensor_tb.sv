/**
 * Testbench name: top_sensor_tb
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-07
 * Description:  Testbench for the top_sensor module, simulating SPI communication and verifying IMU data reading from LSM6DSO sensor.
 */

module top_sensor_tb;

    timeunit 1ns;
    timeprecision 1ps;

    logic clk;
    logic rst_n;
    
    logic cs_n;
    logic sclk;
    logic mosi;
    logic miso;
    
    logic [15:0] gyro_x, gyro_y, gyro_z;
    logic [15:0] acc_x, acc_y, acc_z;
    logic data_ready;

    top_sensor dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .cs_n       (cs_n),
        .sclk       (sclk),
        .mosi       (mosi),
        .miso       (miso),
        .gyro_x     (gyro_x),
        .gyro_y     (gyro_y),
        .gyro_z     (gyro_z),
        .acc_x      (acc_x),
        .acc_y      (acc_y),
        .acc_z      (acc_z),
        .data_ready (data_ready)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    logic [7:0] shift_reg_rx = 8'h00; 

    always @(posedge sclk or posedge cs_n) begin
        if (cs_n) begin
            shift_reg_rx <= 8'h00;
        end else begin
            shift_reg_rx <= {shift_reg_rx[6:0], mosi}; 
        end
    end

    always @(posedge cs_n) begin
        $display("[%0t] SPI Transaction Finished. Received CMD from Master: %h", $time, shift_reg_rx);
    end

    task send_spi_byte(input logic [7:0] data_to_send);
        for (int i = 7; i >= 0; i--) begin
            miso = data_to_send[i];  
            @(negedge sclk);         
        end
    endtask

    initial begin
        miso = 1'b0; 
        rst_n = 0;
      #100;
        rst_n = 1;

        $display("System released from reset. Starting simulation...");

        wait(dut.u_lsm6dso_ctrl.state == dut.u_lsm6dso_ctrl.ST_POLL_DATA);
        $display("[%0t] Entered ST_POLL_DATA state. Simulating Sensor Ready...", $time);
        
        send_spi_byte(8'h03);
        
        wait(dut.u_lsm6dso_ctrl.state == dut.u_lsm6dso_ctrl.ST_BURST_READ);
        $display("[%0t] Entered ST_BURST_READ state. Sending dummy sensor data...", $time);

        send_spi_byte(8'h11); /* Gyro X (L) */
        send_spi_byte(8'h22); /* Gyro X (H) -> gyro_x = 0x2211 */
        send_spi_byte(8'h33); /* Gyro Y (L) */
        send_spi_byte(8'h44); /* Gyro Y (H) -> gyro_y = 0x4433 */
        send_spi_byte(8'h55); /* Gyro Z (L) */
        send_spi_byte(8'h66); /* Gyro Z (H) */
        send_spi_byte(8'h77); /* Acc X (L) */
        send_spi_byte(8'h88); /* Acc X (H) */
        send_spi_byte(8'h99); /* Acc Y (L) */
        send_spi_byte(8'hAA); /* Acc Y (H) */
        send_spi_byte(8'hBB); /* Acc Z (L) */
        send_spi_byte(8'hCC); /* Acc Z (H) -> acc_z = 0xCCBB */

        @(posedge data_ready);
        $display("========================================");
        $display("SUCCESS: data_ready flag is HIGH!");
        $display("Decoded Gyro X: %h (Expected: 2211)", gyro_x);
        $display("Decoded Gyro Y: %h (Expected: 4433)", gyro_y);
        $display("Decoded Gyro Z: %h (Expected: 6655)", gyro_z);
        $display("Decoded Acc  X: %h (Expected: 8877)", acc_x);
        $display("Decoded Acc  Y: %h (Expected: aa99)", acc_y);
        $display("Decoded Acc  Z: %h (Expected: ccbb)", acc_z);
        $display("========================================");
        
        if (gyro_x == 16'h2211 && gyro_y == 16'h4433 && gyro_z == 16'h6655 &&
            acc_x == 16'h8877 && acc_y == 16'haa99 && acc_z == 16'hccbb) begin
            $display("ALL TESTS PASSED - All sensor data decoded correctly!");
        end else begin
            $display("TEST FAILED - Sensor data mismatch detected!");
            if (gyro_x != 16'h2211) $display("  ERROR: Gyro X mismatch: got %h, expected 2211", gyro_x);
            if (gyro_y != 16'h4433) $display("  ERROR: Gyro Y mismatch: got %h, expected 4433", gyro_y);
            if (gyro_z != 16'h6655) $display("  ERROR: Gyro Z mismatch: got %h, expected 6655", gyro_z);
            if (acc_x != 16'h8877) $display("  ERROR: Acc X mismatch: got %h, expected 8877", acc_x);
            if (acc_y != 16'haa99) $display("  ERROR: Acc Y mismatch: got %h, expected aa99", acc_y);
            if (acc_z != 16'hccbb) $display("  ERROR: Acc Z mismatch: got %h, expected ccbb", acc_z);
        end

        #1000;
        $finish; 
    end

endmodule