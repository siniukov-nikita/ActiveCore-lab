`timescale 1ns / 1ps

// Variant 3: fully pipelined unsigned division by 17, with no backpressure.
module const_divider_pipeline (
    input  wire        clk_i,
    input  wire        rst_i,
    input  wire        valid_i,
    input  wire [15:0] dividend_i,
    output wire        valid_o,
    output wire [31:0] quotient_o,
    output wire [31:0] remainder_o
);
    localparam STAGES = 12;
    reg [STAGES:0] valid;
    wire [11:0] bits_left [0:STAGES];
    wire [11:0] quotient [0:STAGES];
    wire [4:0] remainder [0:STAGES];

    reg [15:0] dividend;
    always @(posedge clk_i) begin
        dividend <= dividend_i;
        if (rst_i)
            valid <= 0;
        else
            valid <= {valid[STAGES-1:0], valid_i};
    end

    // The Python model's first comparison is 0..15 >= 17, always false.
    assign remainder[0] = {1'b0, dividend[15:12]};
    assign bits_left[0] = dividend[11:0];
    assign quotient[0] = 12'd0;

    for (genvar i = 0; i < STAGES; i = i + 1) begin : gen_stage
        reg [4:0] r;
        reg [11:0] q;
        reg [11:0] bits;
        wire [5:0] trial = {remainder[i], bits_left[i][11]};
        wire take = trial >= 6'd17;
        wire [5:0] reduced = take ? trial - 6'd17 : trial;

        // On a bubble the data are immaterial; only the valid chain is reset.
        always @(posedge clk_i) begin
            r <= reduced[4:0];
            q <= {quotient[i][10:0], take};
            bits <= {bits_left[i][10:0], 1'b0};
        end

        assign remainder[i+1] = r;
        assign quotient[i+1] = q;
        assign bits_left[i+1] = bits;
    end

    assign valid_o = valid[STAGES];
    assign quotient_o = {20'd0, quotient[STAGES]};
    assign remainder_o = {27'd0, remainder[STAGES]};
endmodule
