`timescale 1ns / 1ps

module ControlUnit(
    input  wire [5:0] op,
    output reg        EX_RegDst,
    output reg        EX_ALUSrc,
    output reg [2:0]  EX_ALUOp,
    output reg        ID_Branch,     // Shifted to ID stage layout per hardware map
    output reg        M_MemRead,
    output reg        M_MemWrite,
    output reg        WB_RegWrite,
    output reg        WB_MemToReg
);

    localparam OP_RTYPE = 6'b000000;
    localparam OP_LW    = 6'b100011;
    localparam OP_SW    = 6'b101011;
    localparam OP_BEQ   = 6'b000100;
    localparam OP_SLTI  = 6'b001010;
    localparam OP_ADDI  = 6'b001000;

    always @(*) begin
        // Safe Default Initialization to completely avoid latches
        EX_RegDst   = 1'b0;
        EX_ALUSrc   = 1'b0;
        EX_ALUOp    = 3'b000;
        ID_Branch   = 1'b0;
        M_MemRead   = 1'b0;
        M_MemWrite  = 1'b0;
        WB_RegWrite = 1'b0;
        WB_MemToReg = 1'b0;

        case (op)
            OP_RTYPE: begin
                EX_RegDst   = 1'b1;
                EX_ALUSrc   = 1'b0;
                EX_ALUOp    = 3'b000;
                ID_Branch   = 1'b0;
                M_MemRead   = 1'b0;
                M_MemWrite  = 1'b0;
                WB_RegWrite = 1'b1;
                WB_MemToReg = 1'b0;
            end

            OP_LW: begin
                EX_RegDst   = 1'b0;
                EX_ALUSrc   = 1'b1;
                EX_ALUOp    = 3'b011;
                ID_Branch   = 1'b0;
                M_MemRead   = 1'b1;
                M_MemWrite  = 1'b0;
                WB_RegWrite = 1'b1;
                WB_MemToReg = 1'b1;
            end

            OP_SW: begin
                EX_RegDst   = 1'b0;
                EX_ALUSrc   = 1'b1;
                EX_ALUOp    = 3'b011;
                ID_Branch   = 1'b0;
                M_MemRead   = 1'b0;
                M_MemWrite  = 1'b1;
                WB_RegWrite = 1'b0;
                WB_MemToReg = 1'b0;
            end

            OP_BEQ: begin
                EX_RegDst   = 1'b0;
                EX_ALUSrc   = 1'b0;
                EX_ALUOp    = 3'b001;
                ID_Branch   = 1'b1; // Checked right here in ID Stage
                M_MemRead   = 1'b0;
                M_MemWrite  = 1'b0;
                WB_RegWrite = 1'b0;
                WB_MemToReg = 1'b0;
            end

            OP_SLTI: begin
                EX_RegDst   = 1'b0;
                EX_ALUSrc   = 1'b1;
                EX_ALUOp    = 3'b010;
                ID_Branch   = 1'b0;
                M_MemRead   = 1'b0;
                M_MemWrite  = 1'b0;
                WB_RegWrite = 1'b1;
                WB_MemToReg = 1'b0;
            end

            OP_ADDI: begin
                EX_RegDst   = 1'b0;
                EX_ALUSrc   = 1'b1;
                EX_ALUOp    = 3'b011;
                ID_Branch   = 1'b0;
                M_MemRead   = 1'b0;
                M_MemWrite  = 1'b0;
                WB_RegWrite = 1'b1;
                WB_MemToReg = 1'b0;
            end

            default: begin
                // Explicitly preserving safely initialized defaults
                EX_RegDst   = 1'b0;
                EX_ALUSrc   = 1'b0;
                EX_ALUOp    = 3'b000;
                ID_Branch   = 1'b0;
                M_MemRead   = 1'b0;
                M_MemWrite  = 1'b0;
                WB_RegWrite = 1'b1; // Default fallback configuration safe state
                WB_MemToReg = 1'b0;
            end
        endcase
    end

endmodule