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
                        p1_cnt_reg <= p1_cnt_reg + 1;
                    end
                    else if (dealer_card_cnt > d_cnt_reg) begin
                        // Sending Dealer card (Bits 7:6 = 10)
                        tx_data <= {2'b10, dealer_cards[d_cnt_reg]}; 
                        wr_uart <= 1'b1;
                        d_cnt_reg <= d_cnt_reg + 1;
                    end
                    else if (pending_money) begin
                        // Safe 10-bit money transmission in 3 stages
                        if (sync_money_step == 2'd0) begin
                            tx_data <= {4'b1101, master_p2_money[9:6]}; // Bits 9-6
                            wr_uart <= 1'b1;
                            sync_money_step <= 2'd1;
                        end else if (sync_money_step == 2'd1) begin
                            tx_data <= {4'b1110, master_p2_money[5:2]}; // Bits 5-2
                            wr_uart <= 1'b1;
                            sync_money_step <= 2'd2;
                        end else begin
                            tx_data <= {6'b111100, master_p2_money[1:0]}; // Bits 1-0
                            wr_uart <= 1'b1;
                            pending_money <= 1'b0;
                            master_money_reg <= master_p2_money; 
                        end
                    end
                end 
                else begin 
                    // Transmission logic for SLAVE
                    if (pending_hit) begin
                        tx_data <= {4'b1100, 4'b0001}; // Slave Action: Hit
                        wr_uart <= 1'b1;
                        pending_hit <= 1'b0;
                    end
                    else if (pending_stand) begin
                        tx_data <= {4'b1100, 4'b0010}; // Slave Action: Stand
                        wr_uart <= 1'b1;
                        pending_stand <= 1'b0;
                    end
                end
            end
        end
    end

    // --- 3. RECEIVE LOGIC (RX Decoder) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_uart <= 1'b0;
            uart_card_valid <= 1'b0;
            uart_card_val <= 6'd0;
            uart_card_dst <= 2'd0;
            uart_new_game <= 1'b0;
            slave_req_hit <= 1'b0;
            slave_req_stand <= 1'b0;
            slave_p2_money_out <= 10'd0;
            temp_money_high <= 4'd0;
            temp_money_mid <= 4'd0;
        end else begin
            rd_uart <= 1'b0;
            uart_card_valid <= 1'b0;
            uart_new_game <= 1'b0;
            slave_req_hit <= 1'b0;
            slave_req_stand <= 1'b0;

            if (!rx_empty && !rd_uart) begin
                rd_uart <= 1'b1; 

                if (rx_data[7:6] != 2'b11) begin 
                    // --- CARD RECEIVED --- (Unpacked by Slave only)
                    if (!is_master) begin
                        uart_card_valid <= 1'b1;
                        uart_card_dst <= rx_data[7:6]; // Mapping matches Datapath (0=P0, 1=P1, 2=Dlr)
                        uart_card_val <= rx_data[5:0];
                    end
                end
                else begin 
                    // --- COMMAND RECEIVED ---
                    case (rx_data[5:4])
                        2'b00: begin // PLAYER OR SYSTEM ACTION
                            if (is_master) begin
                                if (rx_data[3:0] == 4'b0001) slave_req_hit <= 1'b1;
                                if (rx_data[3:0] == 4'b0010) slave_req_stand <= 1'b1;
                            end else begin
                                if (rx_data[3:0] == 4'b0100) uart_new_game <= 1'b1;
                            end
                        end
                        2'b01: begin // MONEY HIGH BYTE
                            if (!is_master) temp_money_high <= rx_data[3:0];
                        end
                        2'b10: begin // MONEY MID BYTE
                            if (!is_master) temp_money_mid <= rx_data[3:0];
                        end
                        2'b11: begin // MONEY LOW BYTE (Merges the whole packet to output)
                            if (!is_master) slave_p2_money_out <= {temp_money_high, temp_money_mid, rx_data[1:0]};
                        end
                    endcase
                end
            end
        end
    end

endmodule