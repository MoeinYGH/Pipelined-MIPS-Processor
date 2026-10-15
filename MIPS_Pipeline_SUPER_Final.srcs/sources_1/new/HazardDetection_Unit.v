`timescale 1ns / 1ps

module HazardDetection_Unit (
    input  wire [4:0] rsD,
    input  wire [4:0] rtD,
    input  wire        branch_takenD, 
    input  wire [4:0] rtE,
    input  wire        mem_to_regE,   
    input  wire        cache_stall,   
    output reg         stallF,        
    output reg         stallD,        
    output reg         flushD,        
    output reg         flushE,        
    output reg         pipeline_cache_stall 
);

    always @(*) begin
        // Baseline Defaults
        stallF               = 1'b0;
        stallD               = 1'b0;
        flushD               = 1'b0;
        flushE               = 1'b0;
        pipeline_cache_stall = 1'b0;

        // ----------------- PRIORITY 1: CACHE SYSTEM MISS STALL -----------------
        if (cache_stall) begin
            stallF               = 1'b1;
            stallD               = 1'b1;
            pipeline_cache_stall = 1'b1; 
            flushE               = 1'b0; 
            flushD               = 1'b0;
        end
        // ----------------- PRIORITY 2: LOAD-USE DATA HAZARD INTERLOCK ----------
        else if (mem_to_regE && (rtE != 5'b0) && ((rtE == rsD) || (rtE == rtD))) begin
            stallF = 1'b1;
            stallD = 1'b1;
            flushE = 1'b1; // Inject bubble into EX stage
        end
        // ----------------- PRIORITY 3: CONTROL HAZARD (BRANCH TAKEN) -----------
        else if (branch_takenD) begin
            flushD = 1'b1;
            flushE = 1'b1;  // ADD THIS: Also flush EX stage on branch
        end
    end
endmodule