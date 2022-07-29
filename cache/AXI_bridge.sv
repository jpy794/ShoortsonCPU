`include "cache.svh"

module AXI_bridge (
    input logic clk,
    input logic rstn,

    input logic [`AXI_REQ_WIDTH]req,
    input logic [`BLOCK_WIDTH]wblock,
    input logic [`DATA_WIDTH]wword,
    input logic [`AXI_STRB_WIDTH]wword_en,
    input logic [`ADDRESS_WIDTH]ad,
    input logic cached,

    output logic task_finish,
    output logic ready_to_pipline,
    output logic [`BLOCK_WIDTH]rblock,
    output logic [`DATA_WIDTH]rword,
    input logic [`DCACHE_REQ_REN_WIDTH]rword_en,


    //axi
    output logic [`AXI_ID_WIDTH]arid,
    output logic [`ADDRESS_WIDTH]araddr,
    output logic [`AXI_LEN_WIDTH]arlen,
    output logic [`AXI_SIZE_WIDTH]arsize,
    output logic [`AXI_BURST_WIDTH]arburst,
    output logic [`AXI_LOCK_WIDTH]arlock,
    output logic [`AXI_CACHE_WIDTH]arcache,
    output logic [`AXI_PROT_WIDTH]arprot,
    output logic arvalid,
    input logic arready,
    //write request
    output logic [`AXI_ID_WIDTH]awid,
    output logic [`ADDRESS_WIDTH]awaddr,
    output logic [`AXI_LEN_WIDTH]awlen,
    output logic [`AXI_SIZE_WIDTH]awsize,    
    output logic [`AXI_BURST_WIDTH]awburst,
    output logic [`AXI_LOCK_WIDTH]awlock,
    output logic [`AXI_CACHE_WIDTH]awcache,
    output logic [`AXI_PROT_WIDTH]awprot,
    output logic awvalid,
    input logic awready,
    //read back
    input logic [`AXI_ID_WIDTH]rid,
    input logic [`DATA_WIDTH]rdata,
    input logic [`AXI_RESP_WIDTH]rresp,
    input logic rlast,
    input logic rvalid,
   output logic rready,
    //write data
    output logic [`AXI_ID_WIDTH]wid,   
    output logic [`DATA_WIDTH]wdata,
    output logic [`AXI_STRB_WIDTH]wstrb,
    output logic wlast,
    output logic wvalid,
     input logic wready,
    //write back
    input logic [`AXI_ID_WIDTH]bid,
     input logic [`AXI_RESP_WIDTH]bresp,
    output logic bready,
    input logic bvalid
);
    
assign wid = `AXI_WRITE_ID;
assign arlock = `AXI_LOCK_NORMAL;
assign arcache = `AXI_CACHE_CACHE;
assign awcache = `AXI_CACHE_CACHE;

assign arprot = `AXI_PORT_DATA;
assign awprot = `AXI_PORT_DATA;
assign awid = `AXI_WRITE_ID;
assign awlock = `AXI_LOCK_NORMAL;

assign arburst = `AXI_BURST_FIXED;
assign awburst = `AXI_BURST_FIXED;
assign arlen = `AXI_LEN_SINGAL;
assign awlen = `AXI_LEN_SINGAL;
assign arsize = `AXI_SIZE_WORD;
assign awsize = `AXI_SIZE_WORD;

logic [`AXI_STATE_WIDTH]axi_cs, axi_ns;

logic [`AXI_REQ_WIDTH]reg_req_from_pipline;
logic [`ADDRESS_WIDTH]reg_req_ad_from_pipline;

always_ff @(posedge clk or negedge rstn)begin
    if(~rstn)begin
        reg_req_from_pipline <= `REQ_TO_AXI_NONE;
    end
    else begin
        if(axi_ns == `AXI_STATE_WAIT && axi_cs != `AXI_STATE_WAIT)begin
            reg_req_from_pipline <= `REQ_TO_AXI_NONE;
        end
        else begin
            if(req != `REQ_TO_AXI_NONE)begin
                reg_req_from_pipline <= req;
            end
        end
    end
end

always_ff @(posedge clk)begin
    if(req != `REQ_TO_AXI_NONE)begin
        reg_req_ad_from_pipline <= ad;
    end
end

