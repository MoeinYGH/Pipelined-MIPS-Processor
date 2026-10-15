`timescale 1ns / 1ps

module pcplus4(
    input  [31:0] OldPC,
    output [31:0] NewPC
);
    
    assign NewPC = OldPC + 32'd4;
    
endmodule