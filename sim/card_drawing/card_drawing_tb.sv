/********************************************************************************
 * Module Name:    card_drawing_tb
 * Author:         Eryk Rutka
 * Date:           2026-05-15
 * Version:        1.0
 * Description:    Testbench for the card_drawing LFSR module.
 ********************************************************************************/

 module card_drawing_tb();

    timeunit 1ns;
    timeprecision 1ps;

    logic clk;
    logic rst_n;
    logic card_req;
    logic [5:0] card_value;
    logic card_valid;

    card_drawing uut (
        .clk(clk),
        .rst_n(rst_n),
        .card_req(card_req),
        .card_value(card_value),
        .card_valid(card_valid)
    );

    always #5 clk = ~clk;

    initial begin
        $display("--- Starting Card Drawing Simulation ---");
        
        clk = 0;
        rst_n = 0;
        card_req = 0;

        #25;
        rst_n = 1;
        $display("[%0t ns] Reset released. LFSR is running in the background.", $time);
    
        
        for (int i = 1; i <= 10; i++) begin
            #100;

            $display("\n[%0t ns] --- DRAW %0d ---", $time, i);
            
            @(negedge clk);
            card_req = 1;
            
            @(negedge clk);
            card_req = 0;
            
            wait(card_valid == 1);
            $display("[%0t ns] Card Valid! Drawn Value: %0d", $time, card_value);
            
            if (card_value > 53) begin
                $display("ERROR: Card value %0d is out of range (0-53)!", card_value);
            end
        end

        #50;
        $display("\n--- Simulation Complete ---");
        $finish;
    end

endmodule