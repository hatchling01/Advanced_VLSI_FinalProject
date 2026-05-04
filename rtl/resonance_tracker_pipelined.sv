`timescale 1ns/1ps

module resonance_tracker_pipelined #(
    parameter int NUM_BINS = 8,
    parameter int BIN_WIDTH = 3,
    parameter int ENERGY_WIDTH = 128,
    parameter bit DIP_MODE = 1'b0
) (
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    bin_valid,
    input  logic [BIN_WIDTH-1:0]    bin_id,
    input  logic [ENERGY_WIDTH-1:0] bin_energy,
    output logic                    done,
    output logic [BIN_WIDTH-1:0]    detected_bin,
    output logic [ENERGY_WIDTH-1:0] best_energy
);

    logic compare_valid_s1;
    logic update_best_s1;
    logic last_bin_s1;
    logic [BIN_WIDTH-1:0] candidate_bin_s1;
    logic [ENERGY_WIDTH-1:0] candidate_energy_s1;

    logic is_better_comb;

    always_comb begin
        if (bin_id == '0) begin
            is_better_comb = 1'b1;
        end else if (DIP_MODE) begin
            is_better_comb = bin_energy < best_energy;
        end else begin
            is_better_comb = bin_energy > best_energy;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            compare_valid_s1 <= 1'b0;
            update_best_s1 <= 1'b0;
            last_bin_s1 <= 1'b0;
            candidate_bin_s1 <= '0;
            candidate_energy_s1 <= '0;
            done <= 1'b0;
            detected_bin <= '0;
            best_energy <= '0;
        end else begin
            compare_valid_s1 <= bin_valid;
            update_best_s1 <= bin_valid && is_better_comb;
            last_bin_s1 <= bin_valid && (bin_id == (NUM_BINS - 1));
            candidate_bin_s1 <= bin_id;
            candidate_energy_s1 <= bin_energy;

            if (compare_valid_s1) begin
                if (update_best_s1) begin
                    best_energy <= candidate_energy_s1;
                    detected_bin <= candidate_bin_s1;
                end

                if (last_bin_s1) begin
                    done <= 1'b1;
                end
            end
        end
    end

endmodule
