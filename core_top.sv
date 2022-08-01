`include "cache/cache.svh"
`include "common_defs.svh"

module core_top(
    input           aclk,
    input           aresetn,
    input    [ 7:0] intrpt,
    //AXI interface
    //read reqest
    output   [ 3:0] arid,
    output   [31:0] araddr,
    output   [ 7:0] arlen,
    output   [ 2:0] arsize,
    output   [ 1:0] arburst,
    output   [ 1:0] arlock,
    output   [ 3:0] arcache,
    output   [ 2:0] arprot,
    output          arvalid,
    input           arready,
    //read back
    input    [ 3:0] rid,
    input    [31:0] rdata,
    input    [ 1:0] rresp,
    input           rlast,
    input           rvalid,
    output          rready,
    //write request
    output   [ 3:0] awid,
    output   [31:0] awaddr,
    output   [ 7:0] awlen,
    output   [ 2:0] awsize,
    output   [ 1:0] awburst,
    output   [ 1:0] awlock,
    output   [ 3:0] awcache,
    output   [ 2:0] awprot,
    output          awvalid,
    input           awready,
    //write data
    output   [ 3:0] wid,
    output   [31:0] wdata,
    output   [ 3:0] wstrb,
    output          wlast,
    output          wvalid,
    input           wready,
    //write back
    input    [ 3:0] bid,
    input    [ 1:0] bresp,
    input           bvalid,
    output          bready,

    output [31:0] debug0_wb_pc,
    output [ 3:0] debug0_wb_rf_wen,
    output [ 4:0] debug0_wb_rf_wnum,
    output [31:0] debug0_wb_rf_wdata,
    output [31:0] debug0_wb_inst
);

    logic stall_icache;
    logic [11:0] icache_idx;
    logic [2:0] icache_op;
    logic icache_is_cached;
    logic [31:0] icache_pa;
    logic [31:0] icache_data;
    logic icache_busy, icache_data_valid;

    logic stall_dcache;
    logic [11:0] dcache_idx;
    logic [4:0] dcache_op;
    logic dcache_is_cached;
    logic [31:0] dcache_pa;
    logic [31:0] rd_dcache_data, wr_dcache_data;
    logic dcache_busy, dcache_data_valid;
    CPUTop U_CPUTop (
        .clk(aclk),
        .rst_n(aresetn),
        .*
    );

`ifdef FAKE_CACHE
    FakeCache U_FackCache (
        .clk(aclk),
        .rst_n(aresetn),
        .icache_req_valid(icache_op[0]),
        .dcache_req_valid(dcache_op[4] | dcache_op[3]),
        .dcache_store(dcache_op[4]),
        .dcache_byte_type(dcache_op[1:0]),
        .*
    );
`else

    logic [`AXI_REQ_WIDTH]req_to_axi;
    logic [`BLOCK_WIDTH]wblock_to_axi;
    logic [`DATA_WIDTH]wword_to_axi;
    logic [`AXI_STRB_WIDTH]wword_en_to_axi;
    logic [2:0]rword_en_to_axi;
    logic [`ADDRESS_WIDTH]ad_to_axi;

    logic [`BLOCK_WIDTH]rblock_from_axi;
    logic [`DATA_WIDTH]rword_from_axi;
    logic ready_from_axi;
    logic task_finish_from_axi;

    Cache cache (
        .clk(aclk),
        .rstn(aresetn),
        .icache_va(icache_idx),
        .icache_pa(icache_pa[31:12]),
        .icache_op(icache_op),
        .icache_stall(stall_icache),
        `ifdef CACHED_TO_TEST
            .icache_cached(1'b1),
        `else
            .icache_cached(icache_is_cached),
        `endif
        //.real_icache_cached(icache_is_cached),
        .ins(icache_data),
        .icache_busy(icache_busy),
        .icache_data_valid(icache_data_valid),
        .dcache_va(dcache_idx),
        .dcache_pa(dcache_pa[31:12]),
        .dcache_op(dcache_op),
        .dcache_stall(stall_dcache),
        `ifdef CACHED
            .dcache_cached(1'b1),
        `else
            .dcache_cached(dcache_is_cached),
        `endif
        //.real_dcache_cached(dcache_is_cached),
        .store_data(wr_dcache_data),
        .load_data(rd_dcache_data),
        .dcache_busy(dcache_busy),
        .dcache_data_valid(dcache_data_valid),

        .req_to_axi(req_to_axi),
        .wblock_to_axi(wblock_to_axi),
        .wword_to_axi(wword_to_axi),
        .wword_en_to_axi(wword_en_to_axi),
        .rword_en_to_axi(rword_en_to_axi),          
        .ad_to_axi(ad_to_axi),
        .rblock_from_axi(rblock_from_axi),
        .rword_from_axi(rword_from_axi),
        .ready_from_axi(ready_from_axi),
        .task_finish_from_axi(task_finish_from_axi)
    );

    AXI_bridge axi_bridge (
        .clk(aclk),
        .rstn(aresetn),
        .req(req_to_axi),
        .wblock(wblock_to_axi),
        .wword(wword_to_axi),
        .wword_en(wword_en_to_axi),
        .ad(ad_to_axi),
        .ready_to_pipline(ready_from_axi),
        .task_finish(task_finish_from_axi),
        .rblock(rblock_from_axi),
        .rword(rword_from_axi),
        .rword_en(rword_en_to_axi),             
        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arlock(arlock),
        .arcache(arcache),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(arready),
        .awid(awid),
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .awlock(awlock),
        .awcache(awcache),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(awready),
        .rid(rid),
        .rdata(rdata),
        .rresp(rresp),
        .rlast(rlast),
        .rvalid(rvalid),
        .rready(rready),
        .wid(wid),
        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),
        .wvalid(wvalid),
        .wready(wready),
        .bid(bid),
        .bresp(bresp),
        .bready(bready),
        .bvalid(bvalid)
    );

`endif

endmodule