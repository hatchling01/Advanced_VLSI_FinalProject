`timescale 1ns/1ps

module magnitude_sq #(
    parameter int IN_WIDTH = 48,
    parameter int OUT_WIDTH = 128
) (
    input  logic signed [IN_WIDTH-1:0]  i_in,
    input  logic signed [IN_WIDTH-1:0]  q_in,
    output logic        [OUT_WIDTH-1:0] mag_sq
);

    logic signed [(2*IN_WIDTH)-1:0] i_square;
    logic signed [(2*IN_WIDTH)-1:0] q_square;

    assign i_square = i_in * i_in;
    assign q_square = q_in * q_in;
    assign mag_sq = {{(OUT_WIDTH-(2*IN_WIDTH)){1'b0}}, i_square}
                  + {{(OUT_WIDTH-(2*IN_WIDTH)){1'b0}}, q_square};

endmodule

