`timescale 1ns / 1ps

module L2_Cache (
    input  wire         clk,
    input  wire         rst,
    // Request interface
    input  wire         l2_req,
    input  wire         l2_is_write,
    input  wire  [31:0] address,
    input  wire  [127:0] write_block_from_l1,
    
    // Main Memory interface
    input  wire  [127:0] main_mem_block,     
    input  wire         main_mem_ready,      
    output reg   [31:0] main_mem_address,    
    output reg   [127:0] main_mem_write_block,
    output reg          main_mem_read,       
    output reg          main_mem_write,      
    
    // Response interface
    output reg   [127:0] read_block_to_l1,
    output reg          l2_done,
    output reg          l2_miss
);

    // L2 Cache parameters: 64 blocks, each 128 bits (16 bytes)
    reg [127:0] cache_data [0:63];
    reg [21:0]  cache_tags [0:63];
    reg         valid_bits [0:63];
    reg         dirty_bits [0:63];

    wire [21:0] current_tag   = address[31:10];
    wire [5:0]  current_index = address[9:4];

    // State machine
    localparam S_IDLE        = 3'b000;
    localparam S_CHECK_HIT   = 3'b001;
    localparam S_WRITEBACK   = 3'b010;
    localparam S_ALLOCATE    = 3'b011;
    localparam S_RESPOND     = 3'b100;
    
    reg [2:0] current_state, next_state;
    reg       internal_miss;
    reg       need_writeback;

    integer i;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state;
        l2_done = 1'b0;
        l2_miss = 1'b0;
        main_mem_read = 1'b0;
        main_mem_write = 1'b0;
        main_mem_address = address;
        main_mem_write_block = cache_data[current_index];
        read_block_to_l1 = cache_data[current_index];
        need_writeback = 1'b0;
        internal_miss = 1'b0;

        case (current_state)
            S_IDLE: begin
                if (l2_req) begin
                    next_state = S_CHECK_HIT;
                end
            end

            S_CHECK_HIT: begin
                if (valid_bits[current_index] && (cache_tags[current_index] == current_tag)) begin
                    // HIT!
                    l2_miss = 1'b0;
                    internal_miss = 1'b0;
                    read_block_to_l1 = cache_data[current_index];
                    
                    if (l2_is_write) begin
                        // Write hit: update cache
                        // Sequential block handles this
                    end
                    
                    // Signal completion immediately
                    next_state = S_RESPOND;
                end else begin
                    // MISS!
                    l2_miss = 1'b1;
                    internal_miss = 1'b1;
                    
                    if (valid_bits[current_index] && dirty_bits[current_index]) begin
                        need_writeback = 1'b1;
                        next_state = S_WRITEBACK;
                    end else begin
                        next_state = S_ALLOCATE;
                    end
                end
            end

            S_WRITEBACK: begin
                main_mem_write = 1'b1;
                main_mem_address = {cache_tags[current_index], current_index, 4'b0000};
                main_mem_write_block = cache_data[current_index];
                
                if (main_mem_ready) begin
                    next_state = S_ALLOCATE;
                end
            end

            S_ALLOCATE: begin
                main_mem_read = 1'b1;
                main_mem_address = {current_tag, current_index, 4'b0000};
                
                if (main_mem_ready) begin
                    // Update cache in sequential block
                    next_state = S_RESPOND;
                end
            end

            S_RESPOND: begin
                // Signal completion for one cycle
                l2_done = 1'b1;
                l2_miss = internal_miss;
                read_block_to_l1 = cache_data[current_index];
                
                if (!l2_req) begin
                    next_state = S_IDLE;
                end
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Sequential updates
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 64; i = i + 1) begin
                valid_bits[i] <= 1'b0;
                dirty_bits[i] <= 1'b0;
                cache_tags[i] <= 22'b0;
                cache_data[i] <= 128'b0;
            end
        end else begin
            case (current_state)
                S_CHECK_HIT: begin
                    if (valid_bits[current_index] && (cache_tags[current_index] == current_tag)) begin
                        // Hit: Handle write
                        if (l2_is_write) begin
                            cache_data[current_index] <= write_block_from_l1;
                            dirty_bits[current_index] <= 1'b1;
                        end
                    end
                end

                S_ALLOCATE: begin
                    if (main_mem_ready) begin
                        cache_data[current_index] <= main_mem_block;
                        cache_tags[current_index] <= current_tag;
                        valid_bits[current_index] <= 1'b1;
                        dirty_bits[current_index] <= 1'b0;
                    end
                end

                S_WRITEBACK: begin
                    if (main_mem_ready) begin
                        dirty_bits[current_index] <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule