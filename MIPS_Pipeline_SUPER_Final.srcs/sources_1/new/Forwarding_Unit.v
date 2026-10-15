`timescale 1ns / 1ps

module Forwarding_Unit (
    input  wire [4:0] rsE,
    input  wire [4:0] rtE,
    input  wire [4:0] write_regM,
    input  wire [4:0] write_regW,
    input  wire       reg_writeM,
    input  wire       reg_writeW,
    
    output reg  [1:0] forwardAE,
    output reg  [1:0] forwardBE
);

    always @(*) begin
        // Standard operational reference defaults: default to Register File inputs [cite: 131]
        forwardAE = 2'b00;
        forwardBE = 2'b00;

        // ----------------- EX HAZARD (FORWARD FROM MEM STAGE) -----------------
        // Highest priority execution matching MIPS structural rules 
        if (reg_writeM && (write_regM != 5'b0) && (write_regM == rsE)) begin
            forwardAE = 2'b10;
        end 
        // ----------------- MEM HAZARD (FORWARD FROM WB STAGE) -----------------
        // Only forward from WB if there is no active overlapping forward from the closer MEM stage
        else if (reg_writeW && (write_regW != 5'b0) && (write_regW == rsE)) begin
            forwardAE = 2'b01;
        end

        // ----------------- EX HAZARD (FORWARD FROM MEM STAGE) -----------------
        if (reg_writeM && (write_regM != 5'b0) && (write_regM == rtE)) begin
            forwardBE = 2'b10;
        end 
        // ----------------- MEM HAZARD (FORWARD FROM WB STAGE) -----------------
        else if (reg_writeW && (write_regW != 5'b0) && (write_regW == rtE)) begin
            forwardBE = 2'b01;
        end
    end
endmodule