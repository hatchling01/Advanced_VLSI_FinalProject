`timescale 1ns/1ps

module magnitude_sq_narrow_pipelined #(
    parameter int IN_WIDTH = 48,
    parameter int OUT_WIDTH = 64,
    parameter int ENERGY_SHIFT = 0
) (
    input  logic                         clk,
    input  logic                         rst,
    input  logic                         valid,
    input  logic signed [IN_WIDTH-1:0]   i_in,
    input  logic signed [IN_WIDTH-1:0]   q_in,
    output logic                         valid_out,
    output logic        [OUT_WIDTH-1:0]  mag_sq
);

    localparam int SQUARE_WIDTH = 2 * IN_WIDTH;
    localparam int SUM_WIDTH = SQUARE_WIDTH + 1;

    logic valid_p1;
    logic valid_p2;
    logic signed [IN_WIDTH-1:0] i_reg;
    logic signed [IN_WIDTH-1:0] q_reg;
    logic [SQUARE_WIDTH-1:0] i_square;
    logic [SQUARE_WIDTH-1:0] q_square;
    logic [SUM_WIDTH-1:0] mag_sum;
    logic [SUM_WIDTH-1:0] mag_shifted;
    logic [OUT_WIDTH-1:0] mag_resized;

    assign mag_sum = {1'b0, i_square} + {1'b0, q_square};
    assign mag_shifted = mag_sum >> ENERGY_SHIFT;

    generate
        if (OUT_WIDTH > SUM_WIDTH) begin : gen_extend_mag
            assign mag_resized = {{(OUT_WIDTH-SUM_WIDTH){1'b0}}, mag_shifted};
        end else begin : gen_truncate_mag
            assign mag_resized = mag_shifted[OUT_WIDTH-1:0];
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_p1 <= 1'b0;
            valid_p2 <= 1'b0;
            valid_out <= 1'b0;
            i_reg <= '0;
            q_reg <= '0;
            i_square <= '0;
            q_square <= '0;
            mag_sq <= '0;
        end else begin
            valid_p1 <= valid;
            valid_p2 <= valid_p1;
            valid_out <= valid_p2;

            if (valid) begin
                i_reg <= i_in;
                q_reg <= q_in;
            end

            if (valid_p1) begin
                i_square <= i_reg * i_reg;
                q_square <= q_reg * q_reg;
            end

            if (valid_p2) begin
                mag_sq <= mag_resized;
            end
        end
    end

endmodule
