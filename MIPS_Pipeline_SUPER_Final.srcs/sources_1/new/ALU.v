`timescale 1ns / 1ps

module ALU(
    input      [31:0] A, B,
    input      [3:0]  ALUCtrl,
    output reg [31:0] Result,
    output reg        Zero
);

    always @(*) begin
        // Evaluate the arithmetic operation
        case (ALUCtrl)
            4'b0000: Result = A & B;        // AND
            4'b0001: Result = A | B;        // OR
            4'b0010: Result = A + B;        // ADD
            4'b0110: Result = A - B;        // SUB
            4'b0111: Result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0; // SLT signed
            default: Result = 32'd0;
        endcase

        // Synchronized combinational assignment of Zero flag to eliminate simulation hazards
        if (Result == 32'd0) begin
            Zero = 1'b1;
        end else begin
            Zero = 1'b0;
        end
    end

endmodule