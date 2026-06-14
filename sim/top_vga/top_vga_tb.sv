/********************************************************************************
 * Module Name:    top_vga_tb
 * Author:         Eryk Rutka / Bartłomiej Raczyński
 * Date:           2026-06-13
 * Version:        11.5 (Perfect Camera Sync)
 * Description:
 * Creates tiff files for start menu, first card deal,
 * Player0 hit and game results frame.
 ********************************************************************************/

 import ai_type_pkg::*;

 module top_vga_tb;
 
     timeunit 1ns;
     timeprecision 1ps;
 
     localparam real    CLK_PERIOD      = 15.385;
     localparam integer RST_START_TIME  = 30;
     localparam integer RST_ACTIVE_TIME = 30;
 
     // 1344 * 806 * 15.385ns = ~16,663,276 ns per frame
     localparam longint FRAME_NS      = 16_663_276;
     // POPRAWKA: Wymuszenie formatu 64-bitowego, żeby uniknąć warningu o przepełnieniu
     localparam longint MAX_SIM_TIME  = 64'd800_000_000_000;
 
     // --- DUT ports ---
     logic clk, rst_n;
     logic sw_master, uart_rx_pin;
     wire  uart_tx_pin;
     gesture_out tb_gesture;
     wire vs, hs;
     wire [3:0] r, g, b;
 
     initial begin
         clk = 1'b0;
         forever #(CLK_PERIOD / 2.0) clk = ~clk;
     end
 
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
     logic tiff_go;
     initial tiff_go = 1'b0;
 
     tiff_writer #(
         .XDIM(16'd1344),
         .YDIM(16'd806),
         .FILE_DIR("../../results")
     ) u_tiff_writer (
         .clk (clk),
         .r   ({r, r}),
         .g   ({g, g}),
         .b   ({b, b}),
         .go  (tiff_go)
     );
 
     //=========================================================================
     // TASK: wait_frame_boundary
     //=========================================================================
     task automatic wait_frame_boundary();
         @(posedge vs);
         @(negedge vs);
     endtask
 
     //=========================================================================
     // TASK: capture_snapshot  
     //=========================================================================
     task automatic capture_snapshot(input string name);
         @(negedge vs);
         tiff_go = 1'b1;
         repeat(1344 * 806) @(negedge clk);
         tiff_go = 1'b0;
         #(100 * CLK_PERIOD);
         $display("[%0t ns] Snapshot taken: %s", $time, name);
     endtask
 
     //=========================================================================
     // TASK: send_uart_byte
     // POPRAWKA: DVSR=35 definiuje 1/16 bitu. Czas całego bitu to 16 * 35 cykli.
     //=========================================================================
     task automatic send_uart_byte(input logic [7:0] data);
         localparam real BIT_NS = 16.0 * 35.0 * CLK_PERIOD; // Ok. 8615.6 ns
         integer i;
         begin
             uart_rx_pin = 1'b0;          // start bit
             #(BIT_NS);
             for (i = 0; i < 8; i++) begin
                 uart_rx_pin = data[i];
                 #(BIT_NS);
             end
             uart_rx_pin = 1'b1;          // stop bit
             #(BIT_NS);
             #(BIT_NS * 2);               // inter-byte gap
         end
     endtask
 
     //=========================================================================
     // TASK: perform_gesture
     //=========================================================================
     task automatic perform_gesture(input gesture_out gesture);
         @(negedge vs);
         #(100 * CLK_PERIOD);
 
         @(negedge clk);
         tb_gesture = gesture;
         $display("[%0t ns] Gesture applied: %0d", $time, int'(gesture));
 
         repeat(2) @(posedge vs);
         repeat(2) @(negedge vs);
 
         @(negedge clk);
         tb_gesture = NOTHING;
         $display("[%0t ns] Gesture released.", $time);
 
         repeat(1) @(posedge vs);
         repeat(1) @(negedge vs);
     endtask
 
     //=========================================================================
     // Dedykowane taski wait 
     // POPRAWKA: Znacząco zwiększone czasy timeout dla grafiki VGA
     //=========================================================================
     task automatic wait_deal_done();
         fork
             begin : w1
                 wait(dut.deal_done_sig == 1'b1);
                 $display("[%0t ns] deal_done!", $time);
             end
             begin : t1
                 #(800_000_000); // <-- POPRAWKA
                 $display("[%0t ns] WARN: deal_done timeout", $time);
             end
         join_any
         disable fork;
     endtask
 
     task automatic wait_p1_turn();
         fork
             begin : w2
                 wait(dut.sig_p1_turn_sig == 1'b1);
                 $display("[%0t ns] p1_turn!", $time);
             end
             begin : t2
                 #(500_000_000); // <-- POPRAWKA
                 $display("[%0t ns] WARN: p1_turn timeout", $time);
             end
         join_any
         disable fork;
     endtask
 
     task automatic wait_dealer_turn();
         fork
             begin : w3
                 wait(dut.sig_dealer_turn_sig == 1'b1);
                 $display("[%0t ns] dealer_turn!", $time);
             end
             begin : t3
                 #(800_000_000); // <-- POPRAWKA
                 $display("[%0t ns] WARN: dealer_turn timeout", $time);
             end
         join_any
         disable fork;
     endtask
 
     task automatic wait_game_over();
         fork
             begin : w4
                 wait(dut.sig_game_over_sig == 1'b1);
                 $display("[%0t ns] game_over!", $time);
             end
             begin : t4
                 #(1_500_000_000); // <-- POPRAWKA
                 $display("[%0t ns] WARN: game_over timeout", $time);
             end
         join_any
         disable fork;
     endtask
 
     // --- WATCHDOG ---
     initial begin
         #(MAX_SIM_TIME);
         $display("WATCHDOG TIMEOUT");
         $finish;
     end
 
     //=========================================================================
     // MAIN STIMULUS
     //=========================================================================
     initial begin
         sw_master   = 1'b1;
         uart_rx_pin = 1'b1;
         tb_gesture  = NOTHING;
         tiff_go     = 1'b0;
 
         // Reset
         rst_n = 1'b1;
         #(RST_START_TIME);
         rst_n = 1'b0;
         #(RST_ACTIVE_TIME);
         rst_n = 1'b1;
 
         // Stabilizacja - czekaj 4 klatki
         $display("[%0t ns] Czekam na stabilizacje...", $time);
         repeat(4) @(posedge vs);
         repeat(4) @(negedge vs);
         $display("[%0t ns] Stabilizacja OK.", $time);
 
         // ----------------------------------------------------------------
         // TIFF 1: Start Screen
         // ----------------------------------------------------------------
         $display("[%0t ns] === TIFF 1: Start Screen ===", $time);
         capture_snapshot("TIFF 1: Start Screen");
 
         // ----------------------------------------------------------------
         // KNOCK -> Start Game
         // ----------------------------------------------------------------
         $display("[%0t ns] === KNOCK: Start Game ===", $time);
         perform_gesture(KNOCK);
 
         // Czekaj na deal_done
         wait_deal_done();
         // 2 klatki po deal dla renderowania
         repeat(2) @(posedge vs);
         repeat(2) @(negedge vs);
 
         // ----------------------------------------------------------------
         // TIFF 2: Initial Deal
         // ----------------------------------------------------------------
         $display("[%0t ns] === TIFF 2: Initial Deal ===", $time);
         capture_snapshot("TIFF 2: Initial Deal");
 
         // ----------------------------------------------------------------
         // KNOCK -> Master HIT
         // ----------------------------------------------------------------
         $display("[%0t ns] === KNOCK: Master HIT ===", $time);
         perform_gesture(KNOCK);
 
         // Czekaj az busy opadnie
         fork
             begin : wb
                 @(negedge dut.busy_sig);
                 $display("[%0t ns] busy=0, karta dobrana.", $time);
             end
             begin : tb2
                 #(400_000_000); // <-- POPRAWKA
                 $display("[%0t ns] WARN: busy timeout", $time);
             end
         join_any
         disable fork;
 
         repeat(2) @(posedge vs);
         repeat(2) @(negedge vs);
 
         // ----------------------------------------------------------------
         // TIFF 3: Master Draws a Card
         // ----------------------------------------------------------------
         $display("[%0t ns] === TIFF 3: Master Draws a Card ===", $time);
         capture_snapshot("TIFF 3: Master Draws a Card");
 
         // ----------------------------------------------------------------
         // SWIPE_RIGHT -> Master STAND
         // ----------------------------------------------------------------
         $display("[%0t ns] === SWIPE_RIGHT: Master STAND ===", $time);
         perform_gesture(SWIPE_RIGHT);
 
         // Czekaj na ture slave
         wait_p1_turn();
         #(2_000_000);
 
         // ----------------------------------------------------------------
         // Slave HIT via UART
         // ----------------------------------------------------------------
         $display("[%0t ns] === Slave HIT (0xC1) ===", $time);
         send_uart_byte(8'hC1); // <-- POPRAWKA: Prawidłowy OPCODE dla HIT
 
         repeat(3) @(posedge vs);
         repeat(3) @(negedge vs);
 
         // ----------------------------------------------------------------
         // TIFF 4: Slave Draws a Card
         // ----------------------------------------------------------------
         $display("[%0t ns] === TIFF 4: Slave Draws a Card ===", $time);
         capture_snapshot("TIFF 4: Slave Draws a Card");
 
         // ----------------------------------------------------------------
         // Slave STAND via UART
         // ----------------------------------------------------------------
         $display("[%0t ns] === Slave STAND (0xC2) ===", $time);
         send_uart_byte(8'hC2); // <-- POPRAWKA: Prawidłowy OPCODE dla STAND
 
         wait_dealer_turn();
         wait_game_over();
 
         repeat(3) @(posedge vs);
         repeat(3) @(negedge vs);
 
         // ----------------------------------------------------------------
         // TIFF 5: Game Over Screen
         // ----------------------------------------------------------------
         $display("[%0t ns] === TIFF 5: Game Over Screen ===", $time);
         capture_snapshot("TIFF 5: Game Over Screen");
 
         #(1_000 * CLK_PERIOD);
         $display("[%0t ns] Simulation complete!", $time);
         $finish;
     end
 
 endmodule