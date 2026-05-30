/**
 * Module name:   model_controller_fsm
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-30
 * Description: Top-level FSM controller for a 1D-CNN hardware accelerator (Vivado HLS).
 * It manages the AI model's execution cycle using the ap_ctrl protocol.
 *
 * Key features:
 * 1. AXI4-Stream dataflow synchronization (TVALID/TREADY).
 * 2. Hardware ArgMax using signed comparators to extract the winning gesture
 * (NOTHING, SWIPE_RIGHT, KNOCK) from a 48-bit output vector.
 * 3. Latch-free output register holding the recognized gesture between inference cycles. 
 */

import ai_type_pkg::*;

module model_controller_fsm (
    input logic clk,
    input logic rst_n,

    input logic ap_done,
    input logic ap_idle,
    input logic ap_ready,
    output logic ap_start,
    input logic [47:0] layer15_out_TDATA,
    output logic layer15_out_TREADY,
    input logic layer15_out_TVALID,

    output gesture_out gesture
);
    /* Local variables and signals */
    typedef enum logic [2:0] {
        IDLE,
        START,
        PROCESSING,
        DONE
    } state_t;

    state_t state, state_nxt;
    logic start_nxt, tready_nxt;

    gesture_out gesture_nxt;

    logic signed [15:0] score_bg, score_gest_1, score_gest_2;

    /* Next State Decode Logic */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ap_start <= 1'b0;
            layer15_out_TREADY <= 1'b0;
            gesture <= NOTHING;

        end else begin
            state <= state_nxt;
            ap_start <= start_nxt;
            layer15_out_TREADY <= tready_nxt;
            gesture <= gesture_nxt;
        end
    end

        /* Next State Decode Logic */
    always_comb begin
        state_nxt    = state;

        case (state)
            IDLE: begin
                if (ap_idle) begin
                    state_nxt = START;
                end
            end

            START: begin
                if (!ap_idle) begin
                    state_nxt = PROCESSING;
                end
            end

            PROCESSING: begin
                if (ap_done) begin
                    state_nxt = DONE;
                end
            end

            DONE: begin
                state_nxt = IDLE;
            end

            default: state_nxt = IDLE;
        endcase
    end

    /* Output Decode Logic */
    always_comb begin
        start_nxt = 1'b0;
        tready_nxt = 1'b0;
        score_bg = layer15_out_TDATA[15:0];
        score_gest_1 = layer15_out_TDATA[31:16];
        score_gest_2 = layer15_out_TDATA[47:32];
        gesture_nxt = gesture; // Pamięć gestu

        // AXI-Stream Handshake Capture - łapiemy w locie, niezależnie od stanu!
        if (layer15_out_TVALID && layer15_out_TREADY) begin
            if ((score_bg > score_gest_1) && (score_bg > score_gest_2)) begin
                gesture_nxt = NOTHING;
            end 
            else if ((score_gest_1 > score_bg) && (score_gest_1 > score_gest_2)) begin
                gesture_nxt = SWIPE_RIGHT;
            end 
            else begin
                gesture_nxt = KNOCK; 
            end
        end

        // Zwykłe sterowanie flagami zależne od stanów
        case (state)
            IDLE: begin
            end
            START: begin
                start_nxt = 1'b1;
            end
            PROCESSING: begin
                tready_nxt = 1'b1;
            end
            DONE: begin
                tready_nxt = 1'b1;
            end
            default: begin
            end
        endcase 
    end

endmodule