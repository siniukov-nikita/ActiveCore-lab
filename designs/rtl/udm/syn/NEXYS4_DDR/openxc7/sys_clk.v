`timescale 1ns / 1ps

// In the openXC7 build, synth_xilinx inserts the global clock buffer.
// The board oscillator already supplies the 100 MHz used by ActiveCore.
module sys_clk (
    input wire clk_in1,
    input wire reset,
    output wire clk_out1,
    output wire locked
);
    // Hold reset active after configuration even if CPU_RESETN starts high.
    reg [3:0] startup = 4'd0;
    always @(posedge clk_in1) begin
        if (reset)
            startup <= 4'd0;
        else
            startup <= {startup[2:0], 1'b1};
    end

    assign clk_out1 = clk_in1;
    assign locked = startup[3];
endmodule
