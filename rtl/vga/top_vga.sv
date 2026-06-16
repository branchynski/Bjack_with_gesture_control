/**
 * San Jose State University
 * EE178 Lab #4
 * Author: prof. Eric Crabilla
 *
 * Modified by: Piotr Kaczmarczyk / Eryk Rutka 
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
     vga_if vga_game_over(); 
     vga_if vga_credits(); 
 
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

     // --- UI State Machine (Menu/Game/Credits) ---
     typedef enum logic [1:0] {ST_MENU, ST_GAME, ST_CREDITS} ui_state_t;
     ui_state_t ui_state;
     
     logic go_to_game_sig;
     logic go_to_credits_sig; 
     logic safe_hit_cmd;
     logic safe_start_cmd;

     always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             ui_state <= ST_MENU; 
         end else begin
             if (ui_state == ST_MENU) begin
                 if (go_to_game_sig)       ui_state <= ST_GAME;
                 else if (go_to_credits_sig) ui_state <= ST_CREDITS;
             end 
             else if (ui_state == ST_GAME) begin
                 if (sig_exit_to_menu_sig) ui_state <= ST_MENU;
             end 
             else if (ui_state == ST_CREDITS) begin
                 if (gest_swipe_pulse) ui_state <= ST_MENU; 
             end
         end
     end

     assign safe_start_cmd = go_to_game_sig & (ui_state == ST_MENU);
     assign safe_hit_cmd   = gest_knock_pulse & (ui_state == ST_GAME);
 
     logic reset_game_sig;
     assign reset_game_sig = safe_start_cmd | (gest_knock_pulse & sig_game_over_sig & (ui_state == ST_GAME));

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

     // --- P1 (UART) Edge Detectors ---
     logic slave_hit_q, slave_stand_q;
     logic p1_hit_pulse, p1_stand_pulse;

     always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             slave_hit_q   <= 1'b0;
             slave_stand_q <= 1'b0;
         end else begin
             slave_hit_q   <= slave_req_hit_sig;
             slave_stand_q <= slave_req_stand_sig;
         end
     end

     assign p1_hit_pulse   = slave_req_hit_sig & ~slave_hit_q;
     assign p1_stand_pulse = slave_req_stand_sig & ~slave_stand_q;
     
     // --- Financial system (Hardware referee) ---
     logic update_money_prev;
     logic update_money_pulse;
     always_ff @(posedge clk or negedge rst_n) begin
         if(!rst_n) update_money_prev <= 1'b0;
         else update_money_prev <= sig_update_money_sig;
     end
     assign update_money_pulse = sig_update_money_sig && !update_money_prev;

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

     logic [15:0] p0_balance_16, p1_balance_16;
     logic [9:0] master_p1_money_internal;
     logic [9:0] master_p2_money_internal;
     
     // UART received financial nodes
     logic [9:0] slave_p1_money_rcv; // NEW: Holds transmitted Master's balance
     logic [9:0] slave_p2_money_rcv;

     // RESTORED: Algorithm untamed, sw_master lock enforced
     bjack_money u_money_p0 (
         .clk(clk),
         .rst_n(rst_n),
         .update_en(update_money_pulse && sw_master), 
         .win(p0_win),
         .draw_flag(p0_draw),
         .bet_amount(8'd1), 
         .balance(p0_balance_16)
     );

     bjack_money u_money_p1 (
         .clk(clk),
         .rst_n(rst_n),
         .update_en(update_money_pulse && sw_master), 
         .win(p1_win),
         .draw_flag(p1_draw),
         .bet_amount(8'd1), 
         .balance(p1_balance_16)
     );

     assign master_p1_money_internal = p0_balance_16[9:0];
     assign master_p2_money_internal = p1_balance_16[9:0];

     // --- Combinational fallbacks for initial startup states ($10000 -> internal 100) ---
     logic [9:0] active_p1_money;
     assign active_p1_money = sw_master ? master_p1_money_internal : 
                              ((slave_p1_money_rcv == 10'd0) ? 10'd100 : slave_p1_money_rcv);

     logic [9:0] active_p2_money;
     assign active_p2_money = sw_master ? master_p2_money_internal : 
                              ((slave_p2_money_rcv == 10'd0) ? 10'd100 : slave_p2_money_rcv);

     // --- Dealer reveal logic ---
     logic reveal_dealer_sig;
     assign reveal_dealer_sig = sig_dealer_turn_sig | sig_update_money_sig | sig_game_over_sig;

     // --- Turn indicator ---
     logic [11:0] game_rgb_with_indicator;
     always_comb begin
         game_rgb_with_indicator = vga_game_over.rgb; 
         if (!sig_game_over_sig && vga_tim.hcount >= 10 && vga_tim.hcount <= 40 && vga_tim.vcount >= 10 && vga_tim.vcount <= 40) begin
             if (sig_p0_turn_sig)          game_rgb_with_indicator = 12'hF00; 
             else if (sig_p1_turn_sig)     game_rgb_with_indicator = 12'h00F; 
             else if (sig_dealer_turn_sig) game_rgb_with_indicator = 12'h555; 
         end
     end
 
     // --- Instances ---
     top_menu u_top_menu (
         .clk(clk), .rst_n(rst_n), .vga_in_main(vga_tim), .vga_out_main(vga_menu),
         .current_gesture(current_gesture), .is_start_screen(ui_state == ST_MENU),
         .go_to_game(go_to_game_sig), .go_to_credits(go_to_credits_sig) 
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
         .btn_start_master(reset_game_sig), 
         .btn_hit_slave(safe_hit_cmd), .btn_stand_slave(gest_swipe_pulse),
         .slave_req_hit(slave_req_hit_sig), .slave_req_stand(slave_req_stand_sig),
         .uart_card_valid(uart_c_valid_sig), .uart_card_val(uart_c_val_sig),
         .uart_card_dst(uart_c_dst_sig), .uart_new_game(uart_new_game_sig),
         
         // NEW UART FINANCIAL PORTS: Wire these inside uart_protocol_ctrl.sv
         .master_p1_money(master_p1_money_internal),     
         .slave_p1_money_out(slave_p1_money_rcv),       
         
         .master_p2_money(master_p2_money_internal), 
         .slave_p2_money_out(slave_p2_money_rcv)
     );
 
     card_drawing u_card_drawing (
         .clk(clk), .rst_n(rst_n), .card_req(card_req_sig),
         .card_value(card_val_sig), .card_valid(card_valid_sig)
     );
 
     bjack_fsm u_bjack_fsm (
         .clk(clk), .rst_n(rst_n),
         .btn_start(reset_game_sig), 
         .btn_p0_hit(safe_hit_cmd), .btn_p0_stand(gest_swipe_pulse & (ui_state == ST_GAME)),
         .btn_p1_hit(p1_hit_pulse), .btn_p1_stand(p1_stand_pulse), 
         .p0_bust(p0_bust_sig), .p1_bust(p1_bust_sig),
         .deal_done(deal_done_sig), .dealer_done(dealer_done_sig),
         .busy(busy_sig), .sig_deal_enable(sig_deal_enable_sig),
         .sig_p0_turn(sig_p0_turn_sig), .sig_p1_turn(sig_p1_turn_sig),
         .sig_dealer_turn(sig_dealer_turn_sig), 
         .sig_update_money(sig_update_money_sig),
         .sig_game_over(sig_game_over_sig),         
         .sig_exit_to_menu(sig_exit_to_menu_sig)    
     );
 
     bjack_datapath u_bjack_datapath (
         .clk(clk), .rst_n(rst_n),
         .sig_deal_enable(sig_deal_enable_sig), .sig_p0_turn(sig_p0_turn_sig),
         .sig_p1_turn(sig_p1_turn_sig), .sig_dealer_turn(sig_dealer_turn_sig),
         .btn_p0_hit(safe_hit_cmd), .btn_p1_hit(p1_hit_pulse),
         .btn_start(reset_game_sig), 
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
         .p1_money(active_p1_money), // FIXED: Routes dynamically synced Master cash
         .p2_money(active_p2_money), 
         .vga_in(vga_tim), .vga_out(vga_bg)
     );
 
     card_generator u_card_generator (
         .clk(clk), .rst_n(rst_n),
         .reveal_dealer(reveal_dealer_sig), 
         .p0_cards(dpath_p0_cards), .p1_cards(dpath_p1_cards), .dealer_cards(dpath_dealer_cards),
         .p0_card_cnt(dpath_p0_cnt), .p1_card_cnt(dpath_p1_cnt), .dealer_card_cnt(dpath_dealer_cnt),
         .vga_in(vga_bg), .vga_out(vga_cards)
     );

     draw_game_over u_draw_game_over (
         .clk(clk), .rst_n(rst_n),
         .sig_game_over(sig_game_over_sig),
         .p0_score(p0_score), .p1_score(p1_score), .d_score(d_score), 
         .p0_win(p0_win), .p0_draw(p0_draw), 
         .p1_win(p1_win), .p1_draw(p1_draw),
         .vga_in(vga_cards),       
         .vga_out(vga_game_over)   
     );

     draw_credits u_draw_credits (
         .clk(clk), .rst_n(rst_n),
         .sig_show_credits(ui_state == ST_CREDITS),
         .vga_in(vga_menu), 
         .vga_out(vga_credits) 
     );

     // --- Final MUX ---
     assign vs = (ui_state == ST_GAME) ? vga_game_over.vsync : vga_credits.vsync;
     assign hs = (ui_state == ST_GAME) ? vga_game_over.hsync : vga_credits.hsync;
     assign {r,g,b} = (ui_state == ST_GAME) ? game_rgb_with_indicator : vga_credits.rgb;
 
 endmodule