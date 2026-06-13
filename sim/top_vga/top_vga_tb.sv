/********************************************************************************
 * Module Name:    top_vga_tb
 * Author:         Eryk Rutka / Bartłomiej Raczyński
 * Date:           2026-06-13
 * Version:        11.5 (Perfect Camera Sync)
 * Description:
 * Testbench adapted to hit the exact active area of the VGA frame.
 * Fixed the tiff_go trigger logic to completely eliminate frame wrapping.
 ********************************************************************************/

 import ai_type_pkg::*;

 module top_vga_tb;
 
     timeunit 1ns;
     timeprecision 1ps;
 
     // --- Timing parameters ---
     localparam real    CLK_PERIOD      = 15.385;   // ~65 MHz VGA
     localparam integer RST_START_TIME  = 30;
     localparam integer RST_ACTIVE_TIME = 30;
 
     localparam longint MAX_SIM_TIME      = 350_000_000; 
     localparam longint SNAPSHOT_TIMEOUT  =  55_000_000; 
 
     // --- DUT ports ---
     logic clk, rst_n;
     logic sw_master, uart_rx_pin;
     wire  uart_tx_pin;
     gesture_out tb_gesture;
     wire vs, hs;
     wire [3:0] r, g, b;
 
     initial begin clk = 1'b0; forever #(CLK_PERIOD / 2.0) clk = ~clk; end
 
     // --- DUT instantiation ---
     top_vga dut (
         .clk             (clk),
         .rst_n           (rst_n),
         .current_gesture (tb_gesture),
         .sw_master       (sw_master),
         .uart_rx_pin     (uart_rx_pin),
         .uart_tx_pin     (uart_tx_pin),
         .vs              (vs),
         .hs              (hs),
         .r               (r),
         .g               (g),
         .b               (b)
     );
 
     // --- TIFF writer ---
     logic capture_en = 1'b0;
     
     // KLUCZOWA POPRAWKA: Migawka kamery musi byc na 0, gdy nie robimy zdjecia!
     wire  tiff_go = capture_en ? vs : 1'b0;
 
     tiff_writer #(.XDIM(16'd1344), .YDIM(16'd806), .FILE_DIR("../../results"))
     u_tiff_writer (
         .clk (clk),
         .r   ({r, r}),
         .g   ({g, g}),
         .b   ({b, b}),
         .go  (tiff_go)
     );
 
     // --- TASKS ---
     task automatic capture_snapshot(input string name);
         fork
             begin : capture_proc
                 @(posedge vs);
                 capture_en = 1'b1;
                 @(negedge vs);
                 @(posedge vs);
                 capture_en = 1'b0;
                 $display("[%0t ns] Snapshot taken: %s", $time, name);
             end
             begin : timeout_proc
                 #(SNAPSHOT_TIMEOUT);
                 capture_en = 1'b0;   
                 $display("[%0t ns] WARNING: Timeout. Skipping: %s", $time, name);
             end
         join_any
         disable fork;  
     endtask
 
     task automatic send_uart_byte(input logic [7:0] data);
         integer i;
         localparam integer BIT_TICKS = 564; 
         begin
             uart_rx_pin = 1'b0; #(BIT_TICKS * CLK_PERIOD); 
             for (i = 0; i < 8; i++) begin
                 uart_rx_pin = data[i]; #(BIT_TICKS * CLK_PERIOD);
             end
             uart_rx_pin = 1'b1; #(BIT_TICKS * CLK_PERIOD); 
         end
     endtask

     task automatic perform_gesture(input gesture_out gesture);
         @(negedge vs);
         #(537600 * CLK_PERIOD); 
         @(posedge hs);
         #(500 * CLK_PERIOD); 
         
         @(negedge clk);
         tb_gesture = gesture;
         #(50 * CLK_PERIOD); 
         
         @(negedge clk);
         tb_gesture = NOTHING;
         #(500 * CLK_PERIOD); 
     endtask
 
     // --- WATCHDOG ---
     initial begin
         #(MAX_SIM_TIME);
         $display("WATCHDOG TIMEOUT: simulation exceeded limit.");
         $finish;
     end
 
     // --- MAIN STIMULUS ---
     initial begin
         sw_master    = 1'b1;
         uart_rx_pin  = 1'b1;  
         tb_gesture   = NOTHING;
 
         rst_n = 1'b1;
         #(RST_START_TIME)  rst_n = 1'b0;
         #(RST_ACTIVE_TIME) rst_n = 1'b1;
         
         // Zabezpieczenie przed artefaktami na pierwszej klatce
         $display("[%0t ns] Czekam na stabilizacje monitora...", $time);
         @(posedge vs);
         @(posedge vs);
         
         capture_snapshot("TIFF 1: Start Screen");
 
         $display("[%0t ns] Simulating Gesture KNOCK (Start Game)", $time);
         perform_gesture(KNOCK);
         capture_snapshot("TIFF 2: Initial Deal");
 
         $display("[%0t ns] Simulating Gesture KNOCK (Master HIT)", $time);
         perform_gesture(KNOCK);
         capture_snapshot("TIFF 3: Master Draws a Card");
 
         $display("[%0t ns] Simulating Gesture SWIPE_RIGHT (Master STAND)", $time);
         perform_gesture(SWIPE_RIGHT);
         #(200 * CLK_PERIOD);
 
         $display("[%0t ns] Sending Slave HIT command via UART (0x11)", $time);
         send_uart_byte(8'h11);
         capture_snapshot("TIFF 4: Slave Draws a Card");
 
         $display("[%0t ns] Sending Slave STAND command via UART (0x12)", $time);
         send_uart_byte(8'h12);
 
         #(1000 * CLK_PERIOD);
         capture_snapshot("TIFF 5: Final Table (Dealer's Turn)");
 
         $display("Simulation complete! 5 PERFECT TIFF files should have been created.");
         $finish;
     end
 
 endmodule