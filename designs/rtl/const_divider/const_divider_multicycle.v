`timescale 1ns / 1ps

/* Variant 3: one iteration of variants/3-const_divider.py per clock. */
module const_divider_multicycle (
    input  wire        clk_i,
    input  wire        rst_i,
    input  wire        start_i,
    input  wire [15:0] dividend_i,
    output reg         busy_o,
    output reg         done_o,
    output reg  [31:0] quotient_o,
    output reg  [31:0] remainder_o
);

    reg [11:0] dividend_bits;
    reg [12:0] quotient;
    reg [5:0] partial_remainder;
    reg [3:0] iteration;

    // Before comparison the remainder is at most 2*16+1 = 33.
    wire subtract = (partial_remainder >= 6'd17);
    wire [5:0] reduced_remainder = subtract
        ? partial_remainder - 6'd17 : partial_remainder;
    wire [12:0] next_quotient = {quotient[11:0], subtract};

    always @(posedge clk_i) begin
        if (rst_i) begin
            dividend_bits <= 12'd0;
            quotient <= 13'd0;
            partial_remainder <= 6'd0;
            iteration <= 4'd0;
            busy_o <= 1'b0;
            done_o <= 1'b0;
            quotient_o <= 32'd0;
            remainder_o <= 32'd0;
        end else if (busy_o) begin
            // START is ignored while busy, including the completion edge.
            quotient <= next_quotient;
            if (iteration == 4'd12) begin
                quotient_o <= {19'd0, next_quotient};
                remainder_o <= {26'd0, reduced_remainder};
                busy_o <= 1'b0;
                done_o <= 1'b1;
            end else begin
                partial_remainder <= {reduced_remainder[4:0], dividend_bits[11]};
                dividend_bits <= {dividend_bits[10:0], 1'b0};
                iteration <= iteration + 4'd1;
            end
        end else if (start_i) begin
            dividend_bits <= dividend_i[11:0];
            partial_remainder <= {2'b0, dividend_i[15:12]};
            quotient <= 13'd0;
            iteration <= 4'd0;
            busy_o <= 1'b1;
            done_o <= 1'b0;
            // Output registers retain the previous completed result.
        end
    end
endmodule
