/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
 *
 * Modified by:
 * 2025  AGH University of Science and Technology
 * MTM UEC2
 * Piotr Kaczmarczyk
 *
 * Description:
 * Top level synthesizable module including the project top and all the FPGA-referred modules.
 */

module top_vga_basys3 (
        input  wire clk,
        input  wire btnC,
        output wire Vsync,
        output wire Hsync,
        output wire [3:0] vgaRed,
        output wire [3:0] vgaGreen,
        output wire [3:0] vgaBlue,
        output wire JA1,
        output wire JC1,
        output wire JC3,
        input wire JC2,
        output wire JC4,

        output wire [2:0] led,

        input  wire RsRx,
        output wire RsTx,

        input wire sw_master
    );

    timeunit 1ns;
    timeprecision 1ps;

    /**
     * Local variables and signals
     */

    wire clk_in, clk_fb, clk_ss, clk_out;
    wire locked;
    wire pclk;
    wire pclk_mirror;

    (* KEEP = "TRUE" *)
    (* ASYNC_REG = "TRUE" *)
    logic [7:0] safe_start = 0;
    // For details on synthesis attributes used above, see AMD Xilinx UG 901:
    // https://docs.xilinx.com/r/en-US/ug901-vivado-synthesis/Synthesis-Attributes


    /**
     * Signals assignments
     */

    assign JA1 = pclk_mirror;


    /**
     * FPGA submodules placement
     */
    clk_wiz_0 clk_wiz_0_inst (

        .clk(clk),

        .clk_65MHz(pclk),

        .locked(locked)

     );


    // Mirror pclk on a pin for use by the testbench;
    // not functionally required for this design to work.

    ODDR pclk_oddr (
        .Q(pclk_mirror),
        .C(pclk),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(1'b0),
        .S(1'b0)
    );


    /**
     *  Project functional top module
     */

    top_game u_top_game (
        .clk(pclk),
        .rst_n(!btnC && locked),
        .cs_n(JC1), 
        .sclk(JC3), 
        .mosi(JC4), 
        .miso(JC2), 

        .rx(RsRx),
        .tx(RsTx),

        .sw_master(sw_master),
        .vs(Vsync),
        .hs(Hsync),
        .r(vgaRed),
        .g(vgaGreen),
        .b(vgaBlue),

        .leds(led[2:0])

    );

endmodule
