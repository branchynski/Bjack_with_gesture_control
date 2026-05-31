module top_vga_tb;

    timeunit 1ns;
    timeprecision 1ps;

    /**
     * Local parameters
     */
    // Zmieniony okres dla zegara 65 MHz (rozdzielczość 1024x768)
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

    // Zaktualizowane wymiary całkowite (Total Time) dla 1024x768
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
        // 1. Inicjalizacja sygnałów (likwidujemy stan 'X')
        btn_start = 1'b0;
        btn_hit   = 1'b0;
        btn_stand = 1'b0;
        
        // 2. Sekwencja resetu układu
        rst_n = 1'b1;
        #(RST_START_TIME) rst_n = 1'b0;
        #(RST_ACTIVE_TIME) rst_n = 1'b1;

        $display("If simulation ends before the testbench");
        $display("completes, use the menu option to run all.");
        $display("Prepare to wait a long time...");

        // 3. Czekamy chwilę po resecie na ustabilizowanie układu
        #100;

        // 4. SYMULUJEMY WCIŚNIĘCIE PRZYCISKU "START"
        $display("Info: Wciskanie przycisku START w czasie %t", $time);
        btn_start = 1'b1;
        #(5 * CLK_PERIOD); // Trzymamy wciśnięty przez 5 taktów zegara wideo
        btn_start = 1'b0;  // Puszczamy przycisk

        // W tym momencie FSM budzi się z IDLE, uruchamia Datapath i rozdaje 4 karty.

        // 5. Czekamy na wygenerowanie klatek
        wait (vs == 1'b0);
        @(negedge vs) $display("Info: negedge VS at %t (Ramka 1 - inicjalizacja)", $time);
        @(negedge vs) $display("Info: negedge VS at %t (Ramka 2 - karty lądują na stole)", $time);
        @(negedge vs) $display("Info: negedge VS at %t (Ramka 3 - finalny obraz)", $time);

        // End the simulation.
        $display("Simulation is over, check the waveforms and TIFFs.");
        $finish;
    end

endmodule