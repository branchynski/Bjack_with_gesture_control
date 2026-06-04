module top_vga_tb;

    timeunit 1ns;
    timeprecision 1ps;

    /**
     * Local parameters
     */
    
    localparam real CLK_PERIOD = 15.385;     
    localparam RST_START_TIME = 30;
    localparam RST_ACTIVE_TIME = 30;

    /**
     * Local variables and signals
     */
    logic clk, rst_n;
    logic btn_start;
    logic btn_hit;
    logic btn_stand;
    wire vs, hs;
    wire [3:0] r, g, b;
    wire tb_ps2_clk, tb_ps2_data;
    logic clk_100MHz = 0;

    /**
     * Clock generation
     */
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2.0) clk = ~clk;
    end

    initial begin
        clk_100MHz = 1'b0;
        forever #5 clk_100MHz = ~clk_100MHz; 
    end

    /**
     * Submodules instances
     */
    top_vga dut (
        .clk(clk),
        .rst_n(rst_n),
        .btn_start(btn_start),
        .btn_hit(btn_hit),
        .btn_stand(btn_stand),
        .vs(vs),
        .hs(hs),
        .r(r),
        .g(g),
        .b(b),
        .ps2_clk(tb_ps2_clk),
        .ps2_data(tb_ps2_data),
        .clk_100MHz(clk_100MHz)
    );

    
    tiff_writer #(
        .XDIM(16'd1344),
        .YDIM(16'd806),
        .FILE_DIR("../../results")
    ) u_tiff_writer (
        .clk(clk),
        .r({r,r}), 
        .g({g,g}), 
        .b({b,b}), 
        .go(vs)
    );

    /**
     * Main test
     */
    initial begin
        
        btn_start = 1'b0;
        btn_hit   = 1'b0;
        btn_stand = 1'b0;
        
        
        rst_n = 1'b1;
        #(RST_START_TIME) rst_n = 1'b0;
        #(RST_ACTIVE_TIME) rst_n = 1'b1;

        $display("--------------------------------------------------");
        $display("MULTIPLAYER BLACKJACK - VGA SIMULATION STARTED");
        $display("Prepare to wait a long time...");
        $display("--------------------------------------------------");

        #100;

        // 4. ROZDANIE POCZĄTKOWE (START)
        $display("[%0t ns] Wciskanie przycisku START", $time);
        btn_start = 1'b1;
        #(5 * CLK_PERIOD); 
        btn_start = 1'b0;  

        // Czekamy na wygenerowanie pierwszej klatki (6 kart na stole)
        wait (vs == 1'b0);
        @(negedge vs) $display("[%0t ns] Ramka 1 - Zapisana (Widać 6 kart: P0, P1, Krupier)", $time);

        // 5. RUCH GRACZA 0 (HIT - Dobiera kartę)
        $display("[%0t ns] Gracz 0 wciska HIT!", $time);
        btn_hit = 1'b1;
        #(5 * CLK_PERIOD); 
        btn_hit = 1'b0; 

        // Czekamy na wygenerowanie drugiej klatki (Gracz 0 ma teraz 3 karty)
        @(negedge vs) $display("[%0t ns] Ramka 2 - Zapisana (Gracz 0 dobrał 3. kartę)", $time);

        // 6. RUCH GRACZA 0 (STAND - Oddaje turę Gracza 1)
        $display("[%0t ns] Gracz 0 wciska STAND!", $time);
        btn_stand = 1'b1;
        #(5 * CLK_PERIOD); 
        btn_stand = 1'b0; 

        // Czekamy na wygenerowanie trzeciej klatki (Układ czeka na UART Gracza 1)
        @(negedge vs) $display("[%0t ns] Ramka 3 - Zapisana (Oczekiwanie na ruch Gracza 1)", $time);
        @(posedge vs);

        // End the simulation.
        $display("--------------------------------------------------");
        $display("Simulation is over! Check your results folder for TIFFs.");
        $finish;
    end

endmodule