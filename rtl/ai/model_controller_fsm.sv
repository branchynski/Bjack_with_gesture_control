/**
 * Module name:   model_controller_fsm
 * Author:        Bartłomiej Raczyński
 * Version:       1.1
 * Last modified: 2026-06-09
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

module model_controller_fsm #(
    parameter int VOTE_THRESHOLD  = 5,
    parameter int FLUSH_INFERENCES = 12,
    parameter signed [15:0] CONFIDENCE_MARGIN = 16'sd300
)(
    input  logic clk,
    input  logic rst_n,

    input  logic ap_done,
    input  logic ap_idle,
    input  logic ap_ready,
    output logic ap_start,

    input  logic start_inference,

    input  logic [47:0] layer15_out_TDATA,
    output logic        layer15_out_TREADY,
    input  logic        layer15_out_TVALID,

    output gesture_out gesture
);

    typedef enum logic [1:0] {
        IDLE,
        START,
        PROCESSING,
        DONE
    } state_t;

    state_t state, state_nxt;

    logic [4:0] flush_cnt, flush_cnt_nxt;

    logic       start_nxt;
    gesture_out gesture_nxt;
    logic       pending_inf, pending_inf_nxt;

    logic [2:0] votes_nothing,  votes_nothing_nxt;
    logic [2:0] votes_swipe,    votes_swipe_nxt;
    logic [2:0] votes_knock,    votes_knock_nxt;
    logic [2:0] vote_cnt,       vote_cnt_nxt;

    logic signed [15:0] score_nothing, score_swipe, score_knock;

    assign layer15_out_TREADY = (state == PROCESSING) || (state == DONE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            ap_start      <= 1'b0;
            gesture       <= NOTHING;
            pending_inf   <= 1'b0;
            votes_nothing <= '0;
            votes_swipe   <= '0;
            votes_knock   <= '0;
            vote_cnt      <= '0;
            flush_cnt <= '0;
        end else begin
            state         <= state_nxt;
            ap_start      <= start_nxt;
            gesture       <= gesture_nxt;
            pending_inf   <= pending_inf_nxt;
            votes_nothing <= votes_nothing_nxt;
            votes_swipe   <= votes_swipe_nxt;
            votes_knock   <= votes_knock_nxt;
            vote_cnt      <= vote_cnt_nxt;
            flush_cnt <= flush_cnt_nxt;
        end
    end

    always_comb begin
        state_nxt = state;
        case (state)
            IDLE:       if (ap_idle && pending_inf) state_nxt = START;
            START:      if (!ap_idle)               state_nxt = PROCESSING;
            PROCESSING: if (ap_done)                state_nxt = DONE;
            DONE:                                   state_nxt = IDLE;
            default:                                state_nxt = IDLE;
        endcase
    end

    always_comb begin
        start_nxt         = 1'b0;
        gesture_nxt       = gesture;
        pending_inf_nxt   = pending_inf;
        votes_nothing_nxt = votes_nothing;
        votes_swipe_nxt   = votes_swipe;
        votes_knock_nxt   = votes_knock;
        vote_cnt_nxt      = vote_cnt;
        flush_cnt_nxt     = flush_cnt;

        if (state == START && !start_inference)
            pending_inf_nxt = 1'b0;
        else if (start_inference)
            pending_inf_nxt = 1'b1;

        score_nothing = layer15_out_TDATA[47:32];
        score_swipe   = layer15_out_TDATA[31:16];
        score_knock   = layer15_out_TDATA[15:0];

        if (layer15_out_TVALID && layer15_out_TREADY) begin
            
            if (flush_cnt > 0) begin
                flush_cnt_nxt = flush_cnt - 1;
                
                if (flush_cnt_nxt == 0) begin
                    gesture_nxt = NOTHING; 
                end
            end else begin
                vote_cnt_nxt = vote_cnt + 1'b1;

                if ((score_swipe > (score_nothing + CONFIDENCE_MARGIN)) && (score_swipe >= score_knock))
                    votes_swipe_nxt   = votes_swipe   + 1'b1;
                else if ((score_knock > (score_nothing + CONFIDENCE_MARGIN)) && (score_knock > score_swipe))
                    votes_knock_nxt   = votes_knock   + 1'b1;
                else
                    votes_nothing_nxt = votes_nothing + 1'b1; 

                if (vote_cnt_nxt == 3'(VOTE_THRESHOLD)) begin
                    if (votes_nothing_nxt >= votes_swipe_nxt && votes_nothing_nxt >= votes_knock_nxt) begin
                        gesture_nxt = NOTHING;
                    end else if (votes_swipe_nxt > votes_nothing_nxt && votes_swipe_nxt >= votes_knock_nxt) begin
                        gesture_nxt   = SWIPE_RIGHT;
                        flush_cnt_nxt = 5'(FLUSH_INFERENCES); 
                    end else begin
                        gesture_nxt   = KNOCK;
                        flush_cnt_nxt = 5'(FLUSH_INFERENCES); 
                    end

                    votes_nothing_nxt = '0;
                    votes_swipe_nxt   = '0;
                    votes_knock_nxt   = '0;
                    vote_cnt_nxt      = '0;
                end
            end
        end

        case (state)
            START:   start_nxt = 1'b1;
            default: ;
        endcase
    end

endmodule