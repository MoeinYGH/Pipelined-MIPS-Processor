`timescale 1ns / 1ps

module RegisterFile (
    input  [4:0]  rs,
    input  [4:0]  rt,
    input  [4:0]  rd,
    input  [31:0] WriteData,
    input         regWrite,
    input         clk,
    input         rst,
    output [31:0] regA,
    output [31:0] regB
);

    reg [31:0] regArray [31:0];
    integer i;

    // Internal Transparent Forwarding: If reading the same register being written to 
    // in this cycle, forward the WriteData immediately to prevent data stall slots.
    assign regA = (rs == 5'b0) ? 32'b0 : ((regWrite && (rd == rs)) ? WriteData : regArray[rs]);
    assign regB = (rt == 5'b0) ? 32'b0 : ((regWrite && (rd == rt)) ? WriteData : regArray[rt]);

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regArray[i] <= 32'b0;
        end else if (regWrite && (rd != 5'd0)) begin
            regArray[rd] <= WriteData;
        end
    end

endmodule