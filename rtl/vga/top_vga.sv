/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
 *
 * Modified by: Piotr Kaczmarczyk / Eryk Rutka / Bartłomiej Raczyński
 * 2026  AGH University of Science and Technology
 * MTM UEC2
 * Description:
 * The project top module. Integrates VGA rendering, Blackjack logic,
 * Master-Slave UART communication, Context-Aware Gesture Inputs,
 * Turn Indicator, full Money/Betting synchronization, and Game Over Screen.
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
     vga_if vga_game_over(); // ADDED: Game Over VGA pipe
 
     // --- Gesture edge detection ---
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

     // --- Internal wires for FSM additions ---
     logic sig_game_over_sig;
     logic sig_exit_to_menu_sig;

     // --- Hardware contextual demultiplexer ---
     logic is_start_screen;
     logic go_to_game_sig;
     logic safe_start_cmd;
     logic safe_hit_cmd;

     assign safe_start_cmd = (gest_knock_pulse | go_to_game_sig) & is_start_screen;
     assign safe_hit_cmd   = gest_knock_pulse & ~is_start_screen;

     always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             is_start_screen <= 1'b1; 
         end else begin
             if (safe_start_cmd) begin
                 is_start_screen <= 1'b0; 
             end else if (sig_exit_to_menu_sig) begin // ADDED: Wake up menu from Game Over
                 is_start_screen <= 1'b1;
             end
         end
     end
 
     // --- Internal wires ---
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
     
     // --- Financial system (Hardware referee) ---
     
     // 1. FSM Protection (Money update pulse lasts only 1 clock cycle)
     logic update_money_prev;
     logic update_money_pulse;
     always_ff @(posedge clk or negedge rst_n) begin
         if(!rst_n) update_money_prev <= 1'b0;
         else update_money_prev <= sig_update_money_sig;
     end
     assign update_money_pulse = sig_update_money_sig && !update_money_prev;

     // 2. Copy of the points calculator from Datapath
     function automatic logic [3:0] get_points(input logic [5:0] c_val);
         logic [3:0] rank;
         rank = c_val % 13;
         if (rank == 0) return 4'd11;           
         else if (rank > 0 && rank < 10) return rank + 1; 
         else return 4'd10;                     
     endfunction

     logic [5:0] p0_score, p1_score, d_score;
     logic p0_has_ace, p1_has_ace, d_has_ace;
     logic [5:0] p0_raw, p1_raw, d_raw;

     // On-the-fly point calculation based on cards on the table
     always_comb begin
         p0_raw = '0; p0_has_ace = 1'b0;
         p1_raw = '0; p1_has_ace = 1'b0;
         d_raw = '0;  d_has_ace = 1'b0;

         for (int i = 0; i < 5; i++) begin
             if (i < dpath_p0_cnt) begin
                 p0_raw = p0_raw + get_points(dpath_p0_cards[i]);
                 if (dpath_p0_cards[i] % 13 == 0) p0_has_ace = 1'b1;
             end
             if (i < dpath_p1_cnt) begin
                 p1_raw = p1_raw + get_points(dpath_p1_cards[i]);
                 if (dpath_p1_cards[i] % 13 == 0) p1_has_ace = 1'b1;
             end
             if (i < dpath_dealer_cnt) begin
                 d_raw = d_raw + get_points(dpath_dealer_cards[i]);
                 if (dpath_dealer_cards[i] % 13 == 0) d_has_ace = 1'b1;
             end
         end

         p0_score = (p0_has_ace && p0_raw > 21) ? p0_raw - 10 : p0_raw;
         p1_score = (p1_has_ace && p1_raw > 21) ? p1_raw - 10 : p1_raw;
         d_score  = (d_has_ace  && d_raw  > 21) ? d_raw  - 10 : d_raw;
     end

     // 3. Win logic (Referee)
     logic p0_win, p0_draw;
     logic p1_win, p1_draw;

     always_comb begin
         p0_win = 1'b0; p0_draw = 1'b0;
         p1_win = 1'b0; p1_draw = 1'b0;

         if (p0_score <= 21) begin
             if (d_score > 21 || p0_score > d_score) p0_win = 1'b1;
             else if (p0_score == d_score) p0_draw = 1'b1;
         end

         if (p1_score <= 21) begin
             if (d_score > 21 || p1_score > d_score) p1_win = 1'b1;
             else if (p1_score == d_score) p1_draw = 1'b1;
         end
     end

     // 4. Wallets integration (bjack_money)
     logic [15:0] p0_balance_16, p1_balance_16;
     logic [9:0] master_p1_money_internal;
     logic [9:0] master_p2_money_internal;
     logic [9:0] slave_p2_money_rcv;

     bjack_money u_money_p0 (
         .clk(clk),
         .rst_n(rst_n),
         .update_en(update_money_pulse && sw_master), // Master manages accounts
         .win(p0_win),
         .draw_flag(p0_draw),
         .bet_amount(8'd100), // Fixed bet of $100
         .balance(p0_balance_16)
     );

     bjack_money u_money_p1 (
         .clk(clk),
         .rst_n(rst_n),
         .update_en(update_money_pulse && sw_master), 
         .win(p1_win),
         .draw_flag(p1_draw),
         .bet_amount(8'd100), // Fixed bet of $100
         .balance(p1_balance_16)
     );

     assign master_p1_money_internal = p0_balance_16[9:0];
     assign master_p2_money_internal = p1_balance_16[9:0];

     // --- Turn indicator (Overlay) and VGA mux ---
     logic [11:0] game_rgb_with_indicator;
     
     always_comb begin
         game_rgb_with_indicator = vga_game_over.rgb; // Base is now Game Over overlay

         // Hide indicator when game over screen is active
         if (!sig_game_over_sig && vga_tim.hcount >= 10 && vga_tim.hcount <= 40 && vga_tim.vcount >= 10 && vga_tim.vcount <= 40) begin
             if (sig_p0_turn_sig)          game_rgb_with_indicator = 12'hF00; 
             else if (sig_p1_turn_sig)     game_rgb_with_indicator = 12'h00F; 
             else if (sig_dealer_turn_sig) game_rgb_with_indicator = 12'h555; 
         end
     end

     assign vs = is_start_screen ? vga_menu.vsync : vga_game_over.vsync;
     assign hs = is_start_screen ? vga_menu.hsync : vga_game_over.hsync;
     assign {r,g,b} = is_start_screen ? vga_menu.rgb : game_rgb_with_indicator;
 
     // --- Instances ---
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
         .p0_cards(dpath_p0_cards), .p0_card_cnt(dpath_p0_cnt),
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
         .sig_dealer_turn(sig_dealer_turn_sig), 
         .sig_update_money(sig_update_money_sig),
         .sig_game_over(sig_game_over_sig),         // ADDED: Game Over state output
         .sig_exit_to_menu(sig_exit_to_menu_sig)    // ADDED: Wake up menu output
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
         .p1_money(master_p1_money_internal), 
         .p2_money(sw_master ? master_p2_money_internal : slave_p2_money_rcv), 
         .vga_in(vga_tim), .vga_out(vga_bg)
     );
 
     card_generator u_card_generator (
         .clk(clk), .rst_n(rst_n),
         .p0_cards(dpath_p0_cards), .p1_cards(dpath_p1_cards), .dealer_cards(dpath_dealer_cards),
         .p0_card_cnt(dpath_p0_cnt), .p1_card_cnt(dpath_p1_cnt), .dealer_card_cnt(dpath_dealer_cnt),
         .vga_in(vga_bg), .vga_out(vga_cards)
     );

     // --- ADDED: Game Over Overlay ---
     draw_game_over u_draw_game_over (
         .clk(clk), .rst_n(rst_n),
         .sig_game_over(sig_game_over_sig),
         .p0_score(p0_score), .p1_score(p1_score), .d_score(d_score), 
         .p0_win(p0_win), .p0_draw(p0_draw), 
         .p1_win(p1_win), .p1_draw(p1_draw),
         .vga_in(vga_cards),       
         .vga_out(vga_game_over)   
     );
 
 endmodule