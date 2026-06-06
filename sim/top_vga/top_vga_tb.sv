/********************************************************************************
 * Module Name:    top_vga_tb
 * Author:         Eryk Rutka / Bartłomiej Raczyński
 * Date:           2026-06-06
 * Version:        10.0 
 * Description:    
 * Testbench now includes the Slave STAND command to allow the FSM to transition
 * to the Dealer's turn. Captures the final board state after Dealer draws.
 ********************************************************************************/

 import ai_type_pkg::*;

 module top_vga_tb;
 
     timeunit 1ns;
     timeprecision 1ps;
 
     localparam real CLK_PERIOD = 15.385;     
     localparam RST_START_TIME = 30;
     localparam RST_ACTIVE_TIME = 30;
 
     logic clk, rst_n;
     logic btn_start, btn_hit, btn_stand;
     logic sw_master, uart_rx_pin;
     wire  uart_tx_pin;
     
     gesture_out tb_gesture;
 
     wire vs, hs;
     wire [3:0] r, g, b;
     wire tb_ps2_clk, tb_ps2_data;
     logic clk_100MHz = 0;
 
     initial begin clk = 1'b0; forever #(CLK_PERIOD/2.0) clk = ~clk; end
     initial begin clk_100MHz = 1'b0; forever #5 clk_100MHz = ~clk_100MHz; end
 
     top_vga dut (
         .clk(clk), .rst_n(rst_n),
         .btn_start(btn_start), .btn_hit(btn_hit), .btn_stand(btn_stand),
         .current_gesture(tb_gesture), 
         .sw_master(sw_master), .uart_rx_pin(uart_rx_pin), .uart_tx_pin(uart_tx_pin),
         .vs(vs), .hs(hs), .r(r), .g(g), .b(b),
         .ps2_clk(tb_ps2_clk), .ps2_data(tb_ps2_data), .clk_100MHz(clk_100MHz)
     );
 
     logic capture_en = 1'b0;
     wire tiff_go = capture_en ? vs : 1'b1; 
 
     tiff_writer #(.XDIM(16'd1344), .YDIM(16'd806), .FILE_DIR("../../results")) 
     u_tiff_writer (
         .clk(clk), .r({r,r}), .g({g,g}), .b({b,b}), .go(tiff_go)
     );
 
     task capture_snapshot(input string name);
         @(posedge vs); capture_en = 1'b1;
         @(negedge vs); @(posedge vs);
         capture_en = 1'b0;
         $display("[%0t ns] Zrobiono zdjecie: %s", $time, name);
     endtask
 
     task send_uart_byte(input logic [7:0] data);
         integer i;
         localparam integer BIT_TICKS = 3385; 
         begin
             uart_rx_pin = 1'b0; #(BIT_TICKS * CLK_PERIOD);
             for (i = 0; i < 8; i++) begin
                 uart_rx_pin = data[i]; #(BIT_TICKS * CLK_PERIOD);
             end
             uart_rx_pin = 1'b1; #(BIT_TICKS * CLK_PERIOD);
         end
     endtask
 
     initial begin
         btn_start = 1'b0; btn_hit = 1'b0; btn_stand = 1'b0;
         sw_master = 1'b1; uart_rx_pin = 1'b1;
         tb_gesture = gesture_out'(0); 
         
         rst_n = 1'b1;
         #(RST_START_TIME) rst_n = 1'b0;
         #(RST_ACTIVE_TIME) rst_n = 1'b1;
 
         #100;
 
         // --- ZDJĘCIE 1: EKRAN STARTOWY ---
         capture_snapshot("TIFF 1: Ekran START");
 
         // --- ZDJĘCIE 2: POCZĄTEK GRY ---
         btn_start = 1'b1; #(10 * CLK_PERIOD); btn_start = 1'b0; 
         capture_snapshot("TIFF 2: Rozdanie poczatkowe");
 
         // --- ZDJĘCIE 3: DOBRANIE KARTY (MASTER HIT) ---
         btn_hit = 1'b1; #(10 * CLK_PERIOD); btn_hit = 1'b0; 
         capture_snapshot("TIFF 3: Master dobiera karte");
 
         // --- MASTER PASUJE ---
         btn_stand = 1'b1; #(10 * CLK_PERIOD); btn_stand = 1'b0; 
         #(200 * CLK_PERIOD); 
 
         // --- ZDJĘCIE 4: RUCH SLAVE'A PRZEZ UART ---
         send_uart_byte(8'h11); // Wysłanie komendy HIT
         capture_snapshot("TIFF 4: Slave dobiera karte");
 
         // --- SLAVE PASUJE (PRZEKAZANIE TURY KRUPIEROWI) ---
         $display("[%0t ns] Slave wciska STAND przez UART", $time);
         send_uart_byte(8'h12); // Wysłanie komendy STAND
         
         // Krupier rozgrywa teraz swoją turę. Dajemy sprzętowi czas na ewentualne dociągnięcie kart.
         #(1000 * CLK_PERIOD); 
 
         // --- ZDJĘCIE 5: FINAŁ STOŁU (RUCH KRUPIERA) ---
         capture_snapshot("TIFF 5: Finalny stol (Ruch Krupiera)");
         
         $display("--------------------------------------------------");
         $display("Symulacja zakonczona! Powinno powstac 5 plikow TIFF.");
         $finish;
     end
 endmodule