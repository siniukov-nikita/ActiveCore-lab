/*
 * NEXYS4_DDR.sv
 *
 *  Created on: 01.01.2020
 *      Author: Alexander Antonov <antonov.alex.alex@gmail.com>
 *     License: See LICENSE file for details
 */
 
module NEXYS4_DDR
#( parameter SIM = "NO", parameter DIVIDER_MULTICYCLE = 1, parameter DIVIDER_PIPELINE = 0 )
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

wire udm_req, udm_ack, udm_we, udm_resp;
wire [31:0] udm_addr, udm_wdata, udm_rdata;

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
	
	, .bus_req_o(udm_req)
	, .bus_we_o(udm_we)
	, .bus_addr_bo(udm_addr)
	, .bus_be_bo()
	, .bus_wdata_bo(udm_wdata)
	, .bus_ack_i(udm_ack)
	, .bus_resp_i(udm_resp)
	, .bus_rdata_bi(udm_rdata)
);

localparam CSR_LED_ADDR         = 32'h00000000;
localparam CSR_SW_ADDR          = 32'h00000004;
localparam DIVIDER_ARG_ADDR     = 32'h00000010;
localparam DIVIDER_QUOT_ADDR    = 32'h00000014;
localparam DIVIDER_REM_ADDR     = 32'h00000018;
localparam DIVIDER_CTRL_ADDR    = 32'h0000001c;
localparam DIVIDER_STATUS_ADDR  = 32'h00000020;
localparam TESTMEM_ADDR         = 32'h80000000;

localparam TESTMEM_WSIZE_POW    = 10;
localparam TESTMEM_WSIZE        = 2**TESTMEM_WSIZE_POW;

logic udm_testmem_enb;
assign udm_testmem_enb = ((udm_addr >= TESTMEM_ADDR) && (udm_addr < (TESTMEM_ADDR + (TESTMEM_WSIZE*4))));
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

    , .dat0_i(udm_wdata)
    , .adr0_i(udm_addr[TESTMEM_WSIZE_POW+1:2])
    , .we0_i(udm_req && udm_we && udm_testmem_enb)
    , .dat0_o(udm_testmem_rdata)

    , .dat1_i(testmem_p1_wdata)
    , .adr1_i(testmem_p1_addr)
    , .we1_i(testmem_p1_we)
    , .dat1_o(testmem_p1_rdata) 
);

assign udm_ack = udm_req;   // bus always ready to accept request
logic udm_csr_resp, udm_testmem_resp;
logic [31:0] udm_csr_rdata;
logic [15:0] divider_arg;
wire [31:0] divider_quotient;
wire [31:0] divider_remainder;
wire divider_busy;
wire divider_done;
wire divider_start = udm_req && udm_ack && udm_we
    && (udm_addr == DIVIDER_CTRL_ADDR) && udm_wdata[0];
wire divider_reset = srst || udm_reset;

generate
    if (DIVIDER_PIPELINE) begin : gen_pipeline
        reg busy, done;
        reg [31:0] quotient, remainder;
        wire result_valid;
        wire [31:0] pipeline_quotient, pipeline_remainder;
        wire accept = divider_start && !busy;

        const_divider_pipeline divider (
            .clk_i(clk_gen),
            .rst_i(divider_reset),
            .valid_i(accept),
            .dividend_i(divider_arg),
            .valid_o(result_valid),
            .quotient_o(pipeline_quotient),
            .remainder_o(pipeline_remainder)
        );

        // UDM exposes one stable result pair. The pipeline core itself accepts
        // an input every cycle and has no dependency on this handshake.
        always @(posedge clk_gen) begin
            if (divider_reset) begin
                busy <= 1'b0;
                done <= 1'b0;
                quotient <= 32'd0;
                remainder <= 32'd0;
            end else if (result_valid) begin
                busy <= 1'b0;
                done <= 1'b1;
                quotient <= pipeline_quotient;
                remainder <= pipeline_remainder;
            end else if (accept) begin
                busy <= 1'b1;
                done <= 1'b0;
            end
        end

        assign divider_busy = busy;
        assign divider_done = done;
        assign divider_quotient = quotient;
        assign divider_remainder = remainder;
    end else if (DIVIDER_MULTICYCLE) begin : gen_multicycle
        const_divider_multicycle divider (
            .clk_i(clk_gen),
            .rst_i(divider_reset),
            .start_i(divider_start),
            .dividend_i(divider_arg),
            .busy_o(divider_busy),
            .done_o(divider_done),
            .quotient_o(divider_quotient),
            .remainder_o(divider_remainder)
        );
    end else begin : gen_combinational
        const_divider divider (
            .dividend_i(divider_arg),
            .quotient_o(divider_quotient),
            .remainder_o(divider_remainder)
        );
        assign divider_busy = 1'b0;
        assign divider_done = 1'b1;
    end
endgenerate

// bus request
always @(posedge clk_gen)
    begin
    udm_csr_resp <= 1'b0;
    udm_testmem_resp <= 1'b0;
    
    if (divider_reset)
        begin
        LED <= 16'hffff;
        divider_arg <= 16'd0;
        end
    
    else
        begin
        
        if (udm_req && udm_ack)
            begin
            
            if (udm_we)     // writing
                begin
                if (udm_addr == CSR_LED_ADDR) LED <= udm_wdata[15:0];
                if (udm_addr == DIVIDER_ARG_ADDR)
                    divider_arg <= udm_wdata[15:0];
                end
            
            else                // reading
                begin
                if (udm_addr == CSR_LED_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= {16'd0, LED};
                    end
                if (udm_addr == CSR_SW_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= {16'd0, SW};
                    end
                if (udm_addr == DIVIDER_ARG_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= {16'd0, divider_arg};
                    end
                if (udm_addr == DIVIDER_QUOT_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= divider_quotient;
                    end
                if (udm_addr == DIVIDER_REM_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= divider_remainder;
                    end
                if (udm_addr == DIVIDER_CTRL_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= 32'd0; // START is a write strobe
                    end
                if (udm_addr == DIVIDER_STATUS_ADDR)
                    begin
                    udm_csr_resp <= 1'b1;
                    udm_csr_rdata <= {29'd0, (DIVIDER_PIPELINE != 0), divider_done, divider_busy};
                    end
                udm_testmem_resp <= udm_testmem_enb;
                end
            end
        
        end

        end

// bus response
assign udm_resp = udm_csr_resp | udm_testmem_resp;
assign udm_rdata = (udm_csr_rdata & {32{udm_csr_resp}}) | (udm_testmem_rdata & {32{udm_testmem_resp}});

endmodule
