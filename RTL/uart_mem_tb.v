`include "uart_mem.v"
`timescale 1ns / 1ps

module uart_controller_tb;

    // Parameters
    parameter CLK_PERIOD = 100; // 10 MHz clock
    parameter CLKS_PER_BIT = 87;
    parameter BIT_PERIOD = CLKS_PER_BIT * CLK_PERIOD;

    // Signals
    reg clk;
    reg rst;
    reg rx;
    wire tx;
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_done;
    wire [7:0] rx_data;
    wire rx_done;

    // Instantiate the UART controller
    uart_controller #(
        .CLKS_PER_BIT(CLKS_PER_BIT),
        .MEM_SIZE(256)
    ) uut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx(tx),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_done(tx_done),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    // Clock generation
    always begin
        clk = 0;
        #(CLK_PERIOD/2);
        clk = 1;
        #(CLK_PERIOD/2);
    end

    // Testbench stimulus
    initial begin
        // Initialize signals
        rst = 1;
        rx = 1;
        tx_data = 8'h00;
        tx_start = 0;

        // Reset the design
        #(CLK_PERIOD*10);
        rst = 0;
        #(CLK_PERIOD*10);

        // Test TX functionality
        tx_data = 8'hA5;
        tx_start = 1;
        #(CLK_PERIOD);
        tx_start = 0;
        
        // Wait for TX to complete
        @(posedge tx_done);
        #(BIT_PERIOD);

        // Test RX functionality
        // Send byte 8'h3C
        rx = 0; // Start bit
        #(BIT_PERIOD);
        rx = 0; #(BIT_PERIOD); // Bit 0
        rx = 0; #(BIT_PERIOD); // Bit 1
        rx = 1; #(BIT_PERIOD); // Bit 2
        rx = 1; #(BIT_PERIOD); // Bit 3
        rx = 1; #(BIT_PERIOD); // Bit 4
        rx = 1; #(BIT_PERIOD); // Bit 5
        rx = 0; #(BIT_PERIOD); // Bit 6
        rx = 0; #(BIT_PERIOD); // Bit 7
        rx = 1; #(BIT_PERIOD); // Stop bit

        // Wait for RX to complete
        @(posedge rx_done);

        // Verify received data
        if (rx_data === 8'h3C) begin
            $display("RX Test Passed: Correct data received");
        end else begin
            $display("RX Test Failed: Incorrect data received");
        end

        // Test multiple byte transmission and reception
        repeat (5) begin
            tx_data = $random;
            tx_start = 1;
            #(CLK_PERIOD);
            tx_start = 0;
            
            // Wait for TX to complete
            @(posedge tx_done);
            #(BIT_PERIOD);

            // Send a random byte to RX
            rx = 0; // Start bit
            #(BIT_PERIOD);
            repeat (8) begin
                rx = $random;
                #(BIT_PERIOD);
            end
            rx = 1; // Stop bit
            #(BIT_PERIOD);

            // Wait for RX to complete
            @(posedge rx_done);
        end

        // Finish the simulation
        #(CLK_PERIOD*100);
        $finish;
    end

    // Monitor TX output
    always @(posedge clk) begin
        if (tx_done) begin
            $display("TX completed at time %t", $time);
        end
    end

    // Monitor RX output
    always @(posedge clk) begin
        if (rx_done) begin
            $display("RX completed at time %t, Data: %h", $time, rx_data);
        end
    end
  initial begin
   $dumpfile("uart1.vcd");
   $dumpvars(0, uart_controller_tb);
   $dumpvars(1, uut.mem[0]);
  end
endmodule