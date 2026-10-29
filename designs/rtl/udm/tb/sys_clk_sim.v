`timescale 1ns / 1ps

// Portable tests only: 100 MHz bypass of the 100 MHz Clocking Wizard IP.
// Do not add this file to Vivado sources: Vivado uses the actual sys_clk IP.
module sys_clk (
    input wire clk_in1,
    input wire reset,
    output wire clk_out1,
    output reg locked = 0
);
    assign clk_out1 = clk_in1;
    always @(posedge clk_in1 or posedge reset) begin
        if (reset) locked <= 0;
        else locked <= 1;
    end
endmodule
