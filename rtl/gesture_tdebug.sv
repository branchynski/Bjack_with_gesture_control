/**
 * Module name:   gesture_tdebug
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-06-07
 * Description:  module for test debugging the gesture recognition system. 
 * It allows manually setting the output gesture using buttons, which is useful for verifying 
 * the functionality of the gesture monitoring and output display logic without needing the full AI inference pipeline to be operational.
 */

import ai_type_pkg::*;

module gesture_tdebug (
    input logic clk,
    input logic rst_n,

    input logic btn_on,
    input logic btn_knock,
    input logic btn_swipe,

    output gesture_out gesture
);

gesture_out gesture_nxt;

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        gesture <= NOTHING;
    end else begin
        gesture <= gesture_nxt;
    end
end

always_comb begin
    case (btn_on)
        1'b0: gesture_nxt = NOTHING;
        1'b1: begin
            if (btn_knock) begin
                gesture_nxt = KNOCK;
            end else if (btn_swipe) begin
                gesture_nxt = SWIPE_RIGHT;
            end else begin
                gesture_nxt = NOTHING;
            end
        end
        default: gesture_nxt = NOTHING;
    endcase
end


endmodule