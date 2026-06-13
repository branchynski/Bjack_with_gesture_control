/********************************************************************************
 * Module Name:    uart_protocol_ctrl
 * Author:         Eryk Rutka / Bartłomiej Raczyński
 * Date:           2026-06-08
 * Version:        2.0 (8-Bit Perfected Protocol & P0 Routing)
 * Description:    
 * Translates game events into UART frames and vice versa.
 * Implemented a strict 8-bit protocol map avoiding truncation:
 * [00xxxxxx] - P0 Cards
 * [01xxxxxx] - P1 Cards
 * [10xxxxxx] - Dealer Cards
 * [11xxxxxx] - System Commands & 10-bit Money Sync
 ********************************************************************************/

 module uart_protocol_ctrl (
    input  logic clk,
    input  logic rst_n,
    input  logic is_master,

    // --- UART module connections ---
    input  logic tx_full,
    input  logic rx_empty,
    input  logic [7:0] rx_data,
    output logic [7:0] tx_data,
    output logic wr_uart,
    output logic rd_uart,

    // --- Datapath snooping inputs (Master TX only) ---
    input  logic [5:0] p1_cards [0:4],
    input  logic [2:0] p1_card_cnt,
    input  logic [5:0] p0_cards [0:4],   // ADDED: P0 cards snoop
    input  logic [2:0] p0_card_cnt,      // ADDED: P0 cards counter
    input  logic [5:0] dealer_cards [0:4],
    input  logic [2:0] dealer_card_cnt,
    input  logic btn_start_master, 

    // --- Slave button inputs (Slave TX only) ---
    input  logic btn_hit_slave,
    input  logic btn_stand_slave,

    // --- Master FSM outputs (RX from Slave) ---
    output logic slave_req_hit,
    output logic slave_req_stand,

    // --- Slave Datapath outputs (RX from Master) ---
    output logic uart_card_valid,
    output logic [5:0] uart_card_val,
    output logic [1:0] uart_card_dst, 
    output logic uart_new_game,

    // --- Money synchronization (Master -> Slave) ---
    input  logic [9:0] master_p2_money,
    output logic [9:0] slave_p2_money_out
);

    timeunit 1ns;
    timeprecision 1ps;

    // --- Internal registers for edge detection and state tracking ---
    logic [2:0] p0_cnt_reg, p1_cnt_reg, d_cnt_reg; // ADDED: State register for P0
    logic [9:0] master_money_reg;
    logic [1:0] sync_money_step; // 0, 1, 2 (Split into 3 safe packets)
    logic pending_money;

    logic hit_reg, stand_reg, start_reg;
    logic pending_hit, pending_stand, pending_start;

    // Buffers for split financial packets
    logic [3:0] temp_money_high;
    logic [3:0] temp_money_mid;

    // --- 1. Button registration for click detection ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hit_reg <= 1'b0;
            stand_reg <= 1'b0;
            start_reg <= 1'b0;
        end else begin
            hit_reg <= btn_hit_slave;
            stand_reg <= btn_stand_slave;
            start_reg <= btn_start_master;
        end
    end

    // --- 2. TRANSMIT LOGIC (TX Arbiter) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_uart <= 1'b0;
            tx_data <= 8'd0;
            p0_cnt_reg <= '0;
            p1_cnt_reg <= '0;
            d_cnt_reg <= '0;
            master_money_reg <= '0;
            pending_money <= 1'b0;
            sync_money_step <= 2'd0;
            pending_hit <= 1'b0;
            pending_stand <= 1'b0;
            pending_start <= 1'b0;
        end else begin
            wr_uart <= 1'b0; 

            if (master_p2_money != master_money_reg && !pending_money) begin
                pending_money <= 1'b1;
                sync_money_step <= 2'd0;
            end
            if (btn_hit_slave && !hit_reg) pending_hit <= 1'b1;
            if (btn_stand_slave && !stand_reg) pending_stand <= 1'b1;
            if (btn_start_master && !start_reg) pending_start <= 1'b1;

            // --- Pushing to UART queue (if space available) ---
            if (!tx_full && !wr_uart) begin
                
                if (is_master) begin
                    // Master transmission priority hierarchy
                    if (pending_start) begin
                        tx_data <= {4'b1100, 4'b0100}; // Opcode New Game
                        wr_uart <= 1'b1;
                        pending_start <= 1'b0;
                        p0_cnt_reg <= '0;
                        p1_cnt_reg <= '0;
                        d_cnt_reg <= '0;
                    end
                    else if (p0_card_cnt > p0_cnt_reg) begin
                        // Sending P0 card (Bits 7:6 = 00)
                        tx_data <= {2'b00, p0_cards[p0_cnt_reg]}; 
                        wr_uart <= 1'b1;
                        p0_cnt_reg <= p0_cnt_reg + 1;
                    end
                    else if (p1_card_cnt > p1_cnt_reg) begin
                        // Sending P1 card (Bits 7:6 = 01)
                        tx_data <= {2'b01, p1_cards[p1_cnt_reg]}; 
                        wr_uart <= 1'b1;
                        p1_cnt_reg <=