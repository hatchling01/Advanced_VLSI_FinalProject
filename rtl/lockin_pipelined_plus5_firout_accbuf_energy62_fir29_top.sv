`timescale 1ns/1ps

module lockin_pipelined_plus5_firout_accbuf_energy62_fir29_top #(
    parameter int SAMPLE_WIDTH = 16,
    parameter int REF_WIDTH = 16,
    parameter int PHASE_WIDTH = 32,
    parameter int ROM_ADDR_BITS = 8,
    parameter int NUM_BINS = 8,
    parameter int SAMPLES_PER_BIN = 64,
    parameter int BIN_WIDTH = 3,
    parameter int MIX_WIDTH = SAMPLE_WIDTH + REF_WIDTH,
    parameter int FIR_OUT_WIDTH = 29,
    parameter int ENERGY_WIDTH = 62,
    parameter string SIN_MEM = "vectors/sin_rom.mem",
    parameter string COS_MEM = "vectors/cos_rom.mem"
) (
    input  logic                           clk,
    input  logic                           rst,
    input  logic                           sample_valid,
    input  logic signed [SAMPLE_WIDTH-1:0] sample_in,
    output logic                           done,
    output logic [BIN_WIDTH-1:0]           detected_bin,
    output logic [ENERGY_WIDTH-1:0]        best_energy
);

    lockin_pipelined_boundary_top #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .REF_WIDTH(REF_WIDTH),
        .PHASE_WIDTH(PHASE_WIDTH),
        .ROM_ADDR_BITS(ROM_ADDR_BITS),
        .NUM_BINS(NUM_BINS),
        .SAMPLES_PER_BIN(SAMPLES_PER_BIN),
        .BIN_WIDTH(BIN_WIDTH),
        .MIX_WIDTH(MIX_WIDTH),
        .FIR_OUT_WIDTH(FIR_OUT_WIDTH),
        .ENERGY_WIDTH(ENERGY_WIDTH),
        .BOUNDARY_STAGES(5),
        .FIR_OUTPUT_PIPELINE(1'b1),
        .MAG_CHUNKED_PIPELINE(1'b0),
        .MAG_NARROW_PIPELINE(1'b1),
        .MAG_ENERGY_SHIFT(0),
        .ACCUMULATOR_OUTPUT_PIPELINE(1'b1),
        .TRACKER_PIPELINE(1'b0),
        .TRACKER_COMPARE_PIPELINE(1'b0),
        .CONTROL_FANOUT_HINTS(1'b0),
        .SIN_MEM(SIN_MEM),
        .COS_MEM(COS_MEM)
    ) u_impl (
        .clk(clk),
        .rst(rst),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .done(done),
        .detected_bin(detected_bin),
        .best_energy(best_energy)
    );

endmodule
