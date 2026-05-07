/**
 * Module name:   top_sensor
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-07
 * Description:  Top-level module for sensor interface, integrating SPI clock generation, 
 * master, and LSM6DSO controller for IMU data acquisition.
 */

module top_sensor (
    input logic clk,
    input logic rst_n,

    output logic cs_n,
    output logic sclk,
    output logic mosi,
    input  logic miso,

    output logic [15:0] gyro_x, 
    output logic [15:0] gyro_y, 
    output logic [15:0] gyro_z,
    output logic [15:0] acc_x, 
    output logic [15:0] acc_y, 
    output logic [15:0] acc_z,
    output logic data_ready
);
    /**
     * Local variables and signals
     */

    localparam DATA_WIDTH = 8;

    logic [DATA_WIDTH-1:0] spi_data_tx;
    logic [DATA_WIDTH-1:0] spi_data_rx;
    logic busy;
    logic valid;
    logic start;
    logic spi_ce_x2;

    
    /**
     * Submodules instances
     */

    spi_ce_gen #(
        /* 100 MHz */
        .MAIN_CLK(100_000_000), 
        /* 1 MHz */
        .SPI_CLK(1_000_000) 
    ) u_spi_ce_gen (
        .clk (clk),
        .rst_n (rst_n),
        .spi_ce_x2 (spi_ce_x2)
    );

    spi_master #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_spi_master (
        .clk(clk),
        .rst_n(rst_n),
        .spi_ce_x2 (spi_ce_x2),
        .start(start),
        .busy(busy),
        .valid(valid),
        .data_out(spi_data_rx),
        .data_in(spi_data_tx),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso)
    );

    lsm6dso_ctrl u_lsm6dso_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .spi_start(start),
        .spi_busy(busy),
        .spi_valid(valid),
        .spi_data_tx(spi_data_tx),
        .spi_data_rx(spi_data_rx),
        .sensor_cs_n(cs_n),
        .gyro_x(gyro_x), 
        .gyro_y(gyro_y), 
        .gyro_z(gyro_z),
        .acc_x(acc_x), 
        .acc_y(acc_y), 
        .acc_z(acc_z),
        .data_ready(data_ready)
    );

endmodule