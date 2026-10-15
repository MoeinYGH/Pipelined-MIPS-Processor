`timescale 1ns / 1ps

module ALUControl(
    input [2:0] ALUOp,
    input [5:0] funct,
    output reg [3:0] ALUCtrl
);

    always @(*) begin
        case (ALUOp)
            3'b000: begin // R-Type Instructions
                case (funct)
                    6'b100000: ALUCtrl = 4'b0010; // add
                    6'b100010: ALUCtrl = 4'b0110; // sub
                    6'b100100: ALUCtrl = 4'b0000; // and
                    6'b100101: ALUCtrl = 4'b0001; // or
                    6'b101010: ALUCtrl = 4'b0111; // slt (added explicit R-type slt)
                    default:   ALUCtrl = 4'b0010; // Default safe fallback to ADD
                endcase
            end
            
            3'b001: ALUCtrl = 4'b0110; // beq (uses subtraction for comparison)
            
            3'b010: ALUCtrl = 4'b0111; // slti / slt
            
            3'b011: ALUCtrl = 4'b0010; // addi, lw, sw (uses addition for address/offset calculation)
            
            default: ALUCtrl = 4'b0010; // Default safe configuration fallback
        endcase
    end

endmodule