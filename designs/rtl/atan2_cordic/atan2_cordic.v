`timescale 1ns / 1ps

module atan2_cordic_comb (
    input  logic signed [31:0] y_bi,
    input  logic signed [31:0] x_bi,
    output logic signed [31:0] angle_bo
);

    // ============================================================
    // Константы алгоритма CORDIC (формат Q3.29, 29 дробных бит)
    // ============================================================
    localparam int ITERATIONS = 32;
    localparam logic signed [63:0] PI     = 64'sh000000006487ed51; // round(pi * 2^29)
    localparam logic signed [63:0] TWO_PI = 64'sh00000000c90fdaa2; // round(2*pi * 2^29)

    // Таблица atan(2^-i) в формате Q3.29
    logic signed [63:0] ATAN_TABLE [0:ITERATIONS-1];
    initial begin
        ATAN_TABLE[0]  = 64'sh1921fb54;
        ATAN_TABLE[1]  = 64'sh0ed63383;
        ATAN_TABLE[2]  = 64'sh07d6dd7e;
        ATAN_TABLE[3]  = 64'sh03fab753;
        ATAN_TABLE[4]  = 64'sh01ff55bb;
        ATAN_TABLE[5]  = 64'sh00ffeaae;
        ATAN_TABLE[6]  = 64'sh007ffd55;
        ATAN_TABLE[7]  = 64'sh003fffab;
        ATAN_TABLE[8]  = 64'sh001ffff5;
        ATAN_TABLE[9]  = 64'sh000fffff;
        ATAN_TABLE[10] = 64'sh00080000;
        ATAN_TABLE[11] = 64'sh00040000;
        ATAN_TABLE[12] = 64'sh00020000;
        ATAN_TABLE[13] = 64'sh00010000;
        ATAN_TABLE[14] = 64'sh00008000;
        ATAN_TABLE[15] = 64'sh00004000;
        ATAN_TABLE[16] = 64'sh00002000;
        ATAN_TABLE[17] = 64'sh00001000;
        ATAN_TABLE[18] = 64'sh00000800;
        ATAN_TABLE[19] = 64'sh00000400;
        ATAN_TABLE[20] = 64'sh00000200;
        ATAN_TABLE[21] = 64'sh00000100;
        ATAN_TABLE[22] = 64'sh00000080;
        ATAN_TABLE[23] = 64'sh00000040;
        ATAN_TABLE[24] = 64'sh00000020;
        ATAN_TABLE[25] = 64'sh00000010;
        ATAN_TABLE[26] = 64'sh00000008;
        ATAN_TABLE[27] = 64'sh00000004;
        ATAN_TABLE[28] = 64'sh00000002;
        ATAN_TABLE[29] = 64'sh00000001;
        ATAN_TABLE[30] = 64'sh00000000;
        ATAN_TABLE[31] = 64'sh00000000;
    end

    // ============================================================
    // Комбинационная логика вычисления CORDIC
    // ============================================================
    always_comb begin
        logic signed [63:0] x, y;
        logic signed [63:0] x_old, y_old;
        logic signed [63:0] angle;

        // Обработка точки (0, 0)
        if (x_bi == 32'sd0 && y_bi == 32'sd0) begin
            angle_bo = 32'sd0;
        end else begin
            // Приведение в правую полуплоскость (x >= 0)
            if (x_bi < 32'sd0) begin
                x = -{{32{x_bi[31]}}, x_bi};
                y = -{{32{y_bi[31]}}, y_bi};
                angle = PI;
            end else begin
                x = {{32{x_bi[31]}}, x_bi};
                y = {{32{y_bi[31]}}, y_bi};
                angle = 64'sd0;
            end

            // 32 комбинационные итерации (разворачиваются синтезатором в цепочку)
            for (int i = 0; i < ITERATIONS; i++) begin
                x_old = x;
                y_old = y;

                if (y > 64'sd0) begin
                    x = x_old + (y_old >>> i);
                    y = y_old - (x_old >>> i);
                    angle = angle + ATAN_TABLE[i];
                end else begin
                    x = x_old - (y_old >>> i);
                    y = y_old + (x_old >>> i);
                    angle = angle - ATAN_TABLE[i];
                end
            end

            // Нормализация диапазона к [-PI, PI]
            if (angle > PI) begin
                angle = angle - TWO_PI;
            end else if (angle < -PI) begin
                angle = angle + TWO_PI;
            end

            angle_bo = angle[31:0];
        end
    end

endmodule
