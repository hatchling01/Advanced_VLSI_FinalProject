`timescale 1ns/1ps

module resonance_tracker_fanout #(
    parameter int NUM_BINS = 8,
    parameter int BIN_WIDTH = 3,
    parameter int ENERGY_WIDTH = 128,
    parameter bit DIP_MODE = 1'b0
) (
    input  logic                    clk,
    input  logic                    rst,
    (* max_fanout = 64 *) input logic bin_valid,
    input  logic [BIN_WIDTH-1:0]    bin_id,
    input  logic [ENERGY_WIDTH-1:0] bin_energy,
    output logic                    done,
    output logic [BIN_WIDTH-1:0]    detected_bin,
    output logic [ENERGY_WIDTH-1:0] best_energy
);

    (* max_fanout = 64 *) logic is_better;

    always_comb begin
        if (bin_id == '0) begin
            is_better = 1'b1;
        end else if (DIP_MODE) begin
            is_better = bin_energy < best_energy;
        end else begin
            is_better = bin_energy > best_energy;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
            detected_bin <= '0;
            best_energy <= '0;
        end else if (bin_valid) begin
            if (is_better) begin
                best_energy <= bin_energy;
                detected_bin <= bin_id;
            end

            if (bin_id == (NUM_BINS - 1)) begin
                done <= 1'b1;
            end
        end
    end

endmodule
