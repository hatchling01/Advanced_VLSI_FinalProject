`timescale 1ns/1ps

module tb_lockin_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart;

    localparam int SAMPLE_WIDTH = 16;
    localparam int NUM_BINS = 8;
    localparam int SAMPLES_PER_BIN = 64;
    localparam int TOTAL_SAMPLES = NUM_BINS * SAMPLES_PER_BIN;
    localparam int BIN_WIDTH = 3;
    localparam int ENERGY_WIDTH = 62;

    localparam string INPUT_MEM = "vectors/input_samples.mem";
    localparam string SIN_MEM = "vectors/sin_rom.mem";
    localparam string COS_MEM = "vectors/cos_rom.mem";
    localparam string EXPECTED_BIN_FILE = "vectors/expected_detected_bin.txt";
    localparam string RESULT_FILE = "sim_result.txt";

    logic clk;
    logic rst;
    logic sample_valid;
    logic signed [SAMPLE_WIDTH-1:0] input_samples [0:TOTAL_SAMPLES-1];
    logic signed [SAMPLE_WIDTH-1:0] sample_in;
    logic done;
    logic [BIN_WIDTH-1:0] detected_bin;
    logic [ENERGY_WIDTH-1:0] best_energy;

    int expected_bin;
    int expected_fd;
    int result_fd;
    int scan_count;
    int wait_cycles;
    int latency_after_last_sample;

    lockin_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart_top #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .NUM_BINS(NUM_BINS),
        .SAMPLES_PER_BIN(SAMPLES_PER_BIN),
        .BIN_WIDTH(BIN_WIDTH),
        .ENERGY_WIDTH(ENERGY_WIDTH),
        .SIN_MEM(SIN_MEM),
        .COS_MEM(COS_MEM)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .done(done),
        .detected_bin(detected_bin),
        .best_energy(best_energy)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $readmemh(INPUT_MEM, input_samples);

        expected_fd = $fopen(EXPECTED_BIN_FILE, "r");
        if (expected_fd == 0) begin
            $fatal(1, "Could not open %s", EXPECTED_BIN_FILE);
        end
        scan_count = $fscanf(expected_fd, "%d", expected_bin);
        $fclose(expected_fd);
        if (scan_count != 1) begin
            $fatal(1, "Could not read expected bin from %s", EXPECTED_BIN_FILE);
        end

        result_fd = $fopen(RESULT_FILE, "w");
        if (result_fd == 0) begin
            $fatal(1, "Could not open %s", RESULT_FILE);
        end

        rst = 1'b1;
        sample_valid = 1'b0;
        sample_in = '0;
        latency_after_last_sample = 0;

        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        for (int idx = 0; idx < TOTAL_SAMPLES; idx++) begin
            sample_valid = 1'b1;
            sample_in = input_samples[idx];
            @(negedge clk);
        end

        sample_valid = 1'b0;
        sample_in = '0;
        wait_cycles = 0;

        while (!done && wait_cycles < 200) begin
            wait_cycles++;
            @(negedge clk);
        end

        latency_after_last_sample = wait_cycles;

        $display("Expected bin: %0d", expected_bin);
        $display("Detected bin: %0d", detected_bin);
        $display("Best energy:  %0d", best_energy);
        $display("Latency after final sample: %0d cycles", latency_after_last_sample);

        $fdisplay(result_fd, "Expected bin: %0d", expected_bin);
        $fdisplay(result_fd, "Detected bin: %0d", detected_bin);
        $fdisplay(result_fd, "Best energy:  %0d", best_energy);
        $fdisplay(result_fd, "Latency after final sample: %0d cycles", latency_after_last_sample);

        if (!done) begin
            $fdisplay(result_fd, "FAIL: done did not assert");
            $fatal(1, "done did not assert");
        end

        if (detected_bin !== expected_bin[BIN_WIDTH-1:0]) begin
            $fdisplay(result_fd, "FAIL: detected bin mismatch");
            $fatal(1, "detected bin mismatch");
        end

        $fdisplay(result_fd, "PASS");
        $display("PASS");
        $fclose(result_fd);
        $finish;
    end

endmodule
