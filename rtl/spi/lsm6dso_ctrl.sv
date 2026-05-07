/**
 * Module name:   lsm6dso_ctrl
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-07
 * Description:  This module controls the LSM6DSO IMU sensor via SPI,
 * performing initialization, status polling, and burst data reading for gyroscope and accelerometer outputs.
 */

import lsm6dso_pkg::*;

module lsm6dso_ctrl (
    input  logic clk,
    input  logic rst_n,

    output logic [7:0] spi_data_tx,
    output logic       spi_start,
    input  logic [7:0] spi_data_rx,
    input  logic       spi_busy,
    input  logic       spi_valid,

    output logic       sensor_cs_n,
    output logic [15:0] gyro_x, 
    output logic [15:0] gyro_y, 
    output logic [15:0] gyro_z,
    output logic [15:0] acc_x, 
    output logic [15:0] acc_y, 
    output logic [15:0] acc_z,
    output logic        data_ready
);

/* Local variables and signals */
typedef enum logic [4:0] {
    ST_RESET,
    
    /* INIT: CTRL3_C (BDU + Auto-increment) */
    ST_INIT_BDU_ADDR, ST_INIT_BDU_DATA,
    /* INIT: CTRL1_XL (Accelerometer) */
    ST_INIT_ACC_ADDR, ST_INIT_ACC_DATA,
    /* INIT: CTRL2_G (Gyroscope) */
    ST_INIT_GYR_ADDR, ST_INIT_GYR_DATA,
    
    /* Polling */
    ST_IDLE,
    ST_POLL_ADDR, ST_POLL_DATA,
    
    /* Burst Read (12 bytes) */
    ST_BURST_ADDR, 
    ST_BURST_READ,
    
    ST_DONE
} state_t;

state_t state, state_nxt;

logic [3:0] byte_cnt, byte_cnt_nxt; 
logic [7:0] data_buffer [0:11];     
logic       data_ready_nxt;
logic       sensor_cs_n_nxt;
logic [7:0] spi_data_tx_nxt;
logic       spi_start_nxt;

logic [15:0] gyro_x_nxt; 
logic [15:0] gyro_y_nxt; 
logic [15:0] gyro_z_nxt;
logic [15:0] acc_x_nxt; 
logic [15:0] acc_y_nxt; 
logic [15:0] acc_z_nxt;

/* Module internal logic */

/* State Sequencer Logic */
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state       <= ST_RESET;
        byte_cnt    <= '0;
        data_ready  <= 1'b0;
        sensor_cs_n <= 1'b1;
        spi_data_tx <= '0;
        spi_start   <= 1'b0;

        gyro_x <= '0;
        gyro_y <= '0;
        gyro_z <= '0;
        acc_x <= '0;
        acc_y <= '0;
        acc_z <= '0;

        for (int i = 0; i < 12; i++) begin
            data_buffer[i] <= 8'h00;
        end
    end else begin
        state       <= state_nxt;
        byte_cnt    <= byte_cnt_nxt;
        data_ready  <= data_ready_nxt;
        sensor_cs_n <= sensor_cs_n_nxt;
        spi_data_tx <= spi_data_tx_nxt;
        spi_start   <= spi_start_nxt;

        gyro_x <= gyro_x_nxt;
        gyro_y <= gyro_y_nxt;
        gyro_z <= gyro_z_nxt;
        acc_x <= acc_x_nxt;
        acc_y <= acc_y_nxt;
        acc_z <= acc_z_nxt;
        
        /* Saving received data in Burst mode */
        if (state == ST_BURST_READ && spi_valid) begin
            data_buffer[byte_cnt] <= spi_data_rx;
        end
    end
end

