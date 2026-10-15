/*
 * Combinational unsigned divider for laboratory variant 3.
 *
 * The restoring-division implementation intentionally mirrors
 * variants/3-const_divider.py: the upper four dividend bits seed the
 * partial remainder and the remaining thirteen bits are processed.
 */
module const_divider (
    input  wire [15:0] dividend_i,
    output wire [31:0] quotient_o,
    output wire [31:0] remainder_o
);

    localparam [4:0] DIVISOR = 5'd17;

    reg [12:0] quotient;
    reg [16:0] divword;
    integer i;

    always @* begin
        quotient = 13'd0;
        divword = {1'b0, dividend_i[15:12]};

        for (i = 0; i <= 12; i = i + 1) begin
            quotient = quotient << 1;
            if (divword >= DIVISOR) begin
                divword = divword - DIVISOR;
                quotient = quotient | 13'd1;
            end
            if (i != 12)
                divword = {divword[15:0], dividend_i[11-i]};
        end
    end

    assign quotient_o = {19'd0, quotient};
    assign remainder_o = {27'd0, divword[4:0]};

endmodule
