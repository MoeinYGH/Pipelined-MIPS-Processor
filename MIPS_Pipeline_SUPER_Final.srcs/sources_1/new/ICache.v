`timescale 1ns / 1ps

module ICache (
    input  wire         clk,
    input  wire         rst,
    input  wire  [31:0] addressF,         // From Program Counter
    input  wire  [127:0] l2_block_data,   // 16-byte block from unified L2
    input  wire         l2_ready,         // Asserted when L2 has finished fetching
    output reg   [31:0] instructionF,     // Decoded instruction to pipeline
    output reg          l1i_miss,         // Signal mismatch directly to controller
    output reg          l1i_req,          // Request to L2 for refill
    input  wire         l1i_grant         // Grant from controller to proceed with refill
);

    // Direct-mapped architecture: 16 blocks, each 16 bytes (128 bits) wide
    reg [127:0] cache_data [0:15];
    reg [23:0]  cache_tags [0:15];
    reg         valid_bits [0:15];

    // Address Breakdown: [31:8] Tag (24 bits) | [7:4] Index (4 bits) | [3:2] Word Offset (2 bits)
    wire [23:0] current_tag   = addressF[31:8];
    wire [3:0]  current_index = addressF[7:4];
    wire [1:0]  word_offset   = addressF[3:2];

    integer i;
    
    // Asynchronous reset initialization
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                valid_bits[i] <= 1'b0;
                cache_tags[i] <= 24'b0;
                cache_data[i] <= 128'b0;
            end
            
            // Load hardcoded test program
            valid_bits[0] <= 1'b1;
            cache_tags[0] <= 24'b0; // Matches PC addresses starting with 24'h000000
            cache_data[0] <= {32'hac040010, 32'h00432020, 32'h20030003, 32'h20020005};
            
            valid_bits[1] <= 1'b1;
            cache_tags[1] <= 24'b0;
            cache_data[1] <= 128'b0; // NOPs for addresses 0x10-0x1F
        end
    end

    // Combinational lookup and request logic
    always @(*) begin
        // Default assignments
        l1i_miss  = 1'b0;
        l1i_req   = 1'b0;
        instructionF = 32'b0;
        
        // Check if the current index is valid and tag matches
        if (valid_bits[current_index] && (cache_tags[current_index] == current_tag)) begin
            // Cache Hit - Extract the instruction
            case (word_offset)
                2'b00: instructionF = cache_data[current_index][31:0];
                2'b01: instructionF = cache_data[current_index][63:32];
                2'b10: instructionF = cache_data[current_index][95:64];
                2'b11: instructionF = cache_data[current_index][127:96];
            endcase
        end else begin
            // Cache Miss - Request refill
            l1i_miss = 1'b1;
            l1i_req  = 1'b1;
            instructionF = 32'b0; // Bubble during miss
        end
    end

    // Synchronous memory block updates on L2 response
    always @(posedge clk) begin
        if (l1i_miss && l2_ready && l1i_grant) begin
            cache_data[current_index] <= l2_block_data;
            cache_tags[current_index] <= current_tag;
            valid_bits[current_index] <= 1'b1;
        end
    end

endmodule