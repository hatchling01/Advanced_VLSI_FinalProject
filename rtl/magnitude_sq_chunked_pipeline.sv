`timescale 1ns/1ps

module magnitude_sq_chunked_pipeline #(
    parameter int IN_WIDTH = 48,
    parameter int OUT_WIDTH = 128
) (
    input  logic                         clk,
    input  logic                         rst,
    input  logic                         valid,
    input  logic signed [IN_WIDTH-1:0]   i_in,
    input  logic signed [IN_WIDTH-1:0]   q_in,
    output logic                         valid_out,
    output logic        [OUT_WIDTH-1:0]  mag_sq
);

    localparam int CHUNK_WIDTH = 16;
    localparam int SQUARE_WIDTH = 2 * IN_WIDTH;
    localparam int ACC_WIDTH = SQUARE_WIDTH + 8;

    logic valid_p1;
    logic valid_p2;
    logic valid_p3;

    logic signed [CHUNK_WIDTH-1:0] i_hi;
    logic        [CHUNK_WIDTH-1:0] i_mid;
    logic        [CHUNK_WIDTH-1:0] i_lo;
    logic signed [CHUNK_WIDTH-1:0] q_hi;
    logic        [CHUNK_WIDTH-1:0] q_mid;
    logic        [CHUNK_WIDTH-1:0] q_lo;

    logic signed [31:0] i_hihi;
    logic signed [32:0] i_himid;
    logic signed [32:0] i_hilo;
    logic        [31:0] i_midmid;
    logic        [31:0] i_midlo;
    logic        [31:0] i_lolo;

    logic signed [31:0] q_hihi;
    logic signed [32:0] q_himid;
    logic signed [32:0] q_hilo;
    logic        [31:0] q_midmid;
    logic        [31:0] q_midlo;
    logic        [31:0] q_lolo;

    logic [SQUARE_WIDTH-1:0] i_square;
    logic [SQUARE_WIDTH-1:0] q_square;

    function automatic logic [SQUARE_WIDTH-1:0] combine_square(
        input logic signed [31:0] hihi,
        input logic signed [32:0] himid,
        input logic signed [32:0] hilo,
        input logic        [31:0] midmid,
        input logic        [31:0] midlo,
        input logic        [31:0] lolo
    );
        logic signed [ACC_WIDTH-1:0] acc;
        begin
            acc = '0;
            acc = acc + ($signed({{(ACC_WIDTH-32){hihi[31]}}, hihi}) <<< 64);
            acc = acc + ($signed({{(ACC_WIDTH-33){himid[32]}}, himid}) <<< 49);
            acc = acc + ($signed({{(ACC_WIDTH-33){hilo[32]}}, hilo}) <<< 33);
            acc = acc + ($signed({{(ACC_WIDTH-32){1'b0}}, midmid}) <<< 32);
            acc = acc + ($signed({{(ACC_WIDTH-32){1'b0}}, midlo}) <<< 17);
            acc = acc + $signed({{(ACC_WIDTH-32){1'b0}}, lolo});
            combine_square = acc[SQUARE_WIDTH-1:0];
        end
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_p1 <= 1'b0;
            valid_p2 <= 1'b0;
            valid_p3 <= 1'b0;
            valid_out <= 1'b0;
            i_hi <= '0;
            i_mid <= '0;
            i_lo <= '0;
            q_hi <= '0;
            q_mid <= '0;
            q_lo <= '0;
            i_hihi <= '0;
            i_himid <= '0;
            i_hilo <= '0;
            i_midmid <= '0;
            i_midlo <= '0;
            i_lolo <= '0;
            q_hihi <= '0;
            q_himid <= '0;
            q_hilo <= '0;
            q_midmid <= '0;
            q_midlo <= '0;
            q_lolo <= '0;
            i_square <= '0;
            q_square <= '0;
            mag_sq <= '0;
        end else begin
            valid_p1 <= valid;
            valid_p2 <= valid_p1;
            valid_p3 <= valid_p2;
            valid_out <= valid_p3;

            if (valid) begin
                i_hi <= i_in[47:32];
                i_mid <= i_in[31:16];
                i_lo <= i_in[15:0];
                q_hi <= q_in[47:32];
                q_mid <= q_in[31:16];
                q_lo <= q_in[15:0];
            end

            if (valid_p1) begin
                i_hihi <= i_hi * i_hi;
                i_himid <= i_hi * $signed({1'b0, i_mid});
                i_hilo <= i_hi * $signed({1'b0, i_lo});
                i_midmid <= i_mid * i_mid;
                i_midlo <= i_mid * i_lo;
                i_lolo <= i_lo * i_lo;

                q_hihi <= q_hi * q_hi;
                q_himid <= q_hi * $signed({1'b0, q_mid});
                q_hilo <= q_hi * $signed({1'b0, q_lo});
                q_midmid <= q_mid * q_mid;
                q_midlo <= q_mid * q_lo;
                q_lolo <= q_lo * q_lo;
            end

            if (valid_p2) begin
                i_square <= combine_square(i_hihi, i_himid, i_hilo, i_midmid, i_midlo, i_lolo);
                q_square <= combine_square(q_hihi, q_himid, q_hilo, q_midmid, q_midlo, q_lolo);
            end

            if (valid_p3) begin
                mag_sq <= {{(OUT_WIDTH-SQUARE_WIDTH){1'b0}}, i_square}
                        + {{(OUT_WIDTH-SQUARE_WIDTH){1'b0}}, q_square};
            end
        end
    end

endmodule
