`timescale 1ns / 1ps

module const_divider_tb;

    logic [15:0] dividend;
    wire [31:0] quotient;
    wire [31:0] remainder;
    integer value;
    integer expected_quotient;
    integer expected_remainder;

    const_divider dut (
        .dividend_i(dividend),
        .quotient_o(quotient),
        .remainder_o(remainder)
    );

    initial begin
        for (value = 0; value < 65536; value = value + 1) begin
            dividend = value;
            #1;
            expected_quotient = value / 17;
            expected_remainder = value % 17;
            if ((quotient !== expected_quotient) ||
                (remainder !== expected_remainder)) begin
                $fatal(1, "x=%0d: got q=%0d r=%0d, expected q=%0d r=%0d",
                    value, quotient, remainder,
                    expected_quotient, expected_remainder);
            end
        end
        $display("const_divider_tb: PASS (65536 values)");
        $finish;
    end

endmodule
