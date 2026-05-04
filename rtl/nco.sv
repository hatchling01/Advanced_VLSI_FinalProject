`timescale 1ns/1ps

module nco #(
    parameter int PHASE_WIDTH = 32,
    parameter int ADDR_BITS = 8,
    parameter int REF_WIDTH = 16,
    parameter string SIN_MEM = "vectors/sin_rom.mem",
    parameter string COS_MEM = "vectors/cos_rom.mem"
) (
    input  logic                         clk,
    input  logic                         rst,
    input  logic                         valid,
    input  logic                         bin_start,
    input  logic [PHASE_WIDTH-1:0]       phase_step,
    output logic signed [REF_WIDTH-1:0]  sin_ref,
    output logic signed [REF_WIDTH-1:0]  cos_ref
);

    localparam int ROM_DEPTH = 1 << ADDR_BITS;

    logic [PHASE_WIDTH-1:0] phase;
    logic [PHASE_WIDTH-1:0] lookup_phase;
    logic [ADDR_BITS-1:0] rom_addr;

    logic signed [REF_WIDTH-1:0] sin_rom [0:ROM_DEPTH-1];
    logic signed [REF_WIDTH-1:0] cos_rom [0:ROM_DEPTH-1];

    initial begin
        $readmemh(SIN_MEM, sin_rom);
        $readmemh(COS_MEM, cos_rom);
    end

    assign lookup_phase = bin_start ? '0 : phase;
    assign rom_addr = lookup_phase[PHASE_WIDTH-1 -: ADDR_BITS];
    assign sin_ref = sin_rom[rom_addr];
    assign cos_ref = cos_rom[rom_addr];

    always_ff @(posedge clk) begin
        if (rst) begin
            phase <= '0;
        end else if (valid) begin
            phase <= lookup_phase + phase_step;
        end
    end

endmodule

