/*
 * Module name:   model_controller_fsm
 * Author:        Bartłomiej Raczyński
 * Version:       1.2
 * Last modified: 2026-06-12
 * Description:   FSM controlling the execution cycle of the HLS 1D-CNN accelerator.
 *
 * Changes v1.2:
 * - Fixed the score_nothing / score_knock assignments.
 * HLS packs out[0] at the LSB. Python: 0=nothing, 1=swipe, 2=knock.
 * The previous version had nothing←[47:32] and knock←[15:0] — reversed.
 * Result: a model confident of silence generated false KNOCKs.
 * - flush_cnt extended to 5 bits (supports FLUSH_INFERENCES=20).
 * The previous version truncated the value when casting 5'(20)=20, but
 * the declaration was already 5-bit — left with an explicit comment.
 * - score_* moved to always_ff as registered signals,
 * to avoid hazards when sampling TDATA after TVALID drops.
 */

import ai_type_pkg::*;

module model_controller_fsm #(
    parameter int VOTE_THRESHOLD   = 5,
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

    /*
     * ----------------------------------------------------------------
     * FSM types and states
     * ----------------------------------------------------------------
     */
    typedef enum logic [1:0] {
        IDLE,
        START,
        PROCESSING,
        DONE
    } state_t;

    state_t state, state_nxt;

    /*
     * ----------------------------------------------------------------
     * Registers
     * ----------------------------------------------------------------
     */
    logic [4:0] flush_cnt,     flush_cnt_nxt;

    logic       start_nxt;
    gesture_out gesture_nxt;
    logic       pending_inf,   pending_inf_nxt;

    logic [2:0] votes_nothing, votes_nothing_nxt;
    logic [2:0] votes_swipe,   votes_swipe_nxt;
    logic [2:0] votes_knock,   votes_knock_nxt;
    logic [2:0] vote_cnt,      vote_cnt_nxt;

    /*
     * Registered scores: sampled only when TVALID&&TREADY=1,
     * so that combinational logic does not "see" old data.
     */
    logic signed [15:0] score_nothing, score_swipe, score_knock;

    /*
     * ----------------------------------------------------------------
     * TREADY active when waiting for a result or receiving it
     * ----------------------------------------------------------------
     */
    assign layer15_out_TREADY = (state == PROCESSING) || (state == DONE);

    /*
     * ----------------------------------------------------------------
     * Registering model results
     * HLS packs out[0] at the LSB:
     * out[0] = nothing → bits [15:0]
     * out[1] = swipe   → bits [31:16]
     * out[2] = knock   → bits [47:32]
     * ----------------------------------------------------------------
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            score_nothing <= '0;
            score_swipe   <= '0;
            score_knock   <= '0;
        end else if (layer15_out_TVALID && layer15_out_TREADY) begin
            score_nothing <= signed'(layer15_out_TDATA[15:0]);   // out[0]
            score_swipe   <= signed'(layer15_out_TDATA[31:16]);  // out[1]
            score_knock   <= signed'(layer15_out_TDATA[47:32]);  // out[2]
        end
    end

    /*
     * ----------------------------------------------------------------
     * State and outputs register
     * ----------------------------------------------------------------
     */
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
            flush_cnt     <= '0;
        end else begin
            state         <= state_nxt;
            ap_start      <= start_nxt;
            gesture       <= gesture_nxt;
            pending_inf   <= pending_inf_nxt;
            votes_nothing <= votes_nothing_nxt;
            votes_swipe   <= votes_swipe_nxt;
            votes_knock   <= votes_knock_nxt;
            vote_cnt      <= vote_cnt_nxt;
            flush_cnt     <= flush_cnt_nxt;
        end
    end

    /*
     * ----------------------------------------------------------------
     * State transition logic
     * ----------------------------------------------------------------
     */
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

    /*
     * ----------------------------------------------------------------
     * Output logic (Mixed Moore/Mealy)
     * ----------------------------------------------------------------
     */
    always_comb begin
        start_nxt         = 1'b0;
        gesture_nxt       = gesture;
        pending_inf_nxt   = pending_inf;
        votes_nothing_nxt = votes_nothing;
        votes_swipe_nxt   = votes_swipe;
        votes_knock_nxt   = votes_knock;
        vote_cnt_nxt      = vote_cnt;
        flush_cnt_nxt     = flush_cnt;

        // pending_inf handling: set on new trigger, clear when handled
        if (state == START && !start_inference)
            pending_inf_nxt = 1'b0;
        if (start_inference)
            pending_inf_nxt = 1'b1;

        /*
         * ----------------------------------------------------------------
         * Reception and classification of the model result
         * Using score_* — safely registered.
         * Handshake: TVALID && TREADY (TREADY=1 in PROCESSING or DONE)
         * ----------------------------------------------------------------
         */
        if (layer15_out_TVALID && layer15_out_TREADY) begin

            if (flush_cnt > 5'b0) begin
                /*
                 * We are in the "flush" window after detecting a gesture —
                 * ignoring votes, only counting down.
                 */
                flush_cnt_nxt = flush_cnt - 5'b1;

                if (flush_cnt_nxt == 5'b0) begin
                    // End of flush — return to NOTHING and clear votes
                    gesture_nxt       = NOTHING;
                    votes_nothing_nxt = '0;
                    votes_swipe_nxt   = '0;
                    votes_knock_nxt   = '0;
                    vote_cnt_nxt      = '0;
                end

            end else begin
                // Normal voting
                vote_cnt_nxt = vote_cnt + 3'b1;

                if ((score_swipe > (score_nothing + CONFIDENCE_MARGIN)) &&
                    (score_swipe >= score_knock))
                    votes_swipe_nxt   = votes_swipe   + 3'b1;
                else if ((score_knock > (score_nothing + CONFIDENCE_MARGIN)) &&
                         (score_knock > score_swipe))
                    votes_knock_nxt   = votes_knock   + 3'b1;
                else
                    votes_nothing_nxt = votes_nothing + 3'b1;

                // Decision after collecting VOTE_THRESHOLD votes
                if (vote_cnt_nxt == 3'(VOTE_THRESHOLD)) begin

                    if (votes_swipe_nxt > votes_nothing_nxt &&
                        votes_swipe_nxt >= votes_knock_nxt) begin
                        gesture_nxt   = SWIPE_RIGHT;
                        flush_cnt_nxt = 5'(FLUSH_INFERENCES);

                    end else if (votes_knock_nxt > votes_nothing_nxt &&
                                 votes_knock_nxt > votes_swipe_nxt) begin
                        gesture_nxt   = KNOCK;
                        flush_cnt_nxt = 5'(FLUSH_INFERENCES);

                    end else begin
                        gesture_nxt = NOTHING;
                    end

                    // Reset voting
                    votes_nothing_nxt = '0;
                    votes_swipe_nxt   = '0;
                    votes_knock_nxt   = '0;
                    vote_cnt_nxt      = '0;
                end
            end
        end

        // ap_start pulses for one cycle in the START state
        if (state == START)
            start_nxt = 1'b1;
    end

endmodule