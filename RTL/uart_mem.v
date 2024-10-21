module uart_controller (
    input wire clk,
    input wire rst,
    input wire rx,
    output reg tx,
    input wire [7:0] tx_data,
    input wire tx_start,
    output reg tx_done,
    output reg [7:0] rx_data,
    output reg rx_done
);

    // Parameters
    parameter CLKS_PER_BIT = 87; // For 115200 baud rate with 10MHz clock
    parameter MEM_SIZE = 256;    // Memory size for storing received data

    // Internal signals
    reg [7:0] tx_data_reg;
    reg [3:0] tx_state;
    reg [6:0] tx_clk_count;
    reg [2:0] tx_bit_index;

    reg [3:0] rx_state;
    reg [6:0] rx_clk_count;
    reg [2:0] rx_bit_index;
    reg [7:0] rx_data_reg;

    // Memory-related signals
    reg [7:0] mem [0:MEM_SIZE-1];  // Memory array for storing received data
    reg [7:0] mem_write_addr;       // Address for writing to memory
    reg mem_write_enable;           // Memory write enable signal

    // States
    localparam IDLE = 4'b0000;
    localparam START_BIT = 4'b0001;
    localparam DATA_BITS = 4'b0010;
    localparam STOP_BIT = 4'b0011;

    // TX Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_state <= IDLE;
            tx <= 1'b1;
            tx_done <= 1'b0;
        end else begin
            case (tx_state)
                IDLE: begin
                    tx <= 1'b1;
                    tx_clk_count <= 0;
                    tx_bit_index <= 0;
                    tx_done <= 1'b0;
                    if (tx_start) begin
                        tx_state <= START_BIT;
                        tx_data_reg <= tx_data;
                    end
                end
                START_BIT: begin
                    tx <= 1'b0;
                    if (tx_clk_count < CLKS_PER_BIT - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_clk_count <= 0;
                        tx_state <= DATA_BITS;
                    end
                end
                DATA_BITS: begin
                    tx <= tx_data_reg[tx_bit_index];
                    if (tx_clk_count < CLKS_PER_BIT - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_clk_count <= 0;
                        if (tx_bit_index < 7) begin
                            tx_bit_index <= tx_bit_index + 1;
                        end else begin
                            tx_state <= STOP_BIT;
                        end
                    end
                end
                STOP_BIT: begin
                    tx <= 1'b1;
                    if (tx_clk_count < CLKS_PER_BIT - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_done <= 1'b1;
                        tx_state <= IDLE;
                    end
                end
            endcase
        end
    end

    // RX Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_state <= IDLE;
            rx_done <= 1'b0;
            rx_data <= 8'h00;
            mem_write_addr <= 8'h00;
            mem_write_enable <= 1'b0;
        end else begin
            case (rx_state)
                IDLE: begin
                    rx_done <= 1'b0;
                    rx_clk_count <= 0;
                    rx_bit_index <= 0;
                    mem_write_enable <= 1'b0;
                    if (rx == 1'b0) // Start bit detected
                        rx_state <= START_BIT;
                end
                START_BIT: begin
                    if (rx_clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (rx == 1'b0) begin
                            rx_clk_count <= 0;
                            rx_state <= DATA_BITS;
                        end else
                            rx_state <= IDLE;
                    end else
                        rx_clk_count <= rx_clk_count + 1;
                end
                DATA_BITS: begin
                    if (rx_clk_count < CLKS_PER_BIT - 1) begin
                        rx_clk_count <= rx_clk_count + 1;
                    end else begin
                        rx_clk_count <= 0;
                        rx_data_reg[rx_bit_index] <= rx;
                        if (rx_bit_index < 7)
                            rx_bit_index <= rx_bit_index + 1;
                        else
                            rx_state <= STOP_BIT;
                    end
                end
                STOP_BIT: begin
                    if (rx_clk_count < CLKS_PER_BIT - 1) begin
                        rx_clk_count <= rx_clk_count + 1;
                    end else begin
                        rx_done <= 1'b1;
                        rx_data <= rx_data_reg;

                        // Store the received data into memory
                        mem[mem_write_addr] <= rx_data_reg;
                        mem_write_enable <= 1'b1;

                        // Increment the write address
                        if (mem_write_addr < MEM_SIZE - 1) begin
                            mem_write_addr <= mem_write_addr + 1;
                        end else begin
                            mem_write_addr <= 0; // Wrap around if memory is full
                        end
                        
                        rx_state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
