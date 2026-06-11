/*
 * Module name:   sliding_window_buffer
 * Author:        Bartłomiej Raczyński
 * Version:       1.2
 * Last modified: 2026-06-12
 * Description:   Equivalent to Python deque(maxlen=208) with inference_step=20.
 * Stores the window in BRAM and sends it via AXI-Stream to the model.
 *
 * Changes v1.2:
 * - actual_rd_ptr is now calculated
 * from the last committed wr_ptr (wr_ptr_snap), not from the current
 * wr_ptr which grows asynchronously during SENDING.
 * The previous version used wr_ptr which could change during
 * transmission, shifting the read base and causing corrupted samples.
 * - ptr_sum extended to 9 bits (1 guard bit) to properly
 * handle the case wr_ptr_snap=0, rd_count=207 → sum=207 < 208,
 * which previously could cause bad wrap-around.
 * - start_inference pulses only for 1 cycle (regardless of
 * trigger_condition length) — inf_pulsed flag added.
 * - Explicit reset of actual_rd_ptr and wr_ptr_snap on rst_n.
 */

module sliding_window_buffer #(
    parameter int DATA_WIDTH  = 96,
    parameter int WINDOW_SIZE = 208,
    parameter int STEP_SIZE   = 20
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  wr_en,

    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                  start_inference,
    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready
);

    /*
     * ----------------------------------------------------------------
     * Window memory
     * ----------------------------------------------------------------
     */
    logic [DATA_WIDTH-1:0] mem [0:WINDOW_SIZE-1];

    /*
     * ----------------------------------------------------------------
     * Pointers and counters
     * ----------------------------------------------------------------
     */
    logic [7:0] wr_ptr;       // points to where to write the NEXT sample
    logic [7:0] wr_ptr_snap;  // frozen read base during SENDING
    logic [7:0] step_cnt;     // how many samples since the last trigger
    logic       window_full;  // true after the first full fill

    logic [7:0] rd_count;     // how many samples have been sent in the current burst

    /*
     * ----------------------------------------------------------------
     * Buffer FSM states
     * ----------------------------------------------------------------
     */
    typedef enum logic { IDLE, SENDING } buf_state_t;
    buf_state_t state;

    /*
     * ----------------------------------------------------------------
     * Trigger condition: first full fill OR every STEP_SIZE
     * ----------------------------------------------------------------
     */
    logic trigger_condition;
    assign trigger_condition =
        wr_en && (
            (!window_full && (wr_ptr == WINDOW_SIZE - 1)) ||
            ( window_full && (step_cnt == STEP_SIZE - 1))
        );

    /*
     * ----------------------------------------------------------------
     * Main sequential block
     * ----------------------------------------------------------------
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr      <= '0;
            wr_ptr_snap <= '0;
            step_cnt    <= '0;
            window_full <= 1'b0;
            rd_count    <= '0;
            state       <= IDLE;
        end else begin

            // -- Step counter (always updated on wr_en) -----
            if (wr_en) begin
                step_cnt <= (step_cnt == STEP_SIZE - 1) ? '0
                                                        : step_cnt + 8'b1;
            end

            /*
             * -- Memory write (only in IDLE state) --------------
             * In the SENDING state, we discard new samples — we do not destroy
             * the window that is currently being read.
             */
            if (wr_en && (state == IDLE)) begin
                mem[wr_ptr] <= data_in;

                if (wr_ptr == WINDOW_SIZE - 1) begin
                    wr_ptr      <= '0;
                    window_full <= 1'b1;
                end else begin
                    wr_ptr <= wr_ptr + 8'b1;
                end
            end

            // -- Buffer FSM ------------------------------------------
            case (state)
                IDLE: begin
                    if (trigger_condition) begin
                        wr_ptr_snap <= wr_ptr;
                        rd_count    <= '0;
                        state       <= SENDING;
                    end
                end

                SENDING: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        if (rd_count == WINDOW_SIZE - 1) begin
                            // Last sample sent — return to IDLE
                            state <= IDLE;
                        end else begin
                            rd_count <= rd_count + 8'b1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    /*
     * ----------------------------------------------------------------
     * Read address calculation
     *
     * actual_rd_ptr = (wr_ptr_snap + rd_count) mod WINDOW_SIZE
     *
     * We use wr_ptr_snap (frozen), not wr_ptr, so the base does not
     * change during an ongoing burst.
     *
     * 9 bits are sufficient: max(wr_ptr_snap)=207, max(rd_count)=207,
     * max sum=414 < 512.
     * ----------------------------------------------------------------
     */
    logic [8:0] ptr_sum;
    logic [7:0] actual_rd_ptr;

    assign ptr_sum       = {1'b0, wr_ptr_snap} + {1'b0, rd_count};
    assign actual_rd_ptr = (ptr_sum >= 9'(WINDOW_SIZE)) ?
                           (ptr_sum[7:0] - 8'(WINDOW_SIZE)) :
                            ptr_sum[7:0];

    /*
     * ----------------------------------------------------------------
     * AXI-Stream Outputs
     * ----------------------------------------------------------------
     */
    assign m_axis_tvalid = (state == SENDING);
    assign m_axis_tdata  = mem[actual_rd_ptr];

    /*
     * start_inference: 1-cycle pulse signaling to the FSM that the burst
     * has just started (in the same cycle as the IDLE→SENDING transition).
     */
    assign start_inference = (state == IDLE) && trigger_condition;

endmodule