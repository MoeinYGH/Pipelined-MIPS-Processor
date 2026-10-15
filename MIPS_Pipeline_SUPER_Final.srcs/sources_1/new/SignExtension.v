`timescale 1ns / 1ps

module SignExtension(
    input       [15:0] inp,
    output wire [31:0] out
);

    assign out = {{16{inp[15]}}, inp};

endmodule