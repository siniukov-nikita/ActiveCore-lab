`timescale 1ns / 1ps

module const_divider_pipeline_tb;
    localparam LATENCY = 12;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, valid_i = 0;
    reg [15:0] dividend = 0;
    wire valid_o;
    wire [31:0] quotient, remainder;

    const_divider_pipeline dut (
        .clk_i(clk), .rst_i(rst), .valid_i(valid_i), .dividend_i(dividend),
        .valid_o(valid_o), .quotient_o(quotient), .remainder_o(remainder)
    );

    reg [63:0] vectors [0:65535];
    string vectors_path, vcd_path;
    bit use_vectors, dump_enabled;
    integer cycle = 0, checked = 0, value, before_exhaustive;
    // Store scheduled arrivals, including their input and exact cycle.
    integer due [0:LATENCY];
    reg [15:0] inputs [0:LATENCY];

    task tick(input bit reset, input bit enable, input reg [15:0] x);
        integer slot, i;
        reg [31:0] arg;
        @(negedge clk);
        rst = reset;
        valid_i = enable;
        dividend = x;
        @(posedge clk);
        cycle = cycle + 1;
        if (reset)
            for (i = 0; i <= LATENCY; i = i + 1) due[i] = -1;
        else if (enable) begin
            slot = (cycle + LATENCY) % (LATENCY + 1);
            due[slot] = cycle + LATENCY;
            inputs[slot] = x;
        end
        #1;
        slot = cycle % (LATENCY + 1);
        if (valid_o !== (due[slot] == cycle))
            $fatal(1, "cycle=%0d: unexpected valid_o=%b", cycle, valid_o);
        if (valid_o) begin
            arg = {16'd0, inputs[slot]};
            if (quotient !== (arg / 32'd17) || remainder !== (arg % 32'd17))
                $fatal(1, "cycle=%0d x=%0d got q=%0d r=%0d", cycle, arg, quotient, remainder);
            if (use_vectors && {quotient, remainder} !== vectors[inputs[slot]])
                $fatal(1, "Python model mismatch for x=%0d", arg);
            checked = checked + 1;
        end
    endtask

    initial begin
        use_vectors = $value$plusargs("VECTORS=%s", vectors_path);
        if (use_vectors) $readmemh(vectors_path, vectors);
        dump_enabled = $value$plusargs("VCD=%s", vcd_path);
        if (dump_enabled) begin
            $dumpfile(vcd_path);
            $dumpvars(0, const_divider_pipeline_tb.clk, rst, valid_i, dividend,
                valid_o, quotient, remainder, dut.valid);
        end
        tick(1, 0, 0);
        tick(0, 1, 16);
        tick(0, 1, 17);
        tick(0, 0, 12345); // Bubble.
        tick(0, 1, 18);
        tick(0, 1, 65535);
        repeat (LATENCY + 1) tick(0, 0, 0);
        if (checked != 4) $fatal(1, "Directed stream incomplete");

        repeat (LATENCY) tick(0, 1, 12345);
        tick(1, 1, 23456); // Reset flushes all pending inputs and takes priority.
        tick(0, 1, 65534);
        repeat (LATENCY + 1) tick(0, 0, 0);
        if (checked != 5) $fatal(1, "Reset leaked a result or lost a fresh input");
        if (dump_enabled) $dumpoff;

        before_exhaustive = checked;
        for (value = 0; value < 65536; value = value + 1)
            tick(0, 1, value[15:0]);
        repeat (LATENCY + 1) tick(0, 0, 0);
        if (checked - before_exhaustive != 65536)
            $fatal(1, "Continuous stream lost data");
        $display("const_divider_pipeline_tb: PASS (65536 consecutive inputs, latency=12, II=1, bubbles/reset)");
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "Pipeline testbench timeout");
    end
endmodule
