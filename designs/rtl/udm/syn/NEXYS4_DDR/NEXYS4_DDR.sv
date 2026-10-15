/*
 * NEXYS4_DDR.sv
 *
 *  Created on: 01.01.2020
 *      Author: Alexander Antonov <antonov.alex.alex@gmail.com>
 *     License: See LICENSE file for details
 */
 
interface MemSplit32 ();
    logic req;
    logic ack;
    logic [31:0] addr;
    logic we;
    logic [31:0] wdata;
    logic [3:0] be;
    logic resp;
    logic [31:0] rdata;

    modport Master  (output req, input ack, output addr, output we, output wdata, output be, input resp, input rdata);
    modport Slave   (input req, output ack, input addr, input we, input wdata, input be, output resp, output rdata);
endinterface


module NEXYS4_DDR
#( parameter SIM = "NO" )
(
	input 	CLK100MHZ
    , input   CPU_RESETN
    
    , input   [15:0] SW
    , output logic  [15:0] LED

    , input   UART_TXD_IN
    , output  UART_RXD_OUT
);

localparam UDM_BUS_TIMEOUT = (SIM == "YES") ? 100 : (1024*1024*100);
localparam UDM_RTX_EXTERNAL_OVERRIDE = (SIM == "YES") ? "YES" : "NO";

logic clk_gen;
logic pll_locked;

sys_clk sys_clk
(
    .clk_in1(CLK100MHZ)
    , .reset(!CPU_RESETN)
    , .clk_out1(clk_gen)
    , .locked(pll_locked)
);

logic arst;
assign arst = !(CPU_RESETN & pll_locked);

logic srst;
reset_sync reset_sync
(
	.clk_i(clk_gen),
	.arst_i(arst),
	.srst_o(srst)
);

logic udm_reset;

MemSplit32 udm_bus();

udm
#(
    .BUS_TIMEOUT(UDM_BUS_TIMEOUT)
    , .RTX_EXTERNAL_OVERRIDE(UDM_RTX_EXTERNAL_OVERRIDE)
) udm (
	.clk_i(clk_gen)
	, .rst_i(srst)

	, .rx_i(UART_TXD_IN)
	, .tx_o(UART_RXD_OUT)

	, .rst_o(udm_reset)
	
	, .bus_req_o(udm_bus.req)
	, .bus_we_o(udm_bus.we)
	, .bus_addr_bo(udm_bus.addr)
	, .bus_be_bo(udm_bus.be)
	, .bus_wdata_bo(udm_bus.wdata)
	, .bus_ack_i(udm_bus.ack)
	, .bus_resp_i(udm_bus.resp)
	, .bus_rdata_bi(udm_bus.rdata)
);

localparam CSR_LED_ADDR         = 32'h00000000;
localparam CSR_SW_ADDR          = 32'h00000004;
localparam VARIANT_SEL_ADDR     = 32'h00000008;
localparam DIVIDER_ARG_ADDR     = 32'h00000010;
localparam DIVIDER_QUOT_ADDR    = 32'h00000014;
localparam DIVIDER_REM_ADDR     = 32'h00000018;
localparam ATAN2_Y_ADDR         = 32'h00000020;
localparam ATAN2_X_ADDR         = 32'h00000024;
localparam ATAN2_ANGLE_ADDR     = 32'h00000028;
localparam TESTMEM_ADDR         = 32'h80000000;

localparam TESTMEM_WSIZE_POW    = 10;
localparam TESTMEM_WSIZE        = 2**TESTMEM_WSIZE_POW;

logic udm_testmem_enb;
assign udm_testmem_enb = ((udm_bus.addr >= TESTMEM_ADDR) && (udm_bus.addr < (TESTMEM_ADDR + (TESTMEM_WSIZE*4))));
logic [31:0] udm_testmem_rdata;

logic testmem_p1_we;
logic [TESTMEM_WSIZE_POW-1:0] testmem_p1_addr;
logic [31:0] testmem_p1_wdata;
logic [31:0] testmem_p1_rdata;

// testmem's port1 is inactive
assign testmem_p1_we = 1'b0;
assign testmem_p1_addr = 0;
assign testmem_p1_wdata = 0;

