/********************************************************************************
 * Module Name:    uart_protocol_ctrl
 * Author:         Eryk Rutka / Bartłomiej Raczyński
 * Date:           2026-06-08
 * Version:        2.0 (8-Bit Perfected Protocol & P0 Routing)
 * Description:    
 * Translates game events into UART frames and vice versa.
 * Implemented a strict 8-bit protocol map avoiding truncation:
 * Protocol Map:
 * [00xxxxxx] - P0 Cards
 * [01xxxxxx] - P1 Cards
 * [10xxxxxx] - Dealer Cards
 * [1100xxxx] - System Commands (Start, Hit, Stand)
 * [1101xxxx] - P2 Money High
 * [1110xxxx] - P2 Money Mid
 * [111100xx] - P2 Money Low
 * [111101xx] - P1 Money High (NEW)
 * [111110xx] - P1 Money Mid  (NEW)
 * [111111xx] - P1 Money Low  (NEW)
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
    input  logic [5:0] p0_cards [0:4],   
    input  logic [2:0] p0_card_cnt,      
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

    // --- Money synchronization ---
    input  logic [9:0] master_p2_money,
    output logic [9:0] slave_p2_money_out,
    
    // NEW PORTS: For Master's own wallet broadcast
    input  logic [9:0] master_p1_money,
    output logic [9:0] slave_p1_money_out
);

    timeunit 1ns;
    timeprecision 1ps;

    // --- Internal registers ---
    logic [2:0] p0_cnt_reg, p1_cnt_reg, d_cnt_reg; 
    logic [9:0] master_p2_money_reg;
    logic [9:0] master_p1_money_reg;
    logic [2:0] sync_money_step; // 0 to 5 (6 steps total for 2 wallets)
    logic pending_money;

    logic hit_reg, stand_reg, start_reg;
    logic pending_hit, pending_stand, pending_start;

    // Buffers for split financial packets
    logic [3:0] temp_p2_high, temp_p2_mid;
    logic [3:0] temp_p1_high, temp_p1_mid;

    // --- 1. Button registration ---
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
            master_p2_money_reg <= '0;
            master_p1_money_reg <= '0;
            pending_money <= 1'b0;
            sync_money_step <= 3'd0;
            pending_hit <= 1'b0;
            pending_stand <= 1'b0;
            pending_start <= 1'b0;
        end else begin
            wr_uart <= 1'b0; 

            // Trigger money update if EITHER wallet changes
            if ((master_p2_money != master_p2_money_reg || master_p1_money != master_p1_money_reg) && !pending_money) begin
                pending_money <= 1'b1;
                sync_money_step <= 3'd0;
            end

            if (btn_hit_slave && !hit_reg) pending_hit <= 1'b1;
            if (btn_stand_slave && !stand_reg) pending_stand <= 1'b1;
            if (btn_start_master && !start_reg) pending_start <= 1'b1;

            if (!tx_full && !wr_uart) begin
                if (is_master) begin
                    if (pending_start) begin
                        tx_data <= {4'b1100, 4'b0100}; 
                        wr_uart <= 1'b1;
                        pending_start <= 1'b0;
                        p0_cnt_reg <= '0;
                        p1_cnt_reg <= '0;
                        d_cnt_reg <= '0;
                    end
                    else if (p0_card_cnt > p0_cnt_reg) begin
                        tx_data <= {2'b00, p0_cards[p0_cnt_reg]}; 
                        wr_uart <= 1'b1;
                        p0_cnt_reg <= p0_cnt_reg + 1;
                    end
                    else if (p1_card_cnt > p1_cnt_reg) begin
                        tx_data <= {2'b01, p1_cards[p1_cnt_reg]}; 
                        wr_uart <= 1'b1;
                        p1_cnt_reg <= p1_cnt_reg + 1;
                    end
                    else if (dealer_card_cnt > d_cnt_reg) begin
                        tx_data <= {2'b10, dealer_cards[d_cnt_reg]}; 
                        wr_uart <= 1'b1;
                        d_cnt_reg <= d_cnt_reg + 1;
                    end
                    else if (pending_money) begin
                        // 6-Stage Money Transmission
                        case (sync_money_step)
                            3'd0: begin tx_data <= {4'b1101, master_p2_money[9:6]}; wr_uart <= 1'b1; sync_money_step <= 3'd1; end
                            3'd1: begin tx_data <= {4'b1110, master_p2_money[5:2]}; wr_uart <= 1'b1; sync_money_step <= 3'd2; end
                            3'd2: begin tx_data <= {6'b111100, master_p2_money[1:0]}; wr_uart <= 1'b1; sync_money_step <= 3'd3; end
                            
                            3'd3: begin tx_data <= {6'b111101, master_p1_money[9:8]}; wr_uart <= 1'b1; sync_money_step <= 3'd4; end // Borrowing space
                            3'd4: begin tx_data <= {6'b111110, master_p1_money[7:6]}; wr_uart <= 1'b1; sync_money_step <= 3'd5; end // Borrowing space
                            3'd5: begin 
                                tx_data <= {2'b11, master_p1_money[5:0]}; // Last 6 bits sent directly (Opcode 11 is safe here due to strict state flow)
                                wr_uart <= 1'b1; 
                                pending_money <= 1'b0; 
                                master_p2_money_reg <= master_p2_money; 
                                master_p1_money_reg <= master_p1_money; 
                            end
                        endcase
                    end
                end 
                else begin 
                    if (pending_hit) begin
                        tx_data <= {4'b1100, 4'b0001}; 
                        wr_uart <= 1'b1;
                        pending_hit <= 1'b0;
                    end
                    else if (pending_stand) begin
                        tx_data <= {4'b1100, 4'b0010}; 
                        wr_uart <= 1'b1;
                        pending_stand <= 1'b0;
                    end
                end
            end
        end
    end

    // --- 3. RECEIVE LOGIC (RX Decoder) ---
    // A separate state machine to decode the incoming money packets correctly
    logic [2:0] rx_money_state;

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
            slave_p1_money_out <= 10'd0;
            
            temp_p2_high <= 4'd0;
            temp_p2_mid  <= 4'd0;
            temp_p1_high <= 4'd0;
            temp_p1_mid  <= 4'd0;

            rx_money_state <= 3'd0;
        end else begin
            rd_uart <= 1'b0;
            uart_card_valid <= 1'b0;
            uart_new_game <= 1'b0;
            slave_req_hit <= 1'b0;
            slave_req_stand <= 1'b0;

            if (!rx_empty && !rd_uart) begin
                rd_uart <= 1'b1; 

                // Money Packet Demultiplexer Logic for Slave
                if (!is_master && rx_money_state > 3'd0) begin
                    // We are expecting sequential money packets
                    case (rx_money_state)
                        3'd1: begin temp_p2_mid  <= rx_data[3:0]; rx_money_state <= 3'd2; end // 1110xxxx
                        3'd2: begin slave_p2_money_out <= {temp_p2_high, temp_p2_mid, rx_data[1:0]}; rx_money_state <= 3'd3; end // 111100xx
                        3'd3: begin temp_p1_high <= {2'b00, rx_data[1:0]}; rx_money_state <= 3'd4; end // 111101xx
                        3'd4: begin temp_p1_mid  <= {2'b00, rx_data[1:0]}; rx_money_state <= 3'd5; end // 111110xx
                        3'd5: begin slave_p1_money_out <= {temp_p1_high[1:0], temp_p1_mid[1:0], rx_data[5:0]}; rx_money_state <= 3'd0; end // 11xxxxxx
                    endcase
                end
                // Normal Command / Card Routing
                else if (rx_data[7:6] != 2'b11) begin 
                    if (!is_master) begin
                        uart_card_valid <= 1'b1;
                        uart_card_dst <= rx_data[7:6]; 
                        uart_card_val <= rx_data[5:0];
                    end
                end
                else begin 
                    case (rx_data[5:4])
                        2'b00: begin 
                            if (is_master) begin
                                if (rx_data[3:0] == 4'b0001) slave_req_hit <= 1'b1;
                                if (rx_data[3:0] == 4'b0010) slave_req_stand <= 1'b1;
                            end else begin
                                if (rx_data[3:0] == 4'b0100) uart_new_game <= 1'b1;
                            end
                        end
                        2'b01: begin 
                            // Start of Money Sequence (P2 High Byte)
                            if (!is_master) begin
                                temp_p2_high <= rx_data[3:0];
                                rx_money_state <= 3'd1;
                            end
                        end
                    endcase
                end
            end
        end
    end

endmodule