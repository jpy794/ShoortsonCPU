`include "cache.svh"

module AXI_bridge (
    input logic clk,
    input logic rstn,

    input logic [`AXI_REQ_WIDTH]req,
    input logic [`BLOCK_WIDTH]wblock,
    input logic [`DATA_WIDTH]wword,
    input logic [`AXI_STRB_WIDTH]wword_en,
    input logic [`ADDRESS_WIDTH]ad,

    output logic task_finish,
    output logic ready_to_pipline,
    output logic [`BLOCK_WIDTH]rblock,
    output logic [`DATA_WIDTH]rword,
    input logic [2:0]rword_en,


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
    
assign arid = `AXI_READ_ID;
assign wid = `AXI_WRITE_ID;
assign arlock = `AXI_LOCK_NORMAL;
assign arcache = `AXI_CACHE_CACHE;
assign awcache = `AXI_CACHE_CACHE;

assign arprot = `AXI_PORT_DATA;
assign awprot = `AXI_PORT_DATA;
assign awid = `AXI_WRITE_ID;
assign awlock = `AXI_LOCK_NORMAL;

assign arburst = `AXI_BURST_INCR;
assign awburst = `AXI_BURST_INCR;
assign awsize = `AXI_SIZE_WORD;

axi_state_t axi_cs, axi_ns;

