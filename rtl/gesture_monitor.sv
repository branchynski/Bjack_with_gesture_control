
import ai_type_pkg::*;

module gesture_monitor (
    input  logic clk,
    input  logic rst_n,
    input  gesture_out current_gesture,

    output logic [2:0] leds
);

    logic [2:0] leds_nxt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            leds <= '0;
        end else begin
            leds <= leds_nxt;
        end
    end

    always_comb begin
        case (current_gesture)
            NOTHING:       leds_nxt = 3'b001;
            SWIPE_RIGHT: leds_nxt = 3'b010;
            KNOCK:  leds_nxt = 3'b100;
            default:     leds_nxt = 3'b000;
        endcase
    end

endmodule