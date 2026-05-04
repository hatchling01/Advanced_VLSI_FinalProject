`timescale 1ns/1ps

module resonance_tracker_compare_pipeline #(
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

    logic candidate_valid_s1;
    logic [BIN_WIDTH-1:0] candidate_bin_s1;
    logic [ENERGY_WIDTH-1:0] candidate_energy_s1;

    logic update_valid_s2;
    logic update_best_s2;
    logic last_bin_s2;
    logic [BIN_WIDTH-1:0] update_bin_s2;
    logic [ENERGY_WIDTH-1:0] update_energy_s2;

    logic is_better_s2;

    always_comb begin
        if (candidate_bin_s1 == '0) begin
            is_better_s2 = 1'b1;
        end else if (DIP_MODE) begin
            is_better_s2 = candidate_energy_s1 < best_energy;
        end else begin
            is_better_s2 = candidate_energy_s1 > best_energy;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            candidate_valid_s1 <= 1'b0;
            candidate_bin_s1 <= '0;
            candidate_energy_s1 <= '0;
            update_valid_s2 <= 1'b0;
            update_best_s2 <= 1'b0;
            last_bin_s2 <= 1'b0;
            update_bin_s2 <= '0;
            update_energy_s2 <= '0;
            done <= 1'b0;
            detected_bin <= '0;
            best_energy <= '0;
        end else begin
            candidate_valid_s1 <= bin_valid;
            candidate_bin_s1 <= bin_id;
            candidate_energy_s1 <= bin_energy;

            update_valid_s2 <= candidate_valid_s1;
            update_best_s2 <= candidate_valid_s1 && is_better_s2;
            last_bin_s2 <= candidate_valid_s1 && (candidate_bin_s1 == (NUM_BINS - 1));
            update_bin_s2 <= candidate_bin_s1;
            update_energy_s2 <= candidate_energy_s1;

            if (update_valid_s2) begin
                if (update_best_s2) begin
                    best_energy <= update_energy_s2;
                    detected_bin <= update_bin_s2;
                end

                if (last_bin_s2) begin
                    done <= 1'b1;
                end
            end
        end
    end

endmodule
