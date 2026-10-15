`timescale 1ns / 1ps

module Cache_Controller (
    input  wire         clk,
    input  wire         rst,
    input  wire         l1i_miss,        
    input  wire         l1d_miss,        
    input  wire         l2_done,         
    output reg          l2_req,          
    output reg          l2_is_write,     
    output reg          cache_stall      
);

    localparam CTRL_READY      = 2'b00;
    localparam CTRL_WAIT_L2    = 2'b01;
    localparam CTRL_REFILL_L1  = 2'b10;

    reg [1:0] state, next_state;
    reg       refill_done;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= CTRL_READY;
            refill_done <= 1'b0;
        end else begin
            state <= next_state;
            if (state == CTRL_REFILL_L1) begin
                refill_done <= 1'b1;
            end else begin
                refill_done <= 1'b0;
            end
        end
    end

    always @(*) begin
        next_state  = state;
        cache_stall = 1'b0;
        l2_req      = 1'b0;
        l2_is_write = 1'b0;

        case (state)
            CTRL_READY: begin
                if (l1d_miss) begin
                    cache_stall = 1'b1;
                    l2_req = 1'b1;
                    l2_is_write = 1'b0;
                    next_state = CTRL_WAIT_L2;
                end
            end

            CTRL_WAIT_L2: begin
                cache_stall = 1'b1;
                if (l2_done) begin
                    l2_req = 1'b0;
                    next_state = CTRL_REFILL_L1;
                end
            end

            CTRL_REFILL_L1: begin
                // One cycle for L1 to latch data, then release
                cache_stall = 1'b1;
                next_state = CTRL_READY;
            end
            
            default: next_state = CTRL_READY;
        endcase
    end

endmodule