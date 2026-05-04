`timescale 1ns/1ps

module fir_filter_pipelined_outreg_fast_round #(
    parameter int IN_WIDTH = 32,
    parameter int OUT_WIDTH = 48,
    parameter int ACC_WIDTH = 56,
    parameter int SHIFT = 4
) (
    input  logic                         clk,
    input  logic                         rst,
    input  logic                         valid,
    input  logic signed [IN_WIDTH-1:0]   sample_in,
    output logic                         valid_out,
    output logic signed [OUT_WIDTH-1:0]  sample_out
);

    localparam int TAPS = 8;

    logic signed [IN_WIDTH-1:0] delay_line [0:TAPS-1];

    logic signed [ACC_WIDTH-1:0] term0;
    logic signed [ACC_WIDTH-1:0] term1;
    logic signed [ACC_WIDTH-1:0] term2;
    logic signed [ACC_WIDTH-1:0] term3;
    logic signed [ACC_WIDTH-1:0] term4;
    logic signed [ACC_WIDTH-1:0] term5;
    logic signed [ACC_WIDTH-1:0] term6;
    logic signed [ACC_WIDTH-1:0] term7;

    logic signed [ACC_WIDTH-1:0] sum01;
    logic signed [ACC_WIDTH-1:0] sum23;
    logic signed [ACC_WIDTH-1:0] sum45;
    logic signed [ACC_WIDTH-1:0] sum67;
    logic signed [ACC_WIDTH-1:0] sum0123;
    logic signed [ACC_WIDTH-1:0] sum4567;
    logic signed [ACC_WIDTH-1:0] final_sum_comb;
    logic signed [ACC_WIDTH-1:0] final_sum_reg;
    logic signed [ACC_WIDTH-1:0] rounded_sum;

    logic valid_p1;
    logic valid_p2;
    logic valid_p3;
    logic valid_p4;

    function automatic logic signed [ACC_WIDTH-1:0] extend_sample(
        input logic signed [IN_WIDTH-1:0] value
    );
        begin
            extend_sample = {{(ACC_WIDTH-IN_WIDTH){value[IN_WIDTH-1]}}, value};
        end
    endfunction

    function automatic logic signed [ACC_WIDTH-1:0] round_shift_fast(
        input logic signed [ACC_WIDTH-1:0] value
    );
        logic signed [ACC_WIDTH-1:0] bias;
        begin
            if (value >= 0) begin
                bias = {{(ACC_WIDTH-SHIFT){1'b0}}, 1'b1, {(SHIFT-1){1'b0}}};
            end else begin
                bias = {{(ACC_WIDTH-(SHIFT-1)){1'b0}}, {(SHIFT-1){1'b1}}};
            end
            round_shift_fast = (value + bias) >>> SHIFT;
        end
    endfunction

    assign final_sum_comb = sum0123 + sum4567;
    assign rounded_sum = round_shift_fast(final_sum_reg);

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int idx = 0; idx < TAPS; idx++) begin
                delay_line[idx] <= '0;
            end

            term0 <= '0;
            term1 <= '0;
            term2 <= '0;
            term3 <= '0;
            term4 <= '0;
            term5 <= '0;
            term6 <= '0;
            term7 <= '0;

            sum01 <= '0;
            sum23 <= '0;
            sum45 <= '0;
            sum67 <= '0;
            sum0123 <= '0;
            sum4567 <= '0;
            final_sum_reg <= '0;
            sample_out <= '0;

            valid_p1 <= 1'b0;
            valid_p2 <= 1'b0;
            valid_p3 <= 1'b0;
            valid_p4 <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            valid_p1 <= valid;
            valid_p2 <= valid_p1;
            valid_p3 <= valid_p2;
            valid_p4 <= valid_p3;
            valid_out <= valid_p4;

            if (valid) begin
                term0 <= extend_sample(sample_in);
                term1 <= extend_sample(delay_line[0]) <<< 1;
                term2 <= extend_sample(delay_line[1]) + (extend_sample(delay_line[1]) <<< 1);
                term3 <= extend_sample(delay_line[2]) <<< 2;
                term4 <= extend_sample(delay_line[3]) <<< 2;
                term5 <= extend_sample(delay_line[4]) + (extend_sample(delay_line[4]) <<< 1);
                term6 <= extend_sample(delay_line[5]) <<< 1;
                term7 <= extend_sample(delay_line[6]);

                delay_line[0] <= sample_in;
                for (int idx = 1; idx < TAPS; idx++) begin
                    delay_line[idx] <= delay_line[idx-1];
                end
            end

            if (valid_p1) begin
                sum01 <= term0 + term1;
                sum23 <= term2 + term3;
                sum45 <= term4 + term5;
                sum67 <= term6 + term7;
            end

            if (valid_p2) begin
                sum0123 <= sum01 + sum23;
                sum4567 <= sum45 + sum67;
            end

            if (valid_p3) begin
                final_sum_reg <= final_sum_comb;
            end

            if (valid_p4) begin
                sample_out <= rounded_sum[OUT_WIDTH-1:0];
            end
        end
    end

endmodule
