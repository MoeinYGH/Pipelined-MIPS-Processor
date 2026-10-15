`timescale 1ns / 1ps

module IF_ID_reg (
    input             clk, 
    input             rst,
    input             stallD,      // Stall from Hazard Unit
    input             flushD,      // Flush from Hazard Unit (Control Hazards)
    input             cache_stall, // Global stall from Cache Controller
    input      [31:0] pc_plus4F,
    input      [31:0] instrF,
    output reg [31:0] pc_plus4D,
    output reg [31:0] instrD
);

    always @(posedge clk) begin
        if (rst) begin
            pc_plus4D <= 32'b0;
            instrD    <= 32'b0;
        end else if (cache_stall) begin
            // Top Priority Rule: Completely freeze pipeline progression
            pc_plus4D <= pc_plus4D;
            instrD    <= instrD;
        end else if (flushD) begin
            // Squashing instructions on mispredicted/taken branches
            pc_plus4D <= 32'b0;
            instrD    <= 32'b0;
        end else if (!stallD) begin
            pc_plus4D <= pc_plus4F;
            instrD    <= instrF;
        end
        // If stallD is 1, hold values (implied)
    end
    
endmodule