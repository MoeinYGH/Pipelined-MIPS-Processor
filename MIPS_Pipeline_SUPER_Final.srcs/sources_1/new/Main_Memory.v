`timescale 1ns / 1ps

module Main_Memory (
    input  wire         clk,
    input  wire         rst,
    input  wire         mem_read,
    input  wire         mem_write,
    input  wire  [31:0] mem_addr,
    input  wire  [127:0] mem_write_data,
    output reg   [127:0] mem_read_data,
    output reg          mem_ready
);

    localparam BLOCK_SIZE_BYTES = 16;
    localparam BLOCK_COUNT = 1024;       
    localparam LATENCY_CYCLES = 50;       // Strict mandated 50-cycle DRAM penalty
    
    reg [127:0] memory [0:BLOCK_COUNT-1];
    reg [7:0]   delay_counter;           // Expanded to 8-bit to comfortably hold 50
    reg         busy;                    

    wire [31:0] block_addr = (mem_addr >> 4) % BLOCK_COUNT; 

    integer i;
    initial begin
        for (i = 0; i < BLOCK_COUNT; i = i + 1) begin
            memory[i] = 128'b0;
        end
        // Corrected Instruction Block
        memory[0] = {32'hac040010, 32'h00432020, 32'h20030003, 32'h20020005};
        
        // Wipe block 1 clean so it doesn't execute rogue instructions!
        memory[1] = 128'b0; 
    end

    always @(posedge clk) begin
        if (rst) begin
            mem_ready     <= 1'b0;
            mem_read_data <= 128'b0;
            delay_counter <= 8'b0;
            busy          <= 1'b0;
        end else begin
            if (!busy) begin
                if (mem_read || mem_write) begin
                    busy          <= 1'b1;
                    delay_counter <= LATENCY_CYCLES - 1;
                    mem_ready     <= 1'b0;
                end else begin
                    mem_ready     <= 1'b0;
                end
            end else begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                    mem_ready     <= 1'b0;
                end else begin
                    // Exactly on the 50th cycle, perform the operation and flag ready
                    busy      <= 1'b0;
                    mem_ready <= 1'b1;
                    if (mem_read) begin
                        mem_read_data <= memory[block_addr];
                    end else if (mem_write) begin
                        memory[block_addr] <= mem_write_data;
                    end
                end
            end
        end
    end

endmodule