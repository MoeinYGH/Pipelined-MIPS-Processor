`timescale 1ns / 1ps

module ID_EX_reg (
    input             clk, 
    input             rst,
    input             flushE,       // Clears controls (injects bubbles) [cite: 40]
    input             cache_stall,  // Global cache stall taking absolute priority 
    input      [31:0] reg_data1D,
    input      [31:0] reg_data2D,
    input      [31:0] sign_ext_immD,
    input      [4:0]  rsD, rtD, rdD,
    input      [2:0]  alu_opD,
    input             alu_srcD,
    input             reg_dstD,
    input             mem_readD,
    input             mem_writeD,
    input             branchD,
    input             reg_writeD,
    input             mem_to_regD,
    input      [31:0] pc_plus4D,
    input      [5:0]  functD,
    
    output reg [31:0] pc_plus4E,
    output reg [5:0]  functE,
    output reg [31:0] reg_data1E,
    output reg [31:0] reg_data2E,
    output reg [31:0] sign_ext_immE,
    output reg [4:0]  rsE, rtE, rdE,
    output reg [2:0]  alu_opE,
    output reg        alu_srcE,
    output reg        reg_dstE,
    output reg        mem_readE,
    output reg        mem_writeE,
    output reg        branchE,
    output reg        reg_writeE,
    output reg        mem_to_regE
);

    // Synchronous state transitions matching structural guidelines [cite: 193, 194]
    always @(posedge clk) begin
        if (rst) begin
            reg_data1E    <= 32'b0;
            reg_data2E    <= 32'b0;
            sign_ext_immE <= 32'b0;
            rsE           <= 5'b0;
            rtE           <= 5'b0;
            rdE           <= 5'b0;
            alu_opE       <= 3'b0;
            alu_srcE      <= 1'b0;
            reg_dstE      <= 1'b0;
            mem_readE     <= 1'b0;
            mem_writeE    <= 1'b0;
            branchE       <= 1'b0;
            reg_writeE    <= 1'b0;
            mem_to_regE   <= 1'b0;
            pc_plus4E     <= 32'b0;
            functE        <= 6'b0;
        end else if (cache_stall) begin
            // Rule 5: Keep current outputs entirely intact during memory hazard resolving 
            reg_data1E    <= reg_data1E;
            reg_data2E    <= reg_data2E;
            sign_ext_immE <= sign_ext_immE;
            rsE           <= rsE;
            rtE           <= rtE;
            rdE           <= rdE;
            alu_opE       <= alu_opE;
            alu_srcE      <= alu_srcE;
            reg_dstE      <= reg_dstE;
            mem_readE     <= mem_readE;
            mem_writeE    <= mem_writeE;
            branchE       <= branchE;
            reg_writeE    <= reg_writeE;
            mem_to_regE   <= mem_to_regE;
            pc_plus4E     <= pc_plus4E;
            functE        <= functE;
        end else if (flushE) begin
            // Injects a execution bubble clearing control lanes [cite: 40, 144]
            reg_data1E    <= 32'b0;
            reg_data2E    <= 32'b0;
            sign_ext_immE <= 32'b0;
            rsE           <= 5'b0;
            rtE           <= 5'b0;
            rdE           <= 5'b0;
            alu_opE       <= 3'b0;
            alu_srcE      <= 1'b0;
            reg_dstE      <= 1'b0;
            mem_readE     <= 1'b0;
            mem_writeE    <= 1'b0;
            branchE       <= 1'b0;
            reg_writeE    <= 1'b0;
            mem_to_regE   <= 1'b0;
            pc_plus4E     <= 32'b0;
            functE        <= 6'b0;
        end else begin
            reg_data1E    <= reg_data1D;
            reg_data2E    <= reg_data2D;
            sign_ext_immE <= sign_ext_immD;
            rsE           <= rsD;
            rtE           <= rtD;
            rdE           <= rdD;
            alu_opE       <= alu_opD;
            alu_srcE      <= alu_srcD;
            reg_dstE      <= reg_dstD;
            mem_readE     <= mem_readD;
            mem_writeE    <= mem_writeD;
            branchE       <= branchD;
            reg_writeE    <= reg_writeD;
            mem_to_regE   <= mem_to_regD;
            pc_plus4E     <= pc_plus4D;
            functE        <= functD;
        end
    end
endmodule