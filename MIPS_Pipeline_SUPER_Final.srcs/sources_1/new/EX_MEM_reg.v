`timescale 1ns / 1ps

module EX_MEM_reg (
    input             clk, 
    input             rst, 
    input             cache_stall,   // Global cache stall signal taking highest priority
    input      [31:0] alu_resultE,
    input      [31:0] write_dataE,
    input      [4:0]  write_regE,
    input             mem_readE,
    input             mem_writeE,
    input             reg_writeE,
    input             mem_to_regE,

    output reg [31:0] alu_resultM,
    output reg [31:0] write_dataM,
    output reg [4:0]  write_regM,
    output reg        mem_readM,
    output reg        mem_writeM,
    output reg        reg_writeM,
    output reg        mem_to_regM
);

    // Completely synchronous timing block to guarantee alignment
    always @(posedge clk) begin
        if (rst) begin
            alu_resultM <= 32'b0;
            write_dataM <= 32'b0;
            write_regM  <= 5'b0;
            mem_readM   <= 1'b0;
            mem_writeM  <= 1'b0;
            reg_writeM  <= 1'b0;
            mem_to_regM <= 1'b0;
        end else if (cache_stall) begin
            // Hint 5: Freeze state completely during data cache misses
            alu_resultM <= alu_resultM;
            write_dataM <= write_dataM;
            write_regM  <= write_regM;
            mem_readM   <= mem_readM;
            mem_writeM  <= mem_writeM;
            reg_writeM  <= reg_writeM;
            mem_to_regM <= mem_to_regM;
        end else begin
            // Normal operational pipeline progression
            alu_resultM <= alu_resultE;
            write_dataM <= write_dataE;
            write_regM  <= write_regE;
            mem_readM   <= mem_readE;
            mem_writeM  <= mem_writeE;
            reg_writeM  <= reg_writeE;
            mem_to_regM <= mem_to_regE;
        end
    end
endmodule