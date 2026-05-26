/********************************************************************************
 * Module Name:    vga_if.sv
 * Author:         Eryk Rutka
 * Date:           2026-05-18
 * Version:        1.0
 * * Description:    
 * Interface for VGA. 
 ********************************************************************************/

 interface vga_if; 

    logic [10:0] hcount;
    logic hsync;
    logic hblnk;
    logic [10:0] vcount;
    logic vsync;
    logic vblnk;
    logic [11:0] rgb;

    modport in ( 
        input vcount,
        input vsync,
        input vblnk,
        input hcount,
        input hsync,
        input hblnk,
        input rgb
    );

    modport out (
        output vcount,
        output vsync,
        output vblnk,
        output hcount,
        output hsync,
        output hblnk,
        output rgb
    );

endinterface