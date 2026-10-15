`timescale 1ns / 1ps

module PC(
    input [31:0] pc_in,
    input clk,
    input rst,
    input stallF,        // Stall signal from Hazard Unit
    input cache_stall,   // Global stall from Cache Controller
    output reg [31:0] pc_out
);

    always @(posedge clk) begin
        if (rst) begin
            pc_out <= 32'b0;
        end else if (cache_stall) begin
            // Highest priority: Freeze absolute state during a cache miss
            pc_out <= pc_out;
        end else if (!stallF) begin
            pc_out <= pc_in;
        end
        // If stallF is 1, pc_out holds its value (implied by not updating)
    end

endmodule