`timescale 1ns/1ps

module bin_accumulator_startload #(
    parameter int BIN_WIDTH = 3,
    parameter int ENERGY_WIDTH = 128
) (
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      valid,
    input  logic [BIN_WIDTH-1:0]      bin_id,
    input  logic                      start_of_bin,
    input  logic                      end_of_bin,
    input  logic [ENERGY_WIDTH-1:0]   mag_sq,
    output logic                      bin_done,
    output logic [BIN_WIDTH-1:0]      done_bin,
    output logic [ENERGY_WIDTH-1:0]   bin_energy
);

    logic [ENERGY_WIDTH-1:0] running_energy;
    logic [ENERGY_WIDTH-1:0] accumulated_energy;

    assign accumulated_energy = start_of_bin ? mag_sq : running_energy + mag_sq;

    always_ff @(posedge clk) begin
        if (rst) begin
            running_energy <= '0;
            bin_done <= 1'b0;
            done_bin <= '0;
            bin_energy <= '0;
        end else begin
            bin_done <= 1'b0;

            if (valid) begin
                running_energy <= accumulated_energy;

                if (end_of_bin) begin
                    bin_done <= 1'b1;
                    done_bin <= bin_id;
                    bin_energy <= accumulated_energy;
                end
            end
        end
    end

endmodule