logic [`AXI_REQ_WIDTH]reg_req_from_pipline;
logic [`ADDRESS_WIDTH]reg_req_ad_from_pipline;
logic [2:0]reg_rword_en;
logic [`BLOCK_WIDTH]reg_wblock;
logic [7:0]reg_wblock_num;

always_ff @(posedge clk)begin
    if(~rstn)begin
        reg_req_from_pipline <= `REQ_TO_AXI_NONE;
    end
    else begin
        if((axi_cs == AXI_STATE_LOAD_WORD_WAIT_RVALID && rvalid) ||
            (axi_cs == AXI_STATE_LOAD_BLOCK_TRANSFER && rlast)  ||
            (axi_cs == AXI_STATE_STORE_WORD_WAIT_BVALID && bvalid) ||
            (axi_cs == AXI_STATE_STORE_BLOCK_WAIT_BVALID && bvalid) )begin
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

always_ff @(posedge clk)begin
    if(req != `REQ_TO_AXI_NONE)begin
        reg_rword_en <= rword_en;
    end
end



always_ff @(posedge clk)begin
    if(~rstn)begin
        axi_cs <= AXI_STATE_WAIT;
        arvalid <= 1'b0;
        awvalid <= 1'b0;
        rready <= 1'b0;
        bready <= 1'b0;
        wvalid <= 1'b0;
        wlast <= 1'b0;
    end
    else begin
        unique case(axi_cs)
            AXI_STATE_WAIT: begin
                unique case(reg_req_from_pipline)
                    `REQ_TO_AXI_LOAD_WORD: begin
                        axi_cs <= AXI_STATE_LOAD_WORD_WAIT_ARREADY;
                        araddr <= reg_req_ad_from_pipline;
                        arvalid <= 1'b1;
                        arlen <= 8'h0;
                        arsize <= reg_rword_en;
                    end
                    `REQ_TO_AXI_WRITE_WORD: begin
                        awaddr <= {reg_req_ad_from_pipline[31:2], {2{1'b0}}};
                        axi_cs <= AXI_STATE_STORE_WORD_WAIT_AWREADY;
                        wdata <= wword;
                        wstrb <= wword_en;
                        awvalid <= 1'b1;
                        wlast <= 1'b1;
                        awlen <= 8'h0;
                    end
                    `REQ_TO_AXI_WRITE_BLOCK: begin
                        awaddr <= {reg_req_ad_from_pipline[31:5], {5{1'b0}}};
                        axi_cs <= AXI_STATE_STORE_BLOCK_WAIT_AWREADY;
                        wdata <= wblock[31:0];
                      //  reg_wblock <= {{32{1'b0}}, reg_wblock[255:32]};
                        wstrb <= 4'b1111;
                        awvalid <= 1'b1;
                        wlast <= 1'b0;
                        awlen <= 8'h7;
                        reg_wblock <= {{32{1'b0}}, wblock[255:32]};
                        reg_wblock_num <= 8'hff;
                    end
                    `REQ_TO_AXI_LOAD_BLOCK: begin
                        araddr <= {reg_req_ad_from_pipline[31:5], {5{1'b0}}};
                        axi_cs <= AXI_STATE_LOAD_BLOCK_WAIT_ARREADY;
                        arvalid <= 1'b1;
                        arlen <= 8'h7;
                        arsize <= 3'h2;
                    end
                    default: axi_cs <= AXI_STATE_WAIT;
                endcase
            end
            AXI_STATE_LOAD_WORD_WAIT_ARREADY: begin
                if(arready)begin
                    axi_cs <= AXI_STATE_LOAD_WORD_WAIT_RVALID;
                    arvalid <= 1'b0;
                    rready <= 1'b1;
                end
            end
            AXI_STATE_LOAD_WORD_WAIT_RVALID: begin
                if(rvalid)begin
                    rready <= 1'b0;
                    axi_cs <= AXI_STATE_WAIT;
                    rword <= rdata;
                end
            end
            AXI_STATE_STORE_WORD_WAIT_AWREADY: begin
                if(awready)begin
                    awvalid <= 1'b0;
                    axi_cs <= AXI_STATE_STORE_WORD_WAIT_WREADY;
                    wvalid <= 1'b1;
                end
            end
            AXI_STATE_STORE_WORD_WAIT_WREADY: begin
                if(wready)begin
                    wvalid <= 1'b0;
                    axi_cs <= AXI_STATE_STORE_WORD_WAIT_BVALID;
                    bready <= 1'b1;
                end
            end
            AXI_STATE_STORE_WORD_WAIT_BVALID: begin
                if(bvalid)begin
                    wlast <= 1'b0;
                    axi_cs <= AXI_STATE_WAIT;
                    bready <= 1'b0;
                end
            end
            AXI_STATE_LOAD_BLOCK_WAIT_ARREADY: begin
                if(arready)begin
                    axi_cs <= AXI_STATE_LOAD_BLOCK_TRANSFER;
                    arvalid <= 1'b0;
                    rready <= 1'b1;
                end
            end
            AXI_STATE_LOAD_BLOCK_TRANSFER: begin
                if(rvalid)begin
                    if(rlast)begin
                        rready <= 1'b0;
                        axi_cs <= AXI_STATE_WAIT;
                    end
                    rblock <= {rdata, rblock[255:32]};
                end
            end
            AXI_STATE_STORE_BLOCK_WAIT_AWREADY: begin
                if(awready)begin
                    awvalid <= 1'b0;
                    axi_cs <= AXI_STATE_STORE_BLOCK_TRANSFER;
                    wvalid <= 1'b1;
                end
            end
            AXI_STATE_STORE_BLOCK_TRANSFER: begin
                if(wready)begin
                    wdata <= reg_wblock[31:0];
                    reg_wblock <= {{32{1'b0}}, reg_wblock[255:32]};
                    reg_wblock_num <= {1'b0, reg_wblock_num[7:1]};
                    if(reg_wblock_num == 8'h1)begin
                        wlast <= 1'b0;
                        axi_cs <= AXI_STATE_STORE_BLOCK_WAIT_BVALID;
                        bready <= 1'b1;
                        wvalid <= 1'b0;
                    end
                    else if(reg_wblock_num == 8'h3)begin
                        wlast <= 1'b1;
                    end
                end
            end
            AXI_STATE_STORE_BLOCK_WAIT_BVALID:begin
                if(bvalid)begin
                    axi_cs <= AXI_STATE_WAIT;
                    bready <= 1'b0;
                end
            end
            default: ;
        endcase 
    end
end

always_ff @(posedge clk)begin
    unique case(axi_cs)
        AXI_STATE_LOAD_WORD_WAIT_RVALID: begin
            if(rvalid)begin
                task_finish <= 1'b1;
            end
        end
        AXI_STATE_STORE_WORD_WAIT_BVALID: begin
            if(bvalid)begin
                task_finish <= 1'b1;
            end
        end
        AXI_STATE_STORE_BLOCK_WAIT_BVALID: begin
            if(bvalid)begin
                task_finish <= 1'b1;
            end
        end
        AXI_STATE_LOAD_BLOCK_TRANSFER: begin
            if(rlast && rvalid)begin
                task_finish <= 1'b1;
            end
        end
        default: begin
            task_finish <= 1'b0;
        end
    endcase
end
assign ready_to_pipline = (axi_cs == AXI_STATE_WAIT)? 1'b1 : 1'b0;
endmodule