/* Next State Decode Logic */
always_comb begin
    state_nxt       = state;
    byte_cnt_nxt    = byte_cnt;

    case (state)
        ST_RESET: begin
            state_nxt = ST_INIT_BDU_ADDR;
        end

        ST_INIT_BDU_ADDR: begin
            if (spi_valid) begin 
                state_nxt = ST_INIT_BDU_DATA;
            end
        end
        ST_INIT_BDU_DATA: begin
            if (spi_valid) begin
                state_nxt = ST_INIT_ACC_ADDR;
            end
        end

        ST_INIT_ACC_ADDR: begin
            if (spi_valid) begin 
                state_nxt = ST_INIT_ACC_DATA;
            end
        end
        ST_INIT_ACC_DATA: begin
            if (spi_valid) begin
                state_nxt = ST_INIT_GYR_ADDR;
            end
        end

        ST_INIT_GYR_ADDR: begin
            if (spi_valid) begin 
                state_nxt = ST_INIT_GYR_DATA;
            end
        end
        ST_INIT_GYR_DATA: begin
            if (spi_valid) begin
                state_nxt = ST_IDLE;
            end
        end

        ST_IDLE: begin
            if (spi_valid) begin 
                state_nxt = ST_POLL_DATA;
            end
        end
        ST_POLL_DATA: begin
            if (spi_valid) begin
                /* Check if XLDA (bit 0) and GDA (bit 1) are equal to 1 -> together 0x03 */
                if ((spi_data_rx & 8'h03) == 8'h03) begin
                    state_nxt = ST_BURST_ADDR;
                end else begin
                    state_nxt = ST_IDLE;
                end
            end
        end

        ST_BURST_ADDR: begin
            byte_cnt_nxt    = '0;       
            if (spi_valid) state_nxt = ST_BURST_READ;
        end
        
        ST_BURST_READ: begin
            if (spi_valid) begin
                if (byte_cnt == 11) begin
                    state_nxt = ST_DONE;
                end else begin
                    byte_cnt_nxt = byte_cnt + 1;
                end
            end
        end

        ST_DONE: begin
            state_nxt = ST_IDLE;
        end

        default: state_nxt = ST_RESET;
    endcase
end

/* Output Decode Logic */
always_comb begin
    data_ready_nxt  = 1'b0;
    sensor_cs_n_nxt = sensor_cs_n;
    spi_data_tx_nxt = spi_data_tx;
    spi_start_nxt   = 1'b0;

    /* Assembling 8-bit data from buffer into 16-bit outputs */
    /* Little Endian: {High_Byte, Low_Byte} */
    gyro_x_nxt = {data_buffer[1],  data_buffer[0]};
    gyro_y_nxt = {data_buffer[3],  data_buffer[2]};
    gyro_z_nxt = {data_buffer[5],  data_buffer[4]};

    acc_x_nxt  = {data_buffer[7],  data_buffer[6]};
    acc_y_nxt  = {data_buffer[9],  data_buffer[8]};
    acc_z_nxt  = {data_buffer[11], data_buffer[10]};

    case (state)
        ST_RESET: begin
            sensor_cs_n_nxt = 1'b1;
        end

        ST_INIT_BDU_ADDR: begin
            sensor_cs_n_nxt = 1'b0;    
            spi_data_tx_nxt = CTRL3_C;    
            if (!spi_busy && !spi_start) spi_start_nxt = 1'b1; 
        end

        ST_INIT_BDU_DATA: begin
            spi_data_tx_nxt = INIT_BDU;
            if (!spi_busy && !spi_start) spi_start_nxt = 1'b1; 
            if (spi_valid) sensor_cs_n_nxt = 1'b1; 
        end

        ST_INIT_ACC_ADDR: begin
            sensor_cs_n_nxt = 1'b0;
            spi_data_tx_nxt = CTRL1_XL;
            if (!spi_busy && !spi_start) spi_start_nxt = 1'b1; 
        end
        ST_INIT_ACC_DATA: begin
            spi_data_tx_nxt = INIT_ACCELATOR;
            if (!spi_busy && !spi_start) spi_start_nxt = 1'b1; 
            if (spi_valid) sensor_cs_n_nxt = 1'b1;
        end

        ST_INIT_GYR_ADDR: begin
            sensor_cs_n_nxt = 1'b0;
            spi_data_tx_nxt = CTRL2_G;
            if (!spi_busy && !spi_start) spi_start_nxt = 1'b1; 
        end
        ST_INIT_GYR_DATA: begin
            spi_data_tx_nxt = INIT_GYRO;
            if (!spi_busy && !spi_start) spi_start_nxt = 1'b1; 
            if (spi_valid) sensor_cs_n_nxt = 1'b1;
        end

        ST_IDLE: begin
            sensor_cs_n_nxt = 1'b0;
            spi_data_tx_nxt = READ_STATUS_REG;
            if (!spi_busy && !spi_start) spi_start_nxt = 1'b1; 
        end
        ST_POLL_DATA: begin
            spi_data_tx_nxt = 8'h00; 
            if (!spi_busy && !spi_start) spi_start_nxt = 1'b1; 
            if (spi_valid) sensor_cs_n_nxt = 1'b1;
        end

        ST_BURST_ADDR: begin
            sensor_cs_n_nxt = 1'b0;      
            /* 0x22 (OUTX_L_G) | 0x80 = 0xA2 */
            spi_data_tx_nxt = READ_OUTX_L_G;     
            if (!spi_busy && !spi_start) spi_start_nxt = 1'b1; 
        end
        
        ST_BURST_READ: begin
            spi_data_tx_nxt = 8'h00;
            if (!spi_busy && !spi_start) spi_start_nxt = 1'b1;
        end

        ST_DONE: begin
            data_ready_nxt  = 1'b1;
            sensor_cs_n_nxt = 1'b1;
        end
        
        default: ; 
    endcase
end

endmodule