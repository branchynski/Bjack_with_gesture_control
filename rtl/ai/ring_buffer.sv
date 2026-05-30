/**
 * Module name:   ring_buffer
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-07
 * Description:  Ring buffer module for storing and retrieving data.
 */

module ring_buffer #(    
    parameter DATA_WIDTH = 16,
    parameter DEPTH      = 256, 
    parameter ADDR_WIDTH = 8    
)(
    input logic clk,
    input logic rst_n,
        
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic wr_en,
    output logic full,
    
    
    input  logic rd_en,  
    output logic [DATA_WIDTH-1:0] data_out,
    output logic empty
);
    /* Local variables and signals */
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;
    
    logic [ADDR_WIDTH:0] count;

    logic [ADDR_WIDTH-1:0] wr_ptr_nxt;
    logic [ADDR_WIDTH-1:0] rd_ptr_nxt;
    logic [ADDR_WIDTH:0]   count_nxt;
    logic                  full_nxt;
    logic                  empty_nxt;
    logic [DATA_WIDTH-1:0] data_out_nxt;

    /* Next State Decode Logic */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= '0;
            rd_ptr   <= '0;
            count    <= '0;
            
            full     <= 1'b0;
            empty    <= 1'b1;
            data_out <= '0;
        end else begin
            wr_ptr   <= wr_ptr_nxt;
            rd_ptr   <= rd_ptr_nxt;
            count    <= count_nxt;
            
            full     <= full_nxt;
            empty    <= empty_nxt;
            data_out <= data_out_nxt;

            if (wr_en && !full) begin
                mem[wr_ptr] <= data_in;
            end
        end
    end

    /* Output Decode Logic */
    always_comb begin
        wr_ptr_nxt   = wr_ptr;
        rd_ptr_nxt   = rd_ptr;
        count_nxt    = count;
        data_out_nxt = data_out;

        case ({wr_en && !full, rd_en && !empty})
            /* ONLY WRITE */
            2'b10: begin 
                wr_ptr_nxt = wr_ptr + 1'b1;
                count_nxt  = count + 1'b1;
            end
            /* ONLY READ */
            2'b01: begin 
                rd_ptr_nxt   = rd_ptr + 1'b1;
                data_out_nxt = mem[rd_ptr];
                count_nxt    = count - 1'b1;
            end
            /* BOTH WRITE AND READ */
            2'b11: begin 
                wr_ptr_nxt   = wr_ptr + 1'b1;
                rd_ptr_nxt   = rd_ptr + 1'b1;
                data_out_nxt = mem[rd_ptr];
            end
            default: begin
            end
        endcase

        full_nxt  = (count_nxt == DEPTH);
        empty_nxt = (count_nxt == '0);
    end

endmodule