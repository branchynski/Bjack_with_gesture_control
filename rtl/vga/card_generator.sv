/********************************************************************************
 * Module Name:    card_generator
 * Author:         Eryk Rutka
 * Date:           2026-06-02
 * Version:        3.0 (Multiplayer 3-Lane Optimized Renderer)
 * Description:    
 * Dynamic card renderer using direct font_rom access. Draws 5 slots for 
 * each Player 0, Player 1, Dealer Wojna 
 * Uses multiplexed Y-coordinates (base_y) to save FPGA logic resources.
 ********************************************************************************/

 module card_generator (
    input  logic clk,
    input  logic rst_n,

    // Karty od dwóch graczy i krupiera
    input  logic [5:0] p0_cards [0:4],
    input  logic [5:0] p1_cards [0:4],
    input  logic [5:0] dealer_cards [0:4],
    
    // Liczniki leżących kart
    input  logic [2:0] p0_card_cnt,
    input  logic [2:0] p1_card_cnt,
    input  logic [2:0] dealer_card_cnt,

    vga_if.in  vga_in,
    vga_if.out vga_out
);

    timeunit 1ns;
    timeprecision 1ps;

    // --- Parametry wymiarów  ---
    localparam CARD_W = 100;
    localparam CARD_H = 140;
    
    localparam DEALER_Y = 80;
    localparam P0_Y     = 310;
    localparam P1_Y     = 540;
    
    logic [10:0] SLOT_X [0:4];
    assign SLOT_X[0] = 200; assign SLOT_X[1] = 320; 
    assign SLOT_X[2] = 440; assign SLOT_X[3] = 560; assign SLOT_X[4] = 680;

    // --- Funkcja dekodująca ASCII ---
    function automatic logic [15:0] get_card_ascii(input logic [5:0] card_val);
        logic [3:0] rank; logic [1:0] suit; logic [7:0] char_rank, char_suit;
        rank = card_val % 13; suit = card_val / 13;
        case (rank)
            0: char_rank=8'h41; 1: char_rank=8'h32; 2: char_rank=8'h33; 3: char_rank=8'h34;
            4: char_rank=8'h35; 5: char_rank=8'h36; 6: char_rank=8'h37; 7: char_rank=8'h38;
            8: char_rank=8'h39; 9: char_rank=8'h54; 10: char_rank=8'h4A; 11: char_rank=8'h51; 12: char_rank=8'h4B;
            default: char_rank=8'h20;
        endcase
        case (suit)
            0: char_suit=8'h03; 1: char_suit=8'h04; 2: char_suit=8'h05; 3: char_suit=8'h06;
            default: char_suit=8'h20;
        endcase
        return {char_rank, char_suit};
    endfunction

    // --- STAGE 1: Logika kombinacyjna ---
    logic in_card, is_red, in_text, is_flipped; 
    logic [7:0] target_char;
    logic [5:0] active_card_val;
    logic [3:0] char_y_line;
    logic [2:0] char_x_bit; 
    logic [15:0] temp_ascii; 
    logic [10:0] rom_addr;
    logic [7:0]  rom_pixels;

    logic active_zone;
    logic [10:0] base_y;

    always_comb begin
        in_card = 1'b0; is_red = 1'b0; in_text = 1'b0; is_flipped = 1'b0;
        target_char = 8'h20; rom_addr = '0; char_y_line = '0; char_x_bit = '0;
        temp_ascii = 16'b0; active_card_val = '0;

        for (int i = 0; i < 5; i++) begin
            active_zone = 1'b0;
            base_y = '0;
            
            // Namierzanie - w której strefie i na którym slocie jesteśmy
            if (i < p0_card_cnt && vga_in.hcount >= SLOT_X[i] && vga_in.hcount < SLOT_X[i] + CARD_W && 
                vga_in.vcount >= P0_Y && vga_in.vcount < P0_Y + CARD_H) begin
                active_zone = 1'b1; active_card_val = p0_cards[i]; base_y = P0_Y;
            end
            else if (i < p1_card_cnt && vga_in.hcount >= SLOT_X[i] && vga_in.hcount < SLOT_X[i] + CARD_W && 
                     vga_in.vcount >= P1_Y && vga_in.vcount < P1_Y + CARD_H) begin
                active_zone = 1'b1; active_card_val = p1_cards[i]; base_y = P1_Y;
            end
            else if (i < dealer_card_cnt && vga_in.hcount >= SLOT_X[i] && vga_in.hcount < SLOT_X[i] + CARD_W && 
                     vga_in.vcount >= DEALER_Y && vga_in.vcount < DEALER_Y + CARD_H) begin
                active_zone = 1'b1; active_card_val = dealer_cards[i]; base_y = DEALER_Y;
            end

            // Logika rysowania symboli 
            if (active_zone) begin
                in_card = 1'b1;
                is_red = (active_card_val / 13 == 0) || (active_card_val / 13 == 1); 
                temp_ascii = get_card_ascii(active_card_val); 
                
                // Figura
                if (vga_in.hcount >= SLOT_X[i] + 5 && vga_in.hcount < SLOT_X[i] + 21 && 
                    vga_in.vcount >= base_y + 5 && vga_in.vcount < base_y + 37) begin
                    in_text = 1'b1; is_flipped = 1'b0; target_char = temp_ascii[15:8]; 
                    char_y_line = (vga_in.vcount - (base_y + 5)) >> 1; 
                    char_x_bit  = (vga_in.hcount - (SLOT_X[i] + 5)) >> 1; 
                    rom_addr = {target_char[6:0], char_y_line};
                end
                // Kolor
                else if (vga_in.hcount >= SLOT_X[i] + 25 && vga_in.hcount < SLOT_X[i] + 41 && 
                         vga_in.vcount >= base_y + 5 && vga_in.vcount < base_y + 37) begin
                    in_text = 1'b1; is_flipped = 1'b0; target_char = temp_ascii[7:0]; 
                    char_y_line = (vga_in.vcount - (base_y + 5)) >> 1; 
                    char_x_bit  = (vga_in.hcount - (SLOT_X[i] + 25)) >> 1; 
                    rom_addr = {target_char[6:0], char_y_line};
                end
                // Figura (obrót)  
                else if (vga_in.hcount >= SLOT_X[i] + 79 && vga_in.hcount < SLOT_X[i] + 95 && 
                         vga_in.vcount >= base_y + 103 && vga_in.vcount < base_y + 135) begin
                    in_text = 1'b1; is_flipped = 1'b1; target_char = temp_ascii[15:8]; 
                    char_y_line = 15 - ((vga_in.vcount - (base_y + 103)) >> 1); 
                    char_x_bit  = (vga_in.hcount - (SLOT_X[i] + 79)) >> 1; 
                    rom_addr = {target_char[6:0], char_y_line};
                end
                // Kolor (obrót)  
                else if (vga_in.hcount >= SLOT_X[i] + 59 && vga_in.hcount < SLOT_X[i] + 75 && 
                         vga_in.vcount >= base_y + 103 && vga_in.vcount < base_y + 135) begin
                    in_text = 1'b1; is_flipped = 1'b1; target_char = temp_ascii[7:0]; 
                    char_y_line = 15 - ((vga_in.vcount - (base_y + 103)) >> 1); 
                    char_x_bit  = (vga_in.hcount - (SLOT_X[i] + 59)) >> 1; 
                    rom_addr = {target_char[6:0], char_y_line};
                end
            end
        end
    end

    // --- INSTANCJA PAMIĘCI ---
    font_rom u_font_rom (.clk(clk), .addr(rom_addr), .char_line_pixels(rom_pixels));

    // --- PAKOWANIE SYGNAŁÓW DO MODUŁU DELAY ---
    localparam DEL_W = 11 + 11 + 12 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 3 + 1; // 45 bitów
    logic [DEL_W-1:0] delay_in, delay_out;

    assign delay_in = {
        vga_in.hcount, vga_in.vcount, vga_in.rgb, vga_in.hsync, vga_in.vsync, 
        vga_in.hblnk, vga_in.vblnk, in_card, is_red, in_text, char_x_bit, is_flipped 
    };

    logic [10:0] d_hcount, d_vcount; logic [11:0] d_rgb;
    logic d_hsync, d_vsync, d_hblnk, d_vblnk, d_in_card, d_is_red, d_in_text, d_is_flipped;
    logic [2:0] d_char_x_bit;

    assign {
        d_hcount, d_vcount, d_rgb, d_hsync, d_vsync, d_hblnk, d_vblnk, 
        d_in_card, d_is_red, d_in_text, d_char_x_bit, d_is_flipped
    } = delay_out;

    delay #(.WIDTH(DEL_W), .CLK_DEL(1)) u_delay (.clk(clk), .rst_n(rst_n), .din(delay_in), .dout(delay_out));

    // --- STAGE 2: Rejestrowanie wyjść ---
    logic [10:0] out_hcount, out_vcount; 
    logic out_hsync, out_vsync, out_hblnk, out_vblnk; 
    logic [11:0] out_rgb;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_hcount <= '0; out_vcount <= '0; out_hsync <= '0;
            out_vsync <= '0; out_hblnk <= '0; out_vblnk <= '0; out_rgb <= '0;
        end else begin
            out_hcount <= d_hcount; out_vcount <= d_vcount; out_hsync <= d_hsync;
            out_vsync <= d_vsync; out_hblnk <= d_hblnk; out_vblnk <= d_vblnk;

            if (d_in_text) begin
                logic target_bit;
                target_bit = d_is_flipped ? rom_pixels[d_char_x_bit] : rom_pixels[7 - d_char_x_bit];
                if (target_bit) out_rgb <= d_is_red ? 12'hf_0_0 : 12'h0_0_0;
                else out_rgb <= 12'hf_f_f;
            end else if (d_in_card) out_rgb <= 12'hf_f_f;
            else out_rgb <= d_rgb;
        end
    end

    assign vga_out.hcount = out_hcount; assign vga_out.vcount = out_vcount;
    assign vga_out.hsync = out_hsync; assign vga_out.vsync = out_vsync;
    assign vga_out.hblnk = out_hblnk; assign vga_out.vblnk = out_vblnk; assign vga_out.rgb = out_rgb;

endmodule