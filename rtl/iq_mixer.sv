`timescale 1ns/1ps

module iq_mixer #(
    parameter int SAMPLE_WIDTH = 16,
    parameter int REF_WIDTH = 16,
    parameter int MIX_WIDTH = SAMPLE_WIDTH + REF_WIDTH
) (
    input  logic signed [SAMPLE_WIDTH-1:0] sample_in,
    input  logic signed [REF_WIDTH-1:0]    sin_ref,
    input  logic signed [REF_WIDTH-1:0]    cos_ref,
    output logic signed [MIX_WIDTH-1:0]    i_mixed,
    output logic signed [MIX_WIDTH-1:0]    q_mixed
);

    assign i_mixed = sample_in * cos_ref;
    assign q_mixed = sample_in * sin_ref;

endmodule

