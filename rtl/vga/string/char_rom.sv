/**
 * Module name: char_rom
 * Author:        Bartłomiej Raczyński
 * Version:       1.0
 * Last modified: 2026-05-31
 * Description:   Character ROM module that maps string text into character codes for rendering.
 */

module char_rom #(
    parameter string TEXT = "Test"
)(
    input  logic [7:0] char_xy,
    output logic [6:0] char_code
);

    logic [7:0] rom [0:255];

    initial begin
        for (int i = 0; i < 256; i++) begin
            if (i < TEXT.len()) begin
                rom[i] = TEXT[i]; // Copy character from string
            end else begin
                rom[i] = 8'h00;   // Fill the rest with transparency
            end
        end
    end

    assign char_code = rom[char_xy][6:0];

endmodule