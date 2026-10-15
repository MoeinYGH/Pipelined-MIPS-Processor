`timescale 1ns / 1ps

module L1_Cache (
    input  wire         clk,
    input  wire         rst,
    input  wire         mem_readM,        // Memory read control line
    input  wire         mem_writeM,       // Memory write control line
    input  wire  [31:0] addressM,         // Data address from ALU stage
    input  wire  [31:0] write_dataM,      // Register data payload to store
    input  wire  [127:0] l2_block_data,   // Refill line data from level 2
    input  wire         l2_ready,         // Allocation validation line
    output reg   [31:0] read_dataM,       // Extracted word line to writeback stage
    output reg          l1d_miss,         // Cache lookup miss indicator flag
    output reg          l1d_req,          // Request to L2 for refill
    input  wire         l1d_grant         // Grant from controller to proceed with refill
);

    // Direct-mapped array architecture: 16 slots matching 128-bit layout lines
    reg [127:0] cache_data [0:15];
    reg [23:0]  cache_tags [0:15];
    reg         valid_bits [0:15];

    wire [23:0] current_tag   = addressM[31:8];
    wire [3:0]  current_index = addressM[7:4];
    wire [1:0]  word_offset   = addressM[3:2];

    integer i;
    
    // Asynchronous reset initialization
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                valid_bits[i] <= 1'b0;
                cache_tags[i] <= 24'b0;
                cache_data[i] <= 128'b0;
            end
        end
    end

    // Combinational evaluation and request logic
    always @(*) begin
        // Default assignments
        l1d_miss  = 1'b0;
        l1d_req   = 1'b0;
        read_dataM = 32'b0;
        
        // Check if operation is valid
        if (mem_readM || mem_writeM) begin
            if (!valid_bits[current_index] || (cache_tags[current_index] != current_tag)) begin
                // Cache Miss
                l1d_miss = 1'b1;
                l1d_req  = 1'b1;
            end else begin
                // Cache Hit
                if (mem_readM) begin
                    case (word_offset)
                        2'b00: read_dataM = cache_data[current_index][31:0];
                        2'b01: read_dataM = cache_data[current_index][63:32];
                        2'b10: read_dataM = cache_data[current_index][95:64];
                        2'b11: read_dataM = cache_data[current_index][127:96];
                    endcase
                end
            end
        end
    end

    // Sequential transaction updates
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                valid_bits[i] <= 1'b0;
            end
        end else begin
            // Write hit: Store word into cache (Write-Through behavior)
            if (mem_writeM && !l1d_miss) begin
                case (word_offset)
                    2'b00: cache_data[current_index][31:0]   <= write_dataM;
                    2'b01: cache_data[current_index][63:32]  <= write_dataM;
                    2'b10: cache_data[current_index][95:64]  <= write_dataM;
                    2'b11: cache_data[current_index][127:96] <= write_dataM;
                endcase
            end
            
            // Miss handling with L2 refill
            if ((mem_readM || mem_writeM) && l1d_miss && l2_ready && l1d_grant) begin
                cache_data[current_index] <= l2_block_data;
                cache_tags[current_index] <= current_tag;
                valid_bits[current_index] <= 1'b1;
            end
        end
    end

endmodule