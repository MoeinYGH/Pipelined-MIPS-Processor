`timescale 1ns / 1ps

module L2_Arbiter (
    input  wire         clk,
    input  wire         rst,
    // L1I Interface
    input  wire         l1i_req,
    input  wire  [31:0] l1i_addr,
    input  wire  [127:0] l1i_write_data,
    input  wire         l1i_is_write,
    output reg          l1i_grant,
    // L1D Interface
    input  wire         l1d_req,
    input  wire  [31:0] l1d_addr,
    input  wire  [127:0] l1d_write_data,
    input  wire         l1d_is_write,
    output reg          l1d_grant,
    // L2 Interface
    output reg          l2_req,
    output reg          l2_is_instruction,
    output reg  [31:0]  l2_addr,
    output reg  [127:0] l2_write_data,
    output reg          l2_is_write,
    input  wire         l2_done,
    input  wire  [127:0] l2_read_data,
    input  wire         l2_miss
);

    localparam S_IDLE = 2'b00;
    localparam S_L1I  = 2'b01;
    localparam S_L1D  = 2'b10;
    localparam S_DONE = 2'b11;
    
    reg [1:0] state, next_state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        // Defaults
        next_state = state;
        l1i_grant = 1'b0;
        l1d_grant = 1'b0;
        l2_req = 1'b0;
        l2_is_instruction = 1'b0;
        l2_addr = 32'b0;
        l2_write_data = 128'b0;
        l2_is_write = 1'b0;

        case (state)
            S_IDLE: begin
                // Priority: L1I has higher priority (instruction fetch)
                if (l1i_req) begin
                    l1i_grant = 1'b1;
                    l2_req = 1'b1;
                    l2_is_instruction = 1'b1;
                    l2_addr = l1i_addr;
                    l2_write_data = l1i_write_data;
                    l2_is_write = l1i_is_write;
                    next_state = S_L1I;
                end else if (l1d_req) begin
                    l1d_grant = 1'b1;
                    l2_req = 1'b1;
                    l2_is_instruction = 1'b0;
                    l2_addr = l1d_addr;
                    l2_write_data = l1d_write_data;
                    l2_is_write = l1d_is_write;
                    next_state = S_L1D;
                end
            end

            S_L1I: begin
                l1i_grant = 1'b1;
                if (l2_done) begin
                    next_state = S_DONE;
                end
            end

            S_L1D: begin
                l1d_grant = 1'b1;
                if (l2_done) begin
                    next_state = S_DONE;
                end
            end

            S_DONE: begin
                if (!l2_req) begin
                    next_state = S_IDLE;
                end
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule