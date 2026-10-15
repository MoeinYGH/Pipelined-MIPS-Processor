`timescale 1ns / 1ps

module MEM_WB_reg (
    input             clk, 
    input             rst, 
    input             cache_stall,   // Global cache stall signal taking highest priority
    input      [31:0] read_dataM,
    input      [31:0] alu_resultM,
    input      [4:0]  write_regM,
    input             reg_writeM,
    input             mem_to_regM,

    output reg [31:0] read_dataW,
    output reg [31:0] alu_resultW,
    output reg [4:0]  write_regW,
    output reg        reg_writeW,
    output reg        mem_to_regW
);

    // Completely synchronous timing block to guarantee alignment
    always @(posedge clk) begin
        if (rst) begin
            read_dataW  <= 32'b0;
            alu_resultW <= 32'b0;
            write_regW  <= 5'b0;
            reg_writeW  <= 1'b0;
            mem_to_regW <= 1'b0;
        end else if (cache_stall) begin
            // Hint 5: Freeze state completely during a data/instruction cache stall
            read_dataW  <= read_dataW;
            alu_resultW <= alu_resultW;
            write_regW  <= write_regW;
            reg_writeW  <= reg_writeW;
            mem_to_regW <= mem_to_regW;
        end else begin
            // Normal operational pipeline writeback updates
            read_dataW  <= read_dataM;
            alu_resultW <= alu_resultM;
            write_regW  <= write_regM;
            reg_writeW  <= reg_writeM;
            mem_to_regW <= mem_to_regM;
        end
    end
endmodule