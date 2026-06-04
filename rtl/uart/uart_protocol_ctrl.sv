/********************************************************************************
 * Module Name:    uart_protocol_ctrl
 * Author:         Eryk Rutka
 * Date:           2026-06-04
 * Version:        1.0 (Master-Slave Bridge)
 * Description:    
 * Translates game events into UART frames and vice versa.
 * Implements a dynamic frame format (Bit 7 = 1 for Cards, Bit 7 = 0 for Cmds).
 * Intrinsically queues multiple cards by snooping Datapath counters.
 ********************************************************************************/

 module uart_protocol_ctrl (
    input  logic clk,
    input  logic rst_n,
    input  logic is_master,

    // --- Złącza do modułu UART ---
    input  logic tx_full,
    input  logic rx_empty,
    input  logic [7:0] rx_data,
    output logic [7:0] tx_data,
    output logic wr_uart,
    output logic rd_uart,

    // --- Wejścia nasłuchujące Datapath (Tylko Master nadaje) ---
    input  logic [5:0] p1_cards [0:4],
    input  logic [2:0] p1_card_cnt,
    input  logic [5:0] dealer_cards [0:4],
    input  logic [2:0] dealer_card_cnt,
    input  logic btn_start_master, 

    // --- Wejścia przycisków od Slave'a (Tylko Slave nadaje) ---
    input  logic btn_hit_slave,
    input  logic btn_stand_slave,

    // --- Wyjścia dla FSM Mastera (Odbiór od Slave'a) ---
    output logic slave_req_hit,
    output logic slave_req_stand,

    // --- Wyjścia dla Datapathu Slave'a (Odbiór od Mastera) ---
    output logic uart_card_valid,
    output logic [5:0] uart_card_val,
    output logic [1:0] uart_card_dst, 
    output logic uart_new_game,

    // --- Synchronizacja Pieniędzy (Master -> Slave) ---
    input  logic [9:0] master_p2_money,
    output logic [9:0] slave_p2_money_out
);

    timeunit 1ns;
    timeprecision 1ps;

    // --- Wewnętrzne rejestry do detekcji zboczy i śledzenia stanu ---
    logic [2:0] p1_cnt_reg, d_cnt_reg;
    logic [9:0] master_money_reg;
    logic sync_money_step; // 0 = high byte, 1 = low byte
    logic pending_money;

    logic hit_reg, stand_reg, start_reg;
    logic pending_hit, pending_stand, pending_start;

    logic [4:0] temp_money_high;

    // --- 1. Rejestrowanie przycisków w celu detekcji kliknięcia ---
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

    // --- 2. LOGIKA NADAWANIA (TX Arbiter) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_uart <= 1'b0;
            tx_data <= 8'd0;
            p1_cnt_reg <= '0;
            d_cnt_reg <= '0;
            master_money_reg <= '0;
            pending_money <= 1'b0;
            sync_money_step <= 1'b0;
            pending_hit <= 1'b0;
            pending_stand <= 1'b0;
            pending_start <= 1'b0;
        end else begin
            wr_uart <= 1'b0; // Domyślnie gasimy impuls zapisu

            // --- Podbijanie flag oczekujących zdarzeń ---
            if (master_p2_money != master_money_reg && !pending_money) begin
                pending_money <= 1'b1;
                sync_money_step <= 1'b0;
            end
            if (btn_hit_slave && !hit_reg) pending_hit <= 1'b1;
            if (btn_stand_slave && !stand_reg) pending_stand <= 1'b1;
            if (btn_start_master && !start_reg) pending_start <= 1'b1;

            // --- Wrzucanie do kolejki UART (jeśli jest miejsce) ---
            if (!tx_full && !wr_uart) begin
                
                if (is_master) begin
                    // Hierarchia ważności (Najpierw reset, potem karty, potem kasa)
                    if (pending_start) begin
                        tx_data <= {1'b0, 3'b100, 4'b0000}; // Opcode 4 (New Game)
                        wr_uart <= 1'b1;
                        pending_start <= 1'b0;
                        // Czyścimy liczniki przy resecie
                        p1_cnt_reg <= '0;
                        d_cnt_reg <= '0;
                    end
                    else if (p1_card_cnt > p1_cnt_reg) begin
                        tx_data <= {1'b1, 1'b1, p1_cards[p1_cnt_reg]}; // Bit 7=1, Bit 6=1 (P1)
                        wr_uart <= 1'b1;
                        p1_cnt_reg <= p1_cnt_reg + 1;
                    end
                    else if (dealer_card_cnt > d_cnt_reg) begin
                        tx_data <= {1'b1, 1'b0, dealer_cards[d_cnt_reg]}; // Bit 7=1, Bit 6=0 (Dealer)
                        wr_uart <= 1'b1;
                        d_cnt_reg <= d_cnt_reg + 1;
                    end
                    else if (pending_money) begin
                        if (sync_money_step == 1'b0) begin
                            tx_data <= {1'b0, 3'b010, master_p2_money[9:5]}; // Opcode 2 (High byte)
                            wr_uart <= 1'b1;
                            sync_money_step <= 1'b1;
                        end else begin
                            tx_data <= {1'b0, 3'b011, master_p2_money[4:0]}; // Opcode 3 (Low byte)
                            wr_uart <= 1'b1;
                            pending_money <= 1'b0;
                            master_money_reg <= master_p2_money; // Zapisz stan po pełnej wysyłce
                        end
                    end
                end 
                else begin 
                    // Logika nadawania dla SLAVE
                    if (pending_hit) begin
                        tx_data <= {1'b0, 3'b001, 4'b0001}; // Opcode 1 (Action), Payload 1 (Hit)
                        wr_uart <= 1'b1;
                        pending_hit <= 1'b0;
                    end
                    else if (pending_stand) begin
                        tx_data <= {1'b0, 3'b001, 4'b0010}; // Opcode 1 (Action), Payload 2 (Stand)
                        wr_uart <= 1'b1;
                        pending_stand <= 1'b0;
                    end
                end
            end
        end
    end

    // --- 3. LOGIKA ODBIERANIA (RX Decoder) ---
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
            temp_money_high <= 5'd0;
        end else begin
            // Impulsy domyślnie ściągamy do zera w kolejnym takcie zegara
            rd_uart <= 1'b0;
            uart_card_valid <= 1'b0;
            uart_new_game <= 1'b0;
            slave_req_hit <= 1'b0;
            slave_req_stand <= 1'b0;

            if (!rx_empty && !rd_uart) begin
                rd_uart <= 1'b1; // Konsumujemy bajt z FIFO UART-a

                if (rx_data[7] == 1'b1) begin 
                    // OTRZYMANO KARTĘ (Rozpakowuje tylko Slave)
                    if (!is_master) begin
                        uart_card_valid <= 1'b1;
                        uart_card_dst <= rx_data[6] ? 2'd1 : 2'd2; // 1 = P1, 0 = Krupier (kod 2 w Datapath)
                        uart_card_val <= rx_data[5:0];
                    end
                end
                else begin 
                    // OTRZYMANO KOMENDĘ
                    case (rx_data[6:4])
                        3'b001: begin // AKCJA GRACZA (Rozpakowuje tylko Master)
                            if (is_master) begin
                                if (rx_data[3:0] == 4'b0001) slave_req_hit <= 1'b1;
                                if (rx_data[3:0] == 4'b0010) slave_req_stand <= 1'b1;
                            end
                        end
                        3'b010: begin // MONEY HIGH BYTE (Rozpakowuje Slave)
                            if (!is_master) temp_money_high <= rx_data[4:0];
                        end
                        3'b011: begin // MONEY LOW BYTE (Rozpakowuje Slave)
                            if (!is_master) slave_p2_money_out <= {temp_money_high, rx_data[4:0]};
                        end
                        3'b100: begin // NEW GAME (Rozpakowuje Slave)
                            if (!is_master) uart_new_game <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end

endmodule