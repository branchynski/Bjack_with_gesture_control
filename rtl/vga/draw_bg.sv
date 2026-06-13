/********************************************************************************
 * Module Name:    draw_bg
 * Author:         Eryk Rutka
 * Date:           2026-06-04
 * Version:        4.2 (Fixed-Point Money Scaling - 10-bit)
 * Description:    
 * Draws the casino green background, a black zone for dealer, 
 * red zone for Player 0, and blue zone for Player 1. 
 * Includes 2 retro arcade money panels with player labels.
 * Optimized money rendering using hardware 100x multiplier (fixed zeros).
 ********************************************************************************/

 module draw_bg (
    input  logic clk,
    input  logic rst_n,
    input  logic [9:0] p1_money, // Pieniadze gracza skalowane x100
    input  logic [9:0] p2_money, 
    vga_if.in  vga_in,
    vga_if.out vga_out
);

    timeunit 1ns;
    timeprecision 1ps;

    // --- Zones' dimensions (3 horizontal stripes) ---
    localparam BOX_X_START = 180;
    localparam BOX_X_END   = 800; 
    
    localparam D_BOX_Y_START = 50;
    localparam D_BOX_Y_END   = 250;
    
    localparam P1_BOX_Y_START = 280;
    localparam P1_BOX_Y_END   = 480;

    localparam P2_BOX_Y_START = 510;
    localparam P2_BOX_Y_END   = 710;

    // --- Panels' parameters (right side) ---
    localparam HUD_X  = 820;
    localparam HUD_W  = 160;
    localparam HUD_H  = 60;
    localparam HUD1_Y = 30;  
    localparam HUD2_Y = 630; 

    // --- 1. Combitional logic ---
    logic in_dealer_box, in_p1_box, in_p2_box;
    logic in_slot_x, in_dealer_slot, in_p1_slot, in_p2_slot;
    logic in_hud1_panel, in_hud1_border;
    logic in_hud2_panel, in_hud2_border;
    
    logic in_d_text, in_p1_text, in_p2_text, in_m1_text, in_m2_text;
    logic [7:0] target_char;
    logic [10:0] rom_addr;
    logic [2:0] char_x_bit;
    logic [3:0] char_y_line; 
    logic [11:0] bg_color;

    always_comb begin
        // Main boxes tracking
        in_dealer_box = (vga_in.hcount >= BOX_X_START && vga_in.hcount < BOX_X_END && 
                         vga_in.vcount >= D_BOX_Y_START && vga_in.vcount < D_BOX_Y_END);
        in_p1_box = (vga_in.hcount >= BOX_X_START && vga_in.hcount < BOX_X_END && 
                     vga_in.vcount >= P1_BOX_Y_START && vga_in.vcount < P1_BOX_Y_END);
        in_p2_box = (vga_in.hcount >= BOX_X_START && vga_in.hcount < BOX_X_END && 
                     vga_in.vcount >= P2_BOX_Y_START && vga_in.vcount < P2_BOX_Y_END);

        // Empty card slots tracking
        in_slot_x = ((vga_in.hcount >= 200 && vga_in.hcount < 300) ||
                     (vga_in.hcount >= 320 && vga_in.hcount < 420) ||
                     (vga_in.hcount >= 440 && vga_in.hcount < 540) ||
                     (vga_in.hcount >= 560 && vga_in.hcount < 660) ||
                     (vga_in.hcount >= 680 && vga_in.hcount < 780));

        in_dealer_slot = in_slot_x && (vga_in.vcount >= D_BOX_Y_START + 30 && vga_in.vcount < D_BOX_Y_END - 30);
        in_p1_slot = in_slot_x && (vga_in.vcount >= P1_BOX_Y_START + 30 && vga_in.vcount < P1_BOX_Y_END - 30);
        in_p2_slot = in_slot_x && (vga_in.vcount >= P2_BOX_Y_START + 30 && vga_in.vcount < P2_BOX_Y_END - 30);

        // Money panel
        in_hud1_panel = (vga_in.hcount >= HUD_X && vga_in.hcount < HUD_X + HUD_W &&
                         vga_in.vcount >= HUD1_Y && vga_in.vcount < HUD1_Y + HUD_H);
        in_hud1_border = in_hud1_panel && (vga_in.hcount < HUD_X + 4 || vga_in.hcount >= HUD_X + HUD_W - 4 ||
                                           vga_in.vcount < HUD1_Y + 4 || vga_in.vcount >= HUD1_Y + HUD_H - 4);

        in_hud2_panel = (vga_in.hcount >= HUD_X && vga_in.hcount < HUD_X + HUD_W &&
                         vga_in.vcount >= HUD2_Y && vga_in.vcount < HUD2_Y + HUD_H);
        in_hud2_border = in_hud2_panel && (vga_in.hcount < HUD_X + 4 || vga_in.hcount >= HUD_X + HUD_W - 4 ||
                                           vga_in.vcount < HUD2_Y + 4 || vga_in.vcount >= HUD2_Y + HUD_H - 4);

        in_d_text = 1'b0; in_p1_text = 1'b0; in_p2_text = 1'b0; 
        in_m1_text = 1'b0; in_m2_text = 1'b0;
        target_char = 8'h20; char_x_bit = '0; char_y_line = '0; rom_addr = '0;

        // --- P0 Money (two 0s added) ---
        if (in_hud1_panel && !in_hud1_border && 
            vga_in.hcount >= HUD_X + 8 && vga_in.hcount < HUD_X + 152 && 
            vga_in.vcount >= HUD1_Y + 14 && vga_in.vcount < HUD1_Y + 46) begin
            in_m1_text = 1'b1;
            char_x_bit = (vga_in.hcount - (HUD_X + 8)) >> 1;
            char_y_line = (vga_in.vcount - (HUD1_Y + 14)) >> 1;
            case ((vga_in.hcount - (HUD_X + 8)) >> 4)
                0: target_char = 8'h50; // P
                1: target_char = 8'h30; // 0
                2: target_char = 8'h20; // [spacja]
                3: target_char = 8'h24; // $
                4: target_char = 8'h30 + ((p1_money / 100) % 10); 
                5: target_char = 8'h30 + ((p1_money / 10) % 10);  
                6: target_char = 8'h30 + (p1_money % 10);         
                7: target_char = 8'h30;                           
                8: target_char = 8'h30;                           
                default: target_char = 8'h20;
            endcase
            rom_addr = {target_char[6:0], char_y_line};
        end
        // --- P1 Money (two 0s added) ---
        else if (in_hud2_panel && !in_hud2_border && 
            vga_in.hcount >= HUD_X + 8 && vga_in.hcount < HUD_X + 152 && 
            vga_in.vcount >= HUD2_Y + 14 && vga_in.vcount < HUD2_Y + 46) begin
            in_m2_text = 1'b1;
            char_x_bit = (vga_in.hcount - (HUD_X + 8)) >> 1;
            char_y_line = (vga_in.vcount - (HUD2_Y + 14)) >> 1;
            case ((vga_in.hcount - (HUD_X + 8)) >> 4)
                0: target_char = 8'h50; // P
                1: target_char = 8'h31; // 1
                2: target_char = 8'h20; // [spacja]
                3: target_char = 8'h24; // $
                4: target_char = 8'h30 + ((p2_money / 100) % 10); 
                5: target_char = 8'h30 + ((p2_money / 10) % 10);  
                6: target_char = 8'h30 + (p2_money % 10);         
                7: target_char = 8'h30;                           
                8: target_char = 8'h30;                           
                default: target_char = 8'h20;
            endcase
            rom_addr = {target_char[6:0], char_y_line};
        end
        // --- "DEALER WOJNA" text ---
        else if (in_dealer_box && vga_in.hcount >= 394 && vga_in.hcount < 586 && 
                 vga_in.vcount >= D_BOX_Y_START + 5 && vga_in.vcount < D_BOX_Y_START + 37) begin
            in_d_text = 1'b1;
            char_x_bit = (vga_in.hcount - 394) >> 1; char_y_line = (vga_in.vcount - (D_BOX_Y_START + 5)) >> 1;
            case ((vga_in.hcount - 394) >> 4)
                0: target_char=8'h44; 1: target_char=8'h45; 2: target_char=8'h41; 3: target_char=8'h4C;
                4: target_char=8'h45; 5: target_char=8'h52; 6: target_char=8'h20; 7: target_char=8'h57;
                8: target_char=8'h4F; 9: target_char=8'h4A; 10: target_char=8'h4E; 11: target_char=8'h41;
                default: target_char=8'h20;
            endcase
            rom_addr = {target_char[6:0], char_y_line};
        end
        // --- "PLAYER 0" text ---
        else if (in_p1_box && vga_in.hcount >= 426 && vga_in.hcount < 554 && 
                 vga_in.vcount >= P1_BOX_Y_START + 5 && vga_in.vcount < P1_BOX_Y_START + 37) begin
            in_p1_text = 1'b1;
            char_x_bit = (vga_in.hcount - 426) >> 1; char_y_line = (vga_in.vcount - (P1_BOX_Y_START + 5)) >> 1;
            case ((vga_in.hcount - 426) >> 4)
                0: target_char=8'h50; 1: target_char=8'h4C; 2: target_char=8'h41; 3: target_char=8'h59;
                4: target_char=8'h45; 5: target_char=8'h52; 6: target_char=8'h20; 7: target_char=8'h30;
                default: target_char=8'h20;
            endcase
            rom_addr = {target_char[6:0], char_y_line};
        end
        // --- "PLAYER 1" text ---
        else if (in_p2_box && vga_in.hcount >= 426 && vga_in.hcount < 554 && 
                 vga_in.vcount >= P2_BOX_Y_START + 5 && vga_in.vcount < P2_BOX_Y_START + 37) begin
            in_p2_text = 1'b1;
            char_x_bit = (vga_in.hcount - 426) >> 1; char_y_line = (vga_in.vcount - (P2_BOX_Y_START + 5)) >> 1;
            case ((vga_in.hcount - 426) >> 4)
                0: target_char=8'h50; 1: target_char=8'h4C; 2: target_char=8'h41; 3: target_char=8'h59;
                4: target_char=8'h45; 5: target_char=8'h52; 6: target_char=8'h20; 7: target_char=8'h31;
                default: target_char=8'h20;
            endcase
            rom_addr = {target_char[6:0], char_y_line};
        end

        // --- Backgroung ---
        if (vga_in.hblnk || vga_in.vblnk) bg_color = 12'h0_0_0; 
        else if (in_hud1_border || in_hud2_border) bg_color = 12'hf_a_0; 
        else if (in_hud1_panel || in_hud2_panel) bg_color = 12'h1_1_2;   
        else if (in_dealer_slot) bg_color = 12'h2_2_2;       
        else if (in_dealer_box) bg_color = 12'h0_0_0;   
        else if (in_p1_slot) bg_color = 12'h6_0_0;  
        else if (in_p1_box) bg_color = 12'h8_0_0;   
        else if (in_p2_slot) bg_color = 12'h0_0_6;  
        else if (in_p2_box) bg_color = 12'h0_0_8;   
        else bg_color = 12'h0_6_1;                      
    end

    // --- 2. ROM instance ---
    logic [7:0] rom_pixels;
    font_rom u_font_rom (
        .clk(clk), .addr(rom_addr), .char_line_pixels(rom_pixels)
    );

    // --- 3. Delay signals ---
    localparam DEL_W = 11 + 11 + 1 + 1 + 1 + 1 + 12 + 5 + 3; // 46 bitów
    logic [DEL_W-1:0] delay_in, delay_out;

    assign delay_in = {
        vga_in.hcount, vga_in.vcount, vga_in.hsync, vga_in.vsync, vga_in.hblnk, vga_in.vblnk, 
        bg_color, in_d_text, in_p1_text, in_p2_text, in_m1_text, in_m2_text, char_x_bit
    };

    logic [10:0] d_hcount, d_vcount;
    logic d_hsync, d_vsync, d_hblnk, d_vblnk;
    logic [11:0] d_bg_color;
    logic d_in_d_text, d_in_p1_text, d_in_p2_text, d_in_m1_text, d_in_m2_text;
    logic [2:0] d_char_x_bit;

    assign {
        d_hcount, d_vcount, d_hsync, d_vsync, d_hblnk, d_vblnk, 
        d_bg_color, d_in_d_text, d_in_p1_text, d_in_p2_text, d_in_m1_text, d_in_m2_text, d_char_x_bit
    } = delay_out;

    delay #(.WIDTH(DEL_W), .CLK_DEL(1)) u_delay (
        .clk(clk), .rst_n(rst_n), .din(delay_in), .dout(delay_out)
    );

    // --- 4. Final paintbrush ---
    logic [10:0] out_hcount, out_vcount;
    logic        out_hsync, out_vsync, out_hblnk, out_vblnk;
    logic [11:0] out_rgb;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_hcount <= '0; out_vcount <= '0; out_hsync <= '0;
            out_vsync <= '0; out_hblnk <= '0; out_vblnk <= '0; out_rgb <= '0;
        end else begin
            out_hcount <= d_hcount; out_vcount <= d_vcount;
            out_hsync <= d_hsync; out_vsync <= d_vsync;
            out_hblnk <= d_hblnk; out_vblnk <= d_vblnk;

            if (d_in_d_text || d_in_p1_text || d_in_p2_text) begin
                if (rom_pixels[7 - d_char_x_bit]) out_rgb <= 12'hf_f_f; 
                else out_rgb <= d_bg_color; 
            end 
            else if (d_in_m1_text || d_in_m2_text) begin
                if (rom_pixels[7 - d_char_x_bit]) out_rgb <= 12'h0_f_0; 
                else out_rgb <= d_bg_color;
            end 
            else begin
                out_rgb <= d_bg_color;
            end
        end
    end

    assign vga_out.hcount = out_hcount;
    assign vga_out.vcount = out_vcount;
    assign vga_out.hsync  = out_hsync;
    assign vga_out.vsync  = out_vsync;
    assign vga_out.hblnk  = out_hblnk;
    assign vga_out.vblnk  = out_vblnk;
    assign vga_out.rgb    = out_rgb;

endmodule