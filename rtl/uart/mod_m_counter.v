/********************************************************************************
 * Module Name:    mod_m_counter
 *                 Eryk Rutka
 * Date:           2026-06-05
 * Version:        1.0
 * Description:    
 * Modulo-M counter acting as a baud rate generator (tick generator) for 
 * the UART transceiver. Divides the main system clock to achieve the 
 * desired oversampling frequency.
 ********************************************************************************/

 // Listing 4.11
module mod_m_counter
   #(
    parameter N=4, // number of bits in counter
              M=10 // mod-M
   )
   (
    input wire clk, reset,
    output wire max_tick,
    output wire [N-1:0] q
   );

   //signal declaration
   reg [N-1:0] r_reg;
   wire [N-1:0] r_next;

   // body
   // register
   always @(posedge clk, posedge reset)
      if (reset)
         r_reg <= 0;
      else
         r_reg <= r_next;

   // next-state logic
   assign r_next = (r_reg==(M-1)) ? 0 : r_reg + 1;
   // output logic
   assign q = r_reg;
   assign max_tick = (r_reg==(M-1)) ? 1'b1 : 1'b0;

endmodule