ram_dual #(
    .init_type("none")
    , .init_data("nodata.hex")
    , .dat_width(32)
    , .adr_width(TESTMEM_WSIZE_POW)
    , .mem_size(TESTMEM_WSIZE)
) testmem (
    .clk(clk_gen)

    , .dat0_i(udm_bus.wdata)
    , .adr0_i(udm_bus.addr[31:2])
    , .we0_i(udm_bus.req && udm_bus.we && udm_testmem_enb)
    , .dat0_o(udm_testmem_rdata)

    , .dat1_i(testmem_p1_wdata)
    , .adr1_i(testmem_p1_addr)
    , .we1_i(testmem_p1_we)
    , .dat1_o(testmem_p1_rdata) 
);

assign udm_bus.ack = udm_bus.req;   // bus always ready to accept request
logic udm_csr_resp, udm_testmem_resp;
logic [31:0] udm_csr_rdata;
logic [15:0] divider_arg;
wire [31:0] divider_quotient;
wire [31:0] divider_remainder;
logic variant_sel;
logic signed [31:0] atan2_y;
logic signed [31:0] atan2_x;
wire signed [31:0] atan2_angle;

const_divider divider (
    .dividend_i(divider_arg),
    .quotient_o(divider_quotient),
    .remainder_o(divider_remainder)
);

atan2_cordic atan2 (
    .y_i(atan2_y),
    .x_i(atan2_x),
    .angle_o(atan2_angle)
);

// bus request
always @(posedge clk_gen)
    begin
    udm_csr_resp <= 1'b0;
    udm_testmem_resp <= 1'b0;
    
    if (srst)
        begin
        LED <= 16'hffff;
        variant_sel <= 1'b0;
        divider_arg <= 16'd0;
        atan2_y <= 32'sd0;
        atan2_x <= 32'sd0;
        end
    
    else
        begin
        
        if (udm_bus.req && udm_bus.ack)
            begin
            
            if (udm_bus.we)     // writing
                begin
                if (udm_bus.addr == CSR_LED_ADDR) LED <= udm_bus.wdata;
                if (udm_bus.addr == VARIANT_SEL_ADDR) variant_sel <= udm_bus.wdata[0];
                if (udm_bus.addr == DIVIDER_ARG_ADDR)
                    begin
                    if (!variant_sel)
                        divider_arg <= udm_bus.wdata[15:0];
                    else
                        atan2_y <= udm_bus.wdata;
                    end
                if ((udm_bus.addr == DIVIDER_QUOT_ADDR) && variant_sel)
                    atan2_x <= udm_bus.wdata;
                if (udm_bus.addr == ATAN2_Y_ADDR) atan2_y <= udm_bus.wdata;
                if (udm_bus.addr == ATAN2_X_ADDR) atan2_x <= udm_bus.wdata;
                end
            
            else                // reading
                begin
                if (udm_bus.addr == CSR_LED_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= LED;
                    end
                if (udm_bus.addr == CSR_SW_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= SW;
                    end
                if (udm_bus.addr == VARIANT_SEL_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= {31'd0, variant_sel};
                    end
                if (udm_bus.addr == DIVIDER_ARG_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    if (!variant_sel)
                        udm_csr_rdata <= {16'd0, divider_arg};
                    else
                        udm_csr_rdata <= atan2_y;
                    end
                if (udm_bus.addr == DIVIDER_QUOT_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    if (!variant_sel)
                        udm_csr_rdata <= divider_quotient;
                    else
                        udm_csr_rdata <= atan2_x;
                    end
                if (udm_bus.addr == DIVIDER_REM_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    if (!variant_sel)
                        udm_csr_rdata <= divider_remainder;
                    else
                        udm_csr_rdata <= atan2_angle;
                    end
                if (udm_bus.addr == ATAN2_Y_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= atan2_y;
                    end
                if (udm_bus.addr == ATAN2_X_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= atan2_x;
                    end
                if (udm_bus.addr == ATAN2_ANGLE_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= atan2_angle;
                    end
                udm_testmem_resp <= udm_testmem_enb;
                end
            end
        
        end

        end

// bus response
assign udm_bus.resp = udm_csr_resp | udm_testmem_resp;
assign udm_bus.rdata = (udm_csr_rdata & {32{udm_csr_resp}}) | (udm_testmem_rdata & {32{udm_testmem_resp}});

endmodule
