`timescale 1ns / 1ps

module async_fifo_tb;

    //-- Parameters for clock generation
    parameter WR_CLK_PERIOD = 10.0; // 100 MHz write clock
    parameter RD_CLK_PERIOD = 12.5; // 80 MHz read clock

    //-- Testbench signals
    reg  wr_clk;
    reg  rd_clk;
    reg  wr_rst;
    reg  rd_rst;
    reg  wr_en;
    reg  rd_en;
    reg  [7:0] fifo_in;
    
    wire [7:0] fifo_out;
    wire fifo_full;
    wire fifo_empty;

    //-- Scoreboard for data verification (Implemented in standard Verilog)
    reg [7:0] scoreboard_mem [0:127]; // A fixed-size memory for verification
    reg [6:0] scoreboard_head;        // Pointer to read from scoreboard
    reg [6:0] scoreboard_tail;        // Pointer to write to scoreboard
    integer   error_count;
    reg [7:0] expected_data;

    //-- Instantiate the DUT (Device Under Test)
    async_fifo dut (
        .rd_clk(rd_clk),
        .wr_clk(wr_clk),
        .wr_rst(wr_rst),
        .rd_rst(rd_rst),
        .rd_en(rd_en),
        .wr_en(wr_en),
        .fifo_in(fifo_in),
        .fifo_out(fifo_out),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty)
    );

    //-- Clock Generators
    initial begin
        wr_clk = 0;
        forever #(WR_CLK_PERIOD / 2) wr_clk = ~wr_clk;
    end

    initial begin
        rd_clk = 0;
        forever #(RD_CLK_PERIOD / 2) rd_clk = ~rd_clk;
    end

    //-- Main Test Sequence
    initial begin
        $display("----------------------------------------------------");
        $display("Starting Final Asynchronous FIFO Testbench...");
        $display("----------------------------------------------------");

        // Initialize scoreboard pointers and error count
        scoreboard_head = 0;
        scoreboard_tail = 0;
        error_count = 0;

        // 1. Apply Reset
        wr_rst = 1;
        rd_rst = 1;
        wr_en = 0;
        rd_en = 0;
        fifo_in = 8'h00;
        repeat (5) @(posedge wr_clk);
        wr_rst = 0;
        rd_rst = 0;
        $display("[%0t] Reset released.", $time);
        
        // 2. Test Case: Fill the FIFO
        $display("[%0t] Test Case 1: Filling the FIFO to capacity.", $time);
        for (integer i = 0; i < 64; i = i + 1) begin
            @(posedge wr_clk);
            #1;
            wr_en <= 1;
            fifo_in <= i;
            scoreboard_mem[scoreboard_tail] = i; 
            scoreboard_tail = scoreboard_tail + 1;
            
            @(posedge wr_clk);
            #1;
            wr_en <= 0;
        end
        
        repeat (5) @(posedge wr_clk);
        if (fifo_full) $display("PASS: FIFO is full.");
        else begin $display("FAIL: FIFO should be full."); error_count = error_count + 1; end

        // 3. Test Case: Overflow check
        $display("[%0t] Test Case 2: Attempting to overflow the FIFO.", $time);
        @(posedge wr_clk); #1; wr_en <= 1; fifo_in <= 8'hFF; 
        @(posedge wr_clk); #1; wr_en <= 0;
        @(posedge wr_clk);
        if (fifo_full) $display("PASS: Overflow prevented.");
        else begin $display("FAIL: Overflow not prevented."); error_count = error_count + 1; end
        
        // 4. Test Case: Empty the FIFO and verify data
        $display("[%0t] Test Case 3: Emptying the FIFO and checking data.", $time);
        @(posedge rd_clk); // Wait for first data to be available
        for (integer i = 0; i < 64; i = i + 1) begin
            // **DEFINITIVE FIX**: Create a single-cycle read transaction
            @(posedge rd_clk);
            #1;
            rd_en <= 1;

            @(posedge rd_clk);
            #1;
            expected_data = scoreboard_mem[scoreboard_head];
            scoreboard_head = scoreboard_head + 1;
            if (fifo_out !== expected_data) begin
                $display("FAIL: Data Mismatch! Expected %h, Got %h", expected_data, fifo_out);
                error_count = error_count + 1;
            end
            rd_en <= 0;
        end
        $display("PASS: All 64 values read back correctly.");
        
        repeat(5) @(posedge rd_clk);
        if (fifo_empty) $display("PASS: FIFO is empty.");
        else begin $display("FAIL: FIFO should be empty."); error_count = error_count + 1; end

        // Final summary
        $display("----------------------------------------------------");
        if (error_count == 0)
            $display("SUCCESS: All tests passed!");
        else
            $display("FAILURE: %0d errors found.", error_count);
        $display("----------------------------------------------------");
        $finish;
    end
endmodule