`timescale 1ns / 1ps

// End-to-end test: actual UART RX/TX, UDM controller, CSR decoder and divider.
// SIM="NO" keeps both UARTs active; no hierarchical signal injection is used.
module tb;
    parameter DIVIDER_MULTICYCLE = 1;
    localparam integer BIT_PERIOD = 1000;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset_n = 0;
    reg rx = 1;
    wire tx;
    reg [15:0] switches = 16'h0030;
    wire [15:0] led;

    NEXYS4_DDR #(.DIVIDER_MULTICYCLE(DIVIDER_MULTICYCLE)) DUT (
        .CLK100MHZ(clk), .CPU_RESETN(reset_n), .SW(switches), .LED(led),
        .UART_TXD_IN(rx), .UART_RXD_OUT(tx)
    );

    localparam ARG = 32'h10, QUOT = 32'h14, REM = 32'h18;
    localparam CTRL = 32'h1c, STATUS = 32'h20;
    reg [7:0] received [0:4095];
    integer received_count = 0, consumed_count = 0;
    reg [7:0] received_byte;
    integer bit_index;
    reg [31:0] last_q = 0, last_r = 0;
    reg [31:0] random_state = 17;
    integer index;

    // Decode DUT UART output independently of its internal bus response.
    initial forever begin
        @(negedge tx);
        #(BIT_PERIOD + BIT_PERIOD/2);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            received_byte[bit_index] = tx;
            #BIT_PERIOD;
        end
        if (tx !== 1'b1) $fatal(1, "UART stop bit missing");
        if (received_count == 4096) $fatal(1, "UART receive buffer overflow");
        received[received_count] = received_byte;
        received_count = received_count + 1;
    end

    task send_byte(input reg [7:0] data);
        integer bit_no;
        rx = 0;
        #BIT_PERIOD;
        for (bit_no = 0; bit_no < 8; bit_no = bit_no + 1) begin
            rx = data[bit_no];
            #BIT_PERIOD;
        end
        rx = 1;
        #(2*BIT_PERIOD);
    endtask

    task get_byte(output reg [7:0] data);
        integer clocks;
        clocks = 0;
        while (consumed_count == received_count && clocks < 10000) begin
            @(posedge clk);
            #1;
            clocks = clocks + 1;
        end
        if (consumed_count == received_count) $fatal(1, "UART response timeout");
        data = received[consumed_count];
        consumed_count = consumed_count + 1;
    endtask

    task send_data(input reg [7:0] data);
        if (data == 8'h55 || data == 8'h5a) send_byte(8'h5a);
        send_byte(data);
    endtask

    task send_word(input reg [31:0] data);
        send_data(data[7:0]);
        send_data(data[15:8]);
        send_data(data[23:16]);
        send_data(data[31:24]);
    endtask

    task get_data(output reg [7:0] data);
        get_byte(data);
        if (data == 8'h5a) get_byte(data);
        else if (data == 8'h01 || data == 8'h02 || data == 8'h80)
            $fatal(1, "UDM error/interrupt byte: 0x%02x", data);
    endtask

    task wr32(input reg [31:0] address, input reg [31:0] data);
        reg [7:0] response;
        send_byte(8'h55);
        send_byte(8'h81);
        send_word(address);
        send_word(32'd4);
        send_word(data);
        get_byte(response);
        if (response !== 8'h00) $fatal(1, "UDM write failed: %02x", response);
    endtask

    task rd32(input reg [31:0] address, output reg [31:0] data);
        reg [7:0] data_byte;
        integer byte_no;
        send_byte(8'h55);
        send_byte(8'h82);
        send_word(address);
        send_word(32'd4);
        for (byte_no = 0; byte_no < 4; byte_no = byte_no + 1) begin
            get_data(data_byte);
            data[byte_no*8 +: 8] = data_byte;
        end
    endtask

    task rd32_expect(input reg [31:0] address, input reg [31:0] expected);
        reg [31:0] actual;
        rd32(address, actual);
        if (actual !== expected)
            $fatal(1, "addr=%08x got=%08x expected=%08x", address, actual, expected);
    endtask

    task run_division(input reg [15:0] x);
        reg [31:0] status;
        integer polls;
        wr32(ARG, {16'hdead, x}); // Upper argument bits must be ignored.
        rd32_expect(ARG, {16'd0, x});
        if (DIVIDER_MULTICYCLE) begin
            rd32_expect(QUOT, last_q); // Writing ARG alone must not start work.
            rd32_expect(REM, last_r);
            wr32(CTRL, 0);
            rd32_expect(QUOT, last_q);
            wr32(CTRL, 1);
            status = 0;
            polls = 0;
            while (status != 2 && polls < 8) begin
                rd32(STATUS, status);
                polls = polls + 1;
            end
            if (status !== 32'd2) $fatal(1, "Divider DONE timeout");
        end
        last_q = {16'd0, x} / 17;
        last_r = {16'd0, x} % 17;
        rd32_expect(QUOT, last_q);
        rd32_expect(REM, last_r);
        rd32_expect(STATUS, 2);
        rd32_expect(CTRL, 0);
    endtask

    initial begin
        reg [7:0] response;
        #100;
        reset_n = 1;
        wait (DUT.srst === 1'b0);
        repeat (10) @(posedge clk);
        send_byte(8'h55);
        send_byte(8'h00);
        get_byte(response);
        if (response !== 8'h55) $fatal(1, "UDM IDCODE mismatch");
        rd32_expect(STATUS, DIVIDER_MULTICYCLE ? 0 : 2);
        rd32_expect(QUOT, 0);
        rd32_expect(REM, 0);

        // Baseline peripherals and escaping in both directions.
        wr32(32'h0, 32'h5a5a);
        rd32_expect(32'h0, 32'h5a5a);
        rd32_expect(32'h4, 32'h30);
        wr32(32'h80000000, 32'h55805a02);
        rd32_expect(32'h80000000, 32'h55805a02);
        wr32(32'h80000ffc, 32'hdeadbeef);
        rd32_expect(32'h80000ffc, 32'hdeadbeef);

        run_division(0);
        run_division(1);
        run_division(16);
        run_division(17);
        run_division(18);
        run_division(34);
        run_division(65534);
        run_division(65535);
        for (index = 0; index < 16; index = index + 1) begin
            random_state = random_state * 32'd1664525 + 32'd1013904223;
            run_division(random_state[15:0]);
        end

        // UDM reset must clear the accelerator, not reset the UART connection.
        send_byte(8'h55);
        send_byte(8'h80);
        send_byte(8'h55);
        send_byte(8'hc0);
        rd32_expect(ARG, 0);
        rd32_expect(QUOT, 0);
        rd32_expect(REM, 0);
        rd32_expect(STATUS, DIVIDER_MULTICYCLE ? 0 : 2);
        last_q = 0;
        last_r = 0;
        run_division(35);
        $display("tb: PASS (UART/UDM, 25 divisions, reset, baseline peripherals, multicycle=%0d)",
            DIVIDER_MULTICYCLE);
        $finish;
    end

    initial begin
        #100000000;
        $fatal(1, "Integration test timeout");
    end
endmodule
