/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
 *
 * Modified by: Piotr Kaczmarczyk / Eryk Rutka / Bartłomiej Raczyński
 * 2026  AGH University of Science and Technology
 * MTM UEC2
 * Description:
 * The project top module. Integrates VGA rendering with Blackjack logic,
 * Master-Slave UART communication, Start Menu with gesture support,
 * Hardware Gesture Demultiplexer, and Turn Indicator.
 */

 import vga_pkg::*;
 import ai_type_pkg::*;
 
 module top_vga (
     input  logic clk,
     input  logic rst_n,
     
     input  gesture_out current_gesture,
 
     input  logic sw_master,     
     input  logic uart_rx_pin,   
     output logic uart_tx_pin,   
 
     output logic vs,
     output logic hs,
     output logic [3:0] r,
     output logic [3:0] g,
     output logic [3:0] b
 );
 
     timeunit 1ns;
     timeprecision 1ps;
 
     vga_if vga_tim();
     vga_if vga_bg();
     vga_if vga_cards();
     vga_if vga_menu();
 
     // ==========================================
     // DETEKCJA ZBOCZA GESTÓW 
     // ==========================================
     gesture_out prev_gesture;
     logic gest_knock_pulse;
     logic gest_swipe_pulse;

     always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             prev_gesture <= NOTHING; 
         end else begin
             prev_gesture <= current_gesture;
         end
     end

     
     assign gest_knock_pulse = (current_gesture == KNOCK)       && (prev_gesture != KNOCK);
     assign gest_swipe_pulse = (current_gesture == SWIPE_RIGHT) && (prev_gesture != SWIPE_RIGHT);

     // ==========================================
     // SPRZĘTOWY DEMULTIPLEKSER KONTEKSTOWY
     // ==========================================
     logic is_start_screen;
     logic go_to_game_sig;
     logic safe_start_cmd;
     logic safe_hit_cmd;

     // Izolacja: KNOCK działa jako START tylko w Menu. KNOCK w grze działa jako HIT.
     assign safe_start_cmd = (gest_knock_pulse | go_to_game_sig) & is_start_screen;
     assign safe_hit_cmd   = gest_knock_pulse & ~is_start_screen;

     always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             is_start_screen <= 1'b1; 
         end else begin
             if (safe_start_cmd) begin
                 is_start_screen <= 1'b0; 
             end
         end
     end
 
     // --- Kable wewnętrzne ---
     logic p0_bust_sig, p1_bust_sig;
     logic deal_done_sig, dealer_done_sig;
     logic sig_deal_enable_sig;
     logic sig_p0_turn_sig, sig_p1_turn_sig, sig_dealer_turn_sig;
     logic sig_update_money_sig; 
     logic busy_sig;
 
     logic [5:0] card_val_sig;
     logic card_valid_sig;
     logic card_req_sig;
 
     logic [5:0] dpath_p0_cards [0:4];
     logic [5:0] dpath_p1_cards [0:4];
     logic [5:0] dpath_dealer_cards [0:4];
     logic [2:0] dpath_p0_cnt;
     logic [2:0] dpath_p1_cnt;
     logic [2:0] dpath_dealer_cnt;
 
     logic uart_rst;
     assign uart_rst = ~rst_n; 
 
     logic uart_tx_full, uart_rx_empty;
     logic [7:0] uart_rx_data, uart_tx_data;
     logic uart_wr, uart_rd;
 
     logic slave_req_hit_sig, slave_req_stand_sig;
     logic uart_c_valid_sig;
     logic [5:0] uart_c_val_sig;
     logic [1:0] uart_c_dst_sig;
     logic uart_new_game_sig;
     
     logic [9:0] master_p2_money_internal = 10'd30; 
     logic [9:0] slave_p2_money_rcv;
 
     // ==========================================
     // WSKAŹNIK TURY (OVERLAY) I MUX VGA
     // ==========================================
     logic [11:0] game_rgb_with_indicator;
     
     always_comb begin
         game_rgb_with_indicator = vga_cards.rgb; 

         // Rysujemy kwadrat 30x30 pikseli (z marginesem 10px od lewej i góry)
         if (vga_tim.hcount >= 10 && vga_tim.hcount <= 40 && vga_tim.vcount >= 10 && vga_tim.vcount <= 40) begin
             if (sig_p0_turn_sig)          game_rgb_with_indicator = 12'hF00; // Czerwony - Master
             else if (sig_p1_turn_sig)     game_rgb_with_indicator = 12'h00F; // Niebieski - Slave
             else if (sig_dealer_turn_sig) game_rgb_with_indicator = 12'h555; // Szary - Krupier
         end
     end

     assign vs = is_start_screen ? vga_menu.vsync : vga_cards.vsync;
     assign hs = is_start_screen ? vga_menu.hsync : vga_cards.hsync;
     assign {r,g,b} = is_start_screen ? vga_menu.rgb : game_rgb_with_indicator;
 
     // ==========================================
     // INSTANCJE (Wpięto bezpieczne sygnały odizolowane kontekstowo)
     // ==========================================
     top_menu u_top_menu (
         .clk(clk), .rst_n(rst_n), .vga_in_main(vga_tim), .vga_out_main(vga_menu),
         .current_gesture(current_gesture), .is_start_screen(is_start_screen),
         .go_to_game(go_to_game_sig), .go_to_credits() 
     );
 
     uart #(
        .DVSR(35),
        .DVSR_BIT(6)
        ) u_uart (
         .clk(clk), .reset(uart_rst), .rd_uart(uart_rd), .wr_uart(uart_wr),
         .rx(uart_rx_pin), .w_data(uart_tx_data), .tx_full(uart_tx_full),
         .rx_empty(uart_rx_empty), .tx(uart_tx_pin), .r_data(uart_rx_data)
     );
 
     uart_protocol_ctrl u_uart_protocol_ctrl (
         .clk(clk), .rst_n(rst_n), .is_master(sw_master),
         .tx_full(uart_tx_full), .rx_empty(uart_rx_empty), .rx_data(uart_rx_data),
         .tx_data(uart_tx_data), .wr_uart(uart_wr), .rd_uart(uart_rd),
         .p1_cards(dpath_p1_cards), .p1_card_cnt(dpath_p1_cnt),
         .dealer_cards(dpath_dealer_cards), .dealer_card_cnt(dpath_dealer_cnt),
         .btn_start_master(safe_start_cmd), 
         .btn_hit_slave(safe_hit_cmd), .btn_stand_slave(gest_swipe_pulse),
         .slave_req_hit(slave_req_hit_sig), .slave_req_stand(slave_req_stand_sig),
         .uart_card_valid(uart_c_valid_sig), .uart_card_val(uart_c_val_sig),
         .uart_card_dst(uart_c_dst_sig), .uart_new_game(uart_new_game_sig),
         .master_p2_money(master_p2_money_internal), .slave_p2_money_out(slave_p2_money_rcv)
     );
 
     card_drawing u_card_drawing (
         .clk(clk), .rst_n(rst_n), .card_req(card_req_sig),
         .card_value(card_val_sig), .card_valid(card_valid_sig)
     );
 
     bjack_fsm u_bjack_fsm (
         .clk(clk), .rst_n(rst_n),
         .btn_start(safe_start_cmd), 
         .btn_p0_hit(safe_hit_cmd), .btn_p0_stand(gest_swipe_pulse),
         .btn_p1_hit(slave_req_hit_sig), .btn_p1_stand(slave_req_stand_sig),
         .p0_bust(p0_bust_sig), .p1_bust(p1_bust_sig),
         .deal_done(deal_done_sig), .dealer_done(dealer_done_sig),
         .busy(busy_sig), .sig_deal_enable(sig_deal_enable_sig),
         .sig_p0_turn(sig_p0_turn_sig), .sig_p1_turn(sig_p1_turn_sig),
         .sig_dealer_turn(sig_dealer_turn_sig), .sig_update_money(sig_update_money_sig)
     );
 
     bjack_datapath u_bjack_datapath (
         .clk(clk), .rst_n(rst_n),
         .sig_deal_enable(sig_deal_enable_sig), .sig_p0_turn(sig_p0_turn_sig),
         .sig_p1_turn(sig_p1_turn_sig), .sig_dealer_turn(sig_dealer_turn_sig),
         .btn_p0_hit(safe_hit_cmd), .btn_p1_hit(slave_req_hit_sig),
         .btn_start(safe_start_cmd), 
         .p0_bust(p0_bust_sig), .p1_bust(p1_bust_sig),
         .deal_done(deal_done_sig), .dealer_done(dealer_done_sig),
         .card_value(card_val_sig), .card_valid(card_valid_sig), .card_req(card_req_sig),
         .p0_cards(dpath_p0_cards), .p1_cards(dpath_p1_cards), .dealer_cards(dpath_dealer_cards),
         .p0_card_cnt(dpath_p0_cnt), .p1_card_cnt(dpath_p1_cnt), .dealer_card_cnt(dpath_dealer_cnt),
         .is_master(sw_master), .uart_card_valid(uart_c_valid_sig),         
         .uart_card_val(uart_c_val_sig), .uart_card_dst(uart_c_dst_sig),           
         .uart_new_game(uart_new_game_sig)           
     );
 
     vga_timing u_vga_timing (.clk(clk), .rst_n(rst_n), .vga_out(vga_tim));
     
     draw_bg u_draw_bg (
         .clk(clk), .rst_n(rst_n),
         .p1_money(10'd25), .p2_money(sw_master ? master_p2_money_internal : slave_p2_money_rcv), 
         .vga_in(vga_tim), .vga_out(vga_bg)
     );
 
     card_generator u_card_generator (
         .clk(clk), .rst_n(rst_n),
         .p0_cards(dpath_p0_cards), .p1_cards(dpath_p1_cards), .dealer_cards(dpath_dealer_cards),
         .p0_card_cnt(dpath_p0_cnt), .p1_card_cnt(dpath_p1_cnt), .dealer_card_cnt(dpath_dealer_cnt),
         .vga_in(vga_bg), .vga_out(vga_cards)
     );
 
 endmodule