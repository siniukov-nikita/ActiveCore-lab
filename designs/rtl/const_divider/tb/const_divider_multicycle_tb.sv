`timescale 1ns / 1ps

module const_divider_multicycle_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg start = 0;
    reg [15:0] dividend = 0;
    wire busy, done;
    wire [31:0] quotient, remainder;
    reg [63:0] vectors [0:65535];
    string vectors_path, vcd_path;
    bit use_vectors;
    integer value, abort_cycle, cycle;

    const_divider_multicycle dut (
        .clk_i(clk), .rst_i(rst), .start_i(start), .dividend_i(dividend),
        .busy_o(busy), .done_o(done),
        .quotient_o(quotient), .remainder_o(remainder)
    );

    task tick;
        @(posedge clk);
        #1;
    endtask

    task reset_dut;
        @(negedge clk);
        rst = 1;
        start = 1; // Reset has priority over START.
        tick();
        if ({busy, done, quotient, remainder} !== 66'd0)
            $fatal(1, "Reset did not clear state and outputs");
        @(negedge clk);
        rst = 0;
        start = 0;
    endtask

    task run_value(input reg [15:0] x, input bit disturb);
        reg [31:0] old_q, old_r, expected_q, expected_r;
        integer step;
        old_q = quotient;
        old_r = remainder;
        expected_q = {16'd0, x} / 17;
        expected_r = {16'd0, x} % 17;
        @(negedge clk);
        dividend = x;
        start = 1;
        tick(); // Acceptance edge, t=0.
        if (busy !== 1'b1 || done !== 1'b0)
            $fatal(1, "START not accepted for x=%0d", x);
        if (quotient !== old_q || remainder !== old_r)
            $fatal(1, "START changed the previous result");
        for (step = 1; step <= 13; step = step + 1) begin
            @(negedge clk);
            dividend = ~x; // The accepted argument must be latched.
            start = disturb; // Includes a START at the completion edge.
            tick();
            if (step < 13) begin
                if (busy !== 1'b1 || done !== 1'b0 ||
                    quotient !== old_q || remainder !== old_r)
                    $fatal(1, "Premature completion/result at step=%0d x=%0d", step, x);
            end else begin
                if (busy !== 1'b0 || done !== 1'b1 ||
                    quotient !== expected_q || remainder !== expected_r)
                    $fatal(1, "step=13 x=%0d got q=%0d r=%0d busy=%b done=%b",
                        x, quotient, remainder, busy, done);
                if (use_vectors && {quotient, remainder} !== vectors[x])
                    $fatal(1, "Python-model mismatch for x=%0d", x);
            end
        end
        @(negedge clk);
        start = 0;
        repeat (2) begin
            tick();
            if (busy !== 1'b0 || done !== 1'b1 ||
                quotient !== expected_q || remainder !== expected_r)
                $fatal(1, "DONE/result not retained or busy START was queued");
        end
    endtask

    initial begin
        use_vectors = $value$plusargs("VECTORS=%s", vectors_path);
        if (use_vectors) $readmemh(vectors_path, vectors);
        if ($value$plusargs("VCD=%s", vcd_path)) begin
            $dumpfile(vcd_path);
            $dumpvars(0, clk, rst, start, dividend, busy, done, quotient, remainder, dut);
        end
        reset_dut();
        // Idle cannot spontaneously start or report completion.
        repeat (3) begin
            tick();
            if (busy !== 1'b0 || done !== 1'b0)
                $fatal(1, "Unexpected work after reset");
        end
        run_value(16'd0, 0);
        run_value(16'd17, 1);
        run_value(16'd65535, 1);
        run_value(16'd65534, 0);

        // Abort at every processing position, then prove a fresh START works.
        for (abort_cycle = 0; abort_cycle < 13; abort_cycle = abort_cycle + 1) begin
            @(negedge clk);
            dividend = 16'd12345;
            start = 1;
            tick();
            @(negedge clk);
            start = 0;
            repeat (abort_cycle) tick();
            reset_dut();
            run_value(16'd34, 0);
        end

        // A held START is accepted again one edge after completion: II=14.
        @(negedge clk);
        start = 1;
        dividend = 16'd18;
        tick();
        repeat (13) tick();
        if (busy !== 1'b0 || done !== 1'b1 || quotient !== 32'd1 || remainder !== 32'd1)
            $fatal(1, "First held-START result failed");
        @(negedge clk);
        dividend = 16'd35;
        tick(); // 14 clocks after the preceding acceptance.
        if (busy !== 1'b1 || done !== 1'b0)
            $fatal(1, "II is not 14 clocks");
        @(negedge clk);
        start = 0;
        repeat (13) tick();
        if (busy !== 1'b0 || done !== 1'b1 || quotient !== 32'd2 || remainder !== 32'd1)
            $fatal(1, "Second held-START result failed");
        reset_dut();
        if (vcd_path != "") $dumpoff;

        for (value = 0; value < 65536; value = value + 1)
            run_value(value[15:0], value[0]);
        $display("const_divider_multicycle_tb: PASS (65536 values, latency=13, II=14, reset/handshake)");
        $finish;
    end

    initial begin
        #20000000;
        $fatal(1, "Testbench timeout");
    end
endmodule
