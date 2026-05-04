`timescale 1ns/1ps

module lockin_pipelined_top #(
    parameter int SAMPLE_WIDTH = 16,
    parameter int REF_WIDTH = 16,
    parameter int PHASE_WIDTH = 32,
    parameter int ROM_ADDR_BITS = 8,
    parameter int NUM_BINS = 8,
    parameter int SAMPLES_PER_BIN = 64,
    parameter int BIN_WIDTH = 3,
    parameter int MIX_WIDTH = SAMPLE_WIDTH + REF_WIDTH,
    parameter int FIR_OUT_WIDTH = 48,
    parameter int ENERGY_WIDTH = 128,
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

    localparam int SAMPLE_COUNT_WIDTH = $clog2(SAMPLES_PER_BIN);

    logic [BIN_WIDTH-1:0] current_bin;
    logic [SAMPLE_COUNT_WIDTH-1:0] sample_count;

    logic bin_start;
    logic end_of_bin;
    logic [PHASE_WIDTH-1:0] phase_step;

    logic signed [REF_WIDTH-1:0] sin_ref;
    logic signed [REF_WIDTH-1:0] cos_ref;

    logic valid_s1;
    logic [BIN_WIDTH-1:0] bin_s1;
    logic end_s1;
    logic signed [SAMPLE_WIDTH-1:0] sample_s1;
    logic signed [REF_WIDTH-1:0] sin_s1;
    logic signed [REF_WIDTH-1:0] cos_s1;

    logic signed [MIX_WIDTH-1:0] i_mixed_comb;
    logic signed [MIX_WIDTH-1:0] q_mixed_comb;
    logic valid_s2;
    logic [BIN_WIDTH-1:0] bin_s2;
    logic end_s2;
    logic signed [MIX_WIDTH-1:0] i_mixed_s2;
    logic signed [MIX_WIDTH-1:0] q_mixed_s2;

    logic valid_s3;
    logic [BIN_WIDTH-1:0] bin_s3;
    logic end_s3;
    logic valid_fir_p1;
    logic valid_fir_p2;
    logic valid_fir_p3;
    logic [BIN_WIDTH-1:0] bin_fir_p1;
    logic [BIN_WIDTH-1:0] bin_fir_p2;
    logic [BIN_WIDTH-1:0] bin_fir_p3;
    logic end_fir_p1;
    logic end_fir_p2;
    logic end_fir_p3;
    logic fir_i_valid;
    logic fir_q_valid;
    logic signed [FIR_OUT_WIDTH-1:0] i_filt_s3;
    logic signed [FIR_OUT_WIDTH-1:0] q_filt_s3;

    logic valid_s4;
    logic [BIN_WIDTH-1:0] bin_s4;
    logic end_s4;
    logic [BIN_WIDTH-1:0] bin_mag_p1;
    logic [BIN_WIDTH-1:0] bin_mag_p2;
    logic end_mag_p1;
    logic end_mag_p2;
    logic [ENERGY_WIDTH-1:0] mag_sq_s4;

    logic bin_done;
    logic [BIN_WIDTH-1:0] done_bin;
    logic [ENERGY_WIDTH-1:0] bin_energy;

    function automatic logic [PHASE_WIDTH-1:0] phase_step_for_bin(
        input logic [BIN_WIDTH-1:0] bin_id
    );
        begin
            unique case (bin_id)
                3'd0: phase_step_for_bin = 32'h08000000;
                3'd1: phase_step_for_bin = 32'h0C000000;
                3'd2: phase_step_for_bin = 32'h10000000;
                3'd3: phase_step_for_bin = 32'h14000000;
                3'd4: phase_step_for_bin = 32'h18000000;
                3'd5: phase_step_for_bin = 32'h1C000000;
                3'd6: phase_step_for_bin = 32'h20000000;
                3'd7: phase_step_for_bin = 32'h24000000;
                default: phase_step_for_bin = 32'h08000000;
            endcase
        end
    endfunction

    assign bin_start = sample_valid && (sample_count == '0);
    assign end_of_bin = sample_valid && (sample_count == SAMPLES_PER_BIN - 1);
    assign phase_step = phase_step_for_bin(current_bin);

    nco #(
        .PHASE_WIDTH(PHASE_WIDTH),
        .ADDR_BITS(ROM_ADDR_BITS),
        .REF_WIDTH(REF_WIDTH),
        .SIN_MEM(SIN_MEM),
        .COS_MEM(COS_MEM)
    ) u_nco (
        .clk(clk),
        .rst(rst),
        .valid(sample_valid),
        .bin_start(bin_start),
        .phase_step(phase_step),
        .sin_ref(sin_ref),
        .cos_ref(cos_ref)
    );

    iq_mixer #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .REF_WIDTH(REF_WIDTH),
        .MIX_WIDTH(MIX_WIDTH)
    ) u_mixer (
        .sample_in(sample_s1),
        .sin_ref(sin_s1),
        .cos_ref(cos_s1),
        .i_mixed(i_mixed_comb),
        .q_mixed(q_mixed_comb)
    );

    fir_filter_pipelined #(
        .IN_WIDTH(MIX_WIDTH),
        .OUT_WIDTH(FIR_OUT_WIDTH)
    ) u_fir_i (
        .clk(clk),
        .rst(rst),
        .valid(valid_s2),
        .sample_in(i_mixed_s2),
        .valid_out(fir_i_valid),
        .sample_out(i_filt_s3)
    );

    fir_filter_pipelined #(
        .IN_WIDTH(MIX_WIDTH),
        .OUT_WIDTH(FIR_OUT_WIDTH)
    ) u_fir_q (
        .clk(clk),
        .rst(rst),
        .valid(valid_s2),
        .sample_in(q_mixed_s2),
        .valid_out(fir_q_valid),
        .sample_out(q_filt_s3)
    );

    magnitude_sq_pipelined #(
        .IN_WIDTH(FIR_OUT_WIDTH),
        .OUT_WIDTH(ENERGY_WIDTH)
    ) u_mag (
        .clk(clk),
        .rst(rst),
        .valid(valid_s3),
        .i_in(i_filt_s3),
        .q_in(q_filt_s3),
        .valid_out(valid_s4),
        .mag_sq(mag_sq_s4)
    );

    bin_accumulator #(
        .BIN_WIDTH(BIN_WIDTH),
        .ENERGY_WIDTH(ENERGY_WIDTH)
    ) u_accumulator (
        .clk(clk),
        .rst(rst),
        .valid(valid_s4),
        .bin_id(bin_s4),
        .end_of_bin(end_s4),
        .mag_sq(mag_sq_s4),
        .bin_done(bin_done),
        .done_bin(done_bin),
        .bin_energy(bin_energy)
    );

    resonance_tracker #(
        .NUM_BINS(NUM_BINS),
        .BIN_WIDTH(BIN_WIDTH),
        .ENERGY_WIDTH(ENERGY_WIDTH),
        .DIP_MODE(1'b0)
    ) u_tracker (
        .clk(clk),
        .rst(rst),
        .bin_valid(bin_done),
        .bin_id(done_bin),
        .bin_energy(bin_energy),
        .done(done),
        .detected_bin(detected_bin),
        .best_energy(best_energy)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            current_bin <= '0;
            sample_count <= '0;
        end else if (sample_valid) begin
            if (end_of_bin) begin
                sample_count <= '0;
                if (current_bin != NUM_BINS - 1) begin
                    current_bin <= current_bin + 1'b1;
                end
            end else begin
                sample_count <= sample_count + 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_s1 <= 1'b0;
            bin_s1 <= '0;
            end_s1 <= 1'b0;
            sample_s1 <= '0;
            sin_s1 <= '0;
            cos_s1 <= '0;

            valid_s2 <= 1'b0;
            bin_s2 <= '0;
            end_s2 <= 1'b0;
            i_mixed_s2 <= '0;
            q_mixed_s2 <= '0;

            valid_s3 <= 1'b0;
            bin_s3 <= '0;
            end_s3 <= 1'b0;
            valid_fir_p1 <= 1'b0;
            valid_fir_p2 <= 1'b0;
            valid_fir_p3 <= 1'b0;
            bin_fir_p1 <= '0;
            bin_fir_p2 <= '0;
            bin_fir_p3 <= '0;
            end_fir_p1 <= 1'b0;
            end_fir_p2 <= 1'b0;
            end_fir_p3 <= 1'b0;

            bin_s4 <= '0;
            end_s4 <= 1'b0;
            bin_mag_p1 <= '0;
            bin_mag_p2 <= '0;
            end_mag_p1 <= 1'b0;
            end_mag_p2 <= 1'b0;
        end else begin
            valid_s1 <= sample_valid;
            bin_s1 <= current_bin;
            end_s1 <= end_of_bin;
            sample_s1 <= sample_in;
            sin_s1 <= sin_ref;
            cos_s1 <= cos_ref;

            valid_s2 <= valid_s1;
            bin_s2 <= bin_s1;
            end_s2 <= end_s1;
            i_mixed_s2 <= i_mixed_comb;
            q_mixed_s2 <= q_mixed_comb;

            valid_fir_p1 <= valid_s2;
            valid_fir_p2 <= valid_fir_p1;
            valid_fir_p3 <= valid_fir_p2;
            valid_s3 <= valid_fir_p3;
            bin_fir_p1 <= bin_s2;
            bin_fir_p2 <= bin_fir_p1;
            bin_fir_p3 <= bin_fir_p2;
            bin_s3 <= bin_fir_p3;
            end_fir_p1 <= end_s2;
            end_fir_p2 <= end_fir_p1;
            end_fir_p3 <= end_fir_p2;
            end_s3 <= end_fir_p3;

            bin_mag_p1 <= bin_s3;
            bin_mag_p2 <= bin_mag_p1;
            bin_s4 <= bin_mag_p2;
            end_mag_p1 <= end_s3;
            end_mag_p2 <= end_mag_p1;
            end_s4 <= end_mag_p2;
        end
    end

endmodule
