`timescale 1ns/1ps

module fir_filter #(
    parameter int IN_WIDTH = 32,
    parameter int OUT_WIDTH = 48,
    parameter int ACC_WIDTH = 56,
    parameter int SHIFT = 4
) (
    input  logic                         clk,
    input  logic                         rst,
    input  logic                         valid,
    input  logic signed [IN_WIDTH-1:0]   sample_in,
    output logic signed [OUT_WIDTH-1:0]  sample_out
);

    localparam int TAPS = 8;

    logic signed [IN_WIDTH-1:0] delay_line [0:TAPS-1];
    logic signed [ACC_WIDTH-1:0] acc;
    logic signed [ACC_WIDTH-1:0] rounded_acc;

    function automatic logic signed [ACC_WIDTH-1:0] extend_sample(
        input logic signed [IN_WIDTH-1:0] value
    );
        begin
            extend_sample = {{(ACC_WIDTH-IN_WIDTH){value[IN_WIDTH-1]}}, value};
        end
    endfunction

    function automatic logic signed [ACC_WIDTH-1:0] round_shift(
        input logic signed [ACC_WIDTH-1:0] value
    );
        logic signed [ACC_WIDTH-1:0] offset;
        begin
            offset = {{(ACC_WIDTH-1){1'b0}}, 1'b1} <<< (SHIFT - 1);
            if (value >= 0) begin
                round_shift = (value + offset) >>> SHIFT;
            end else begin
                round_shift = -(((-value) + offset) >>> SHIFT);
            end
        end
    endfunction

    always_comb begin
        acc = '0;
        acc += extend_sample(sample_in);
        acc += (extend_sample(delay_line[0]) <<< 1);
        acc += extend_sample(delay_line[1]) + (extend_sample(delay_line[1]) <<< 1);
        acc += (extend_sample(delay_line[2]) <<< 2);
        acc += (extend_sample(delay_line[3]) <<< 2);
        acc += extend_sample(delay_line[4]) + (extend_sample(delay_line[4]) <<< 1);
        acc += (extend_sample(delay_line[5]) <<< 1);
        acc += extend_sample(delay_line[6]);
    end

    assign rounded_acc = round_shift(acc);

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int idx = 0; idx < TAPS; idx++) begin
                delay_line[idx] <= '0;
            end
            sample_out <= '0;
        end else if (valid) begin
            sample_out <= rounded_acc[OUT_WIDTH-1:0];
            delay_line[0] <= sample_in;
            for (int idx = 1; idx < TAPS; idx++) begin
                delay_line[idx] <= delay_line[idx-1];
            end
        end
    end

endmodule
