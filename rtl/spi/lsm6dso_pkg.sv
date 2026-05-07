/**
 * Module name:   lsm6dso_pkg
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-07
 * Description:  Package containing constants and parameters for LSM6DSO IMU sensor configuration and register addresses.
 */

package lsm6dso_pkg;

   localparam CTRL3_C = 8'h12;
   localparam INIT_BDU = 8'h44;
   localparam CTRL1_XL = 8'h10;
   localparam INIT_ACCELATOR = 8'h40;
   localparam CTRL2_G = 8'h11;
   localparam INIT_GYRO = 8'h40;
   localparam READ_STATUS_REG = 8'h9E;
   localparam READ_OUTX_L_G = 8'hA2;

endpackage