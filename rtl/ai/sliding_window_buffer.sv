/**
 * Module name:   sliding_window_buffer
 * Author:        Bartłomiej Raczyński 
 * Version:       1.1
 * Last modified: 2026-06-09
 * Description:   Replicates Python's deque(maxlen=208) with inference_step=20.
 * Uses BRAM to store the window and blasts it via AXI-Stream.
 */

module sliding_window_buffer #(
    parameter DATA_WIDTH = 96,
    parameter WINDOW_SIZE = 208,
    parameter STEP_SIZE = 20
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic wr_en,

    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic start_inference,
    output logic m_axis_tvalid,
    input  logic m_axis_tready
);

    logic [DATA_WIDTH-1:0] mem [0:WINDOW_SIZE-1];
    logic [7:0] wr_ptr;
    logic [7:0] step_cnt;
    logic window_full;

    logic [7:0] rd_count;
    logic [7:0] actual_rd_ptr;

    typedef enum logic {IDLE, SENDING} state_t;
    state_t state;

    logic trigger_condition;
    assign trigger_condition = wr_en && (
        (window_full == 1'b0 && wr_ptr == WINDOW_SIZE - 1) || 
        (window_full == 1'b1 && step_cnt == STEP_SIZE - 1)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            step_cnt <= '0;
            window_full <= 1'b0;
            rd_count <= '0;
            state <= IDLE;
        end else begin
            
            if (wr_en) begin
                if (step_cnt == STEP_SIZE - 1) begin
                    step_cnt <= '0;
                end else begin
                    step_cnt <= step_cnt + 1'b1;
                end
            end

            if (wr_en && (state == IDLE)) begin
                mem[wr_ptr] <= data_in;

                if (wr_ptr == WINDOW_SIZE - 1) begin
                    wr_ptr <= '0;
                    window_full <= 1'b1;
                end else begin
                    wr_ptr <= wr_ptr + 1'b1;
                end
            end

            case (state)
                IDLE: begin
                    if (trigger_condition) begin
                        state <= SENDING;
                        rd_count <= '0;
                    end
                end

                SENDING: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        if (rd_count == WINDOW_SIZE - 1) begin
                            state <= IDLE; 
                        end else begin
                            rd_count <= rd_count + 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    logic [8:0] ptr_sum;
    assign ptr_sum = {1'b0, wr_ptr} + {1'b0, rd_count};
    
    assign actual_rd_ptr = (ptr_sum >= WINDOW_SIZE) ? 
                           (ptr_sum - WINDOW_SIZE) : 
                           ptr_sum[7:0];

    assign m_axis_tvalid = (state == SENDING);
    assign m_axis_tdata  = mem[actual_rd_ptr];
    assign start_inference = (state == IDLE) && trigger_condition;

endmodule