always_ff @(posedge clk or negedge rstn)begin
    if(~rstn)begin
        axi_cs <= `AXI_STATE_WAIT;
    end
    else begin
        axi_cs <= axi_ns;
    end
end

always_comb begin
    unique case(axi_cs)
        `AXI_STATE_WAIT: begin
            unique case(reg_req_from_pipline)
                `REQ_TO_AXI_LOAD_WORD: begin
                    axi_ns = `AXI_STATE_LOAD_WORD_WAIT_ARREADY;
                end
                `REQ_TO_AXI_WRITE_WORD: begin
                    axi_ns = `AXI_STATE_STORE_BLOCK_WAIT_AWREADY;
                end
                default: begin
                    axi_ns =  `AXI_STATE_WAIT;
                end
            endcase
        end
        `AXI_STATE_LOAD_WORD_WAIT_ARREADY: begin
            if(arready)begin
                axi_ns = `AXI_STATE_LOAD_WORD_WAIT_RVALID;
            end
            else begin
                axi_ns = `AXI_STATE_LOAD_WORD_WAIT_ARREADY;
            end
        end
        `AXI_STATE_LOAD_WORD_WAIT_RVALID: begin
            if(rvalid)begin
                axi_ns = `AXI_STATE_LOAD_WORD_SUCCESS;
            end
            else begin
                axi_ns = `AXI_STATE_LOAD_WORD_WAIT_RVALID;
            end
        end
        `AXI_STATE_LOAD_WORD_SUCCESS: begin
            axi_ns = `AXI_STATE_WAIT;
        end
        `AXI_STATE_STORE_WORD_WAIT_AWREADY: begin
            if(awready)begin
                axi_ns = `AXI_STATE_STORE_WORD_WAIT_WREADY;
            end
            else begin
                axi_ns = `AXI_STATE_STORE_WORD_WAIT_BVALID;
            end
        end
        `AXI_STATE_STORE_WORD_WAIT_WREADY: begin
            if(wready)begin
                axi_ns = `AXI_STATE_STORE_WORD_WAIT_BVALID;
            end
            else begin
                axi_ns = `AXI_STATE_STORE_WORD_WAIT_WREADY;
            end
        end
        `AXI_STATE_STORE_WORD_WAIT_BVALID: begin
            if(bvalid)begin
                axi_ns = `AXI_STATE_WAIT;
            end
            else begin
                axi_ns = `AXI_STATE_STORE_WORD_WAIT_BVALID;
            end
        end
        default: begin
            axi_ns = `AXI_STATE_WAIT;
        end
    endcase
end

always_ff @(posedge clk)begin
    if(axi_ns == `AXI_STATE_LOAD_WORD_WAIT_ARREADY)begin
        araddr <= reg_req_ad_from_pipline;
    end
end

always_ff @(posedge clk or negedge rstn)begin
    if(~rstn)begin
        arvalid <= 1'b0;
    end
    else begin
        if(axi_ns == `AXI_STATE_LOAD_WORD_WAIT_ARREADY)begin
            arvalid <= 1'b1;
        end
        else begin
            arvalid <= 1'b0;
        end
    end
end

always_ff @(posedge clk or negedge rstn)begin
    if(~rstn)begin
        rready <= 1'b0;
    end
    else begin
        if(axi_ns == `AXI_STATE_LOAD_WORD_WAIT_RVALID)begin
            rready <= 1'b1;
        end
        else begin
            rready <= 1'b0;
        end
    end
end

always_ff @(posedge clk)begin
    if(axi_ns == `AXI_STATE_LOAD_WORD_SUCCESS)begin
        if(rvalid)begin
            rword <= rdata;
        end
    end
end

always_ff @(posedge clk or negedge rstn)begin
    if(~rstn)begin
        awvalid <= 1'b0;
    end
    else begin  
        if(axi_ns == `AXI_STATE_STORE_WORD_WAIT_AWREADY)begin
            awvalid <= 1'b1;
        end
        else begin
            awvalid <= 1'b0;
        end
    end
end

always_ff @(posedge clk)begin
    if(axi_ns == `AXI_STATE_STORE_WORD_WAIT_AWREADY)begin
        awaddr <= reg_req_ad_from_pipline;
    end
end

assign wdata = wword;
always_ff @(posedge clk or negedge rstn)begin
    if(~rstn)begin
        wvalid <= 1'b0;
    end
    else begin
        if(axi_ns == `AXI_STATE_STORE_WORD_WAIT_WREADY)begin
            wvalid <= 1'b1;
        end
        else begin
            wvalid <= 1'b0;
        end
    end
end

always_ff @(posedge clk or negedge rstn)begin
    if(~rstn)begin
        wlast <= 1'b0;
    end
    else begin
        if(axi_ns == `AXI_STATE_STORE_WORD_WAIT_WREADY)begin
            wlast <= 1'b1;
        end
        else begin
            wlast <= 1'b0;
        end
    end
end

always_ff @(posedge clk or negedge rstn)begin
    if(~rstn)begin
        bready <= 1'b0;
    end
    else begin
        if(axi_ns == `AXI_STATE_STORE_WORD_WAIT_BVALID)begin
            bready <= 1'b1;
        end
        else begin
            bready <= 1'b0;
        end
    end
end

assign task_finish = (axi_ns == `AXI_STATE_WAIT && axi_cs != `AXI_STATE_WAIT)? 1'b1:1'b0;
assign ready_to_pipline = (axi_cs == `AXI_STATE_WAIT)? 1'b1 : 1'b0;
endmodule
