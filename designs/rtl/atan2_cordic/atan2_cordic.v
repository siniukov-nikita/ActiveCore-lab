/*
 * Combinational vectoring CORDIC atan2.
 *
 * Inputs and output use signed two's-complement integers. The output is a
 * signed Q3.29 angle in radians, matching variants/10-atan2_cordic.py.
 */
module atan2_cordic (
    input  wire signed [31:0] y_i,
    input  wire signed [31:0] x_i,
    output wire signed [31:0] angle_o
);

    localparam signed [63:0] PI = 64'sd1686629713;
    localparam signed [63:0] TWO_PI = 64'sd3373259426;
    localparam signed [63:0] ATAN_TABLE [0:31] = '{
        64'sd421657428, 64'sd248918915, 64'sd131521918, 64'sd66762579,
        64'sd33510843, 64'sd16771758, 64'sd8387925, 64'sd4194219,
        64'sd2097141, 64'sd1048575, 64'sd524288, 64'sd262144,
        64'sd131072, 64'sd65536, 64'sd32768, 64'sd16384,
        64'sd8192, 64'sd4096, 64'sd2048, 64'sd1024,
        64'sd512, 64'sd256, 64'sd128, 64'sd64,
        64'sd32, 64'sd16, 64'sd8, 64'sd4,
        64'sd2, 64'sd1, 64'sd0, 64'sd0
    };

    reg signed [63:0] x_work;
    reg signed [63:0] y_work;
    reg signed [63:0] angle;
    reg signed [63:0] x_old;
    reg signed [63:0] y_old;
    integer i;

    always @* begin
        x_work = {{32{ x_i[31]}}, x_i};
        y_work = {{32{ y_i[31]}}, y_i};
        angle = 64'sd0;

        if ((x_i == 0) && (y_i == 0)) begin
            angle = 64'sd0;
        end
        else begin
            if (x_work < 0) begin
                x_work = -x_work;
                y_work = -y_work;
                angle = PI;
            end

            for (i = 0; i < 32; i = i + 1) begin
                x_old = x_work;
                y_old = y_work;
                if (y_work > 0) begin
                    x_work = x_old + (y_old >>> i);
                    y_work = y_old - (x_old >>> i);
                    angle = angle + ATAN_TABLE[i];
                end
                else begin
                    x_work = x_old - (y_old >>> i);
                    y_work = y_old + (x_old >>> i);
                    angle = angle - ATAN_TABLE[i];
                end
            end

            if (angle > PI)
                angle = angle - TWO_PI;
            else if (angle < -PI)
                angle = angle + TWO_PI;
        end
    end

    assign angle_o = angle[31:0];

endmodule
