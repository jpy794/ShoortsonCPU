`include "cache.svh"

module To_AXI (
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
    input logic bvaild
);
// logic [`AXI_ID_WIDTH]arid;
// logic [`ADDRESS_WIDTH]araddr;
// logic [`AXI_LEN_WIDTH]arlen;
// logic [`AXI_SIZE_WIDTH]arsize;
// logic [`AXI_BURST_WIDTH]arburst;
// logic [`AXI_LOCK_WIDTH]arlock;
// logic [`AXI_CACHE_WIDTH]arcache;
// logic [`AXI_PROT_WIDTH]arprot;
// logic arvalid;
// logic arready;
// logic [`AXI_ID_WIDTH]awid;
// logic [`ADDRESS_WIDTH]awaddr;
// logic [`AXI_LEN_WIDTH]awlen;
// logic [`AXI_SIZE_WIDTH]awsize;
// logic [`AXI_LOCK_WIDTH]awlock;
// logic [`AXI_CACHE_WIDTH]awcache;
// logic [`AXI_PROT_WIDTH]awprot;
// logic awvalid;
// logic awready;
// logic [`AXI_ID_WIDTH]rid;
// logic [`DATA_WIDTH]rdata;
// logic [`AXI_RESP_WIDTH]rresp;
// logic rlast;
// logic rvalid;
// logic rready;
// logic [`AXI_ID_WIDTH]wid;
// logic [`DATA_WIDTH]wdata;
// logic [`AXI_STRB_WIDTH]wstrb;
// logic wlast;
// logic wvaild;
// logic wready;
// logic [`AXI_ID_WIDTH]bid;
// logic [`AXI_RESP_WIDTH]bresp;
// logic bready;
// logic bvaild;
assign wid = `AXI_WRITE_ID;
assign arlock = `AXI_LOCK_NORMAL;
assign arcache = `AXI_CACHE_CACHE;
assign awcache = `AXI_CACHE_CACHE;

assign arprot = `AXI_PORT_DATA;
assign awprot = `AXI_PORT_DATA;
assign awid = `AXI_WRITE_ID;
assign awlock = `AXI_LOCK_NORMAL;

logic [`AXI_STATE_WIDTH]cs, ns;

logic [`AXI_REQ_WIDTH]reg_req_from_pipline;
logic [`ADDRESS_WIDTH]reg_ad;

always_ff @(posedge clk)begin
    if(~rstn)begin
        reg_req_from_pipline <= `REQ_TO_AXI_NONE;
    end
    else begin
        if(ns == `AXI_STATE_WAIT && cs != `AXI_STATE_WAIT)begin
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
        reg_ad <= ad;
    end
end

always_ff @(posedge clk)begin
    if(!rstn)begin
        cs <= `AXI_STATE_WAIT;
    end
    else begin
        cs <= ns;
    end
end

always_comb begin
    unique case(cs)
        `AXI_STATE_WAIT: begin
            unique case(reg_req_from_pipline)
                `REQ_TO_AXI_LOAD_BLOCK: begin
                    ns = `AXI_STATE_REQ_LOAD_BLOCK;
                end
                `REQ_TO_AXI_LOAD_WORD: begin
                    ns = `AXI_STATE_REQ_LOAD_WORD;
                end
                `REQ_TO_AXI_WRITE_BLOCK: begin
                    ns = `AXI_STATE_REQ_STORE_BLOCK;
                end
                `REQ_TO_AXI_WRITE_WORD: begin
                    ns = `AXI_STATE_REQ_STORE_WORD;
                end
                default: begin
                    ns = `AXI_STATE_WAIT;
                end
            endcase
        end
        `AXI_STATE_REQ_LOAD_BLOCK: begin
            ns = `AXI_STATE_LOAD_BLOCK_WAIT_ARREADY;
        end
        `AXI_STATE_LOAD_BLOCK_WAIT_ARREADY: begin
            if(arready)begin
                ns = `AXI_STATE_LOAD_BLOCK_WAIT_RVALID;
            end
            else begin
                ns = `AXI_STATE_LOAD_BLOCK_WAIT_ARREADY;
            end
        end
        `AXI_STATE_LOAD_BLOCK_WAIT_RVALID: begin
            if(rvalid)begin
                ns = `AXI_STATE_LOAD_BLOCK_DATA0;
            end
            else begin
                ns = `AXI_STATE_LOAD_BLOCK_WAIT_RVALID;
            end
        end
        `AXI_STATE_LOAD_BLOCK_DATA0: begin
            ns = `AXI_STATE_LOAD_BLOCK_DATA1;
        end
        `AXI_STATE_LOAD_BLOCK_DATA1: begin
            ns = `AXI_STATE_LOAD_BLOCK_DATA2;
        end
        `AXI_STATE_LOAD_BLOCK_DATA2: begin
            ns = `AXI_STATE_LOAD_BLOCK_DATA3;
        end
        `AXI_STATE_LOAD_BLOCK_DATA3: begin
            ns = `AXI_STATE_LOAD_BLOCK_DATA4;
        end
        `AXI_STATE_LOAD_BLOCK_DATA4: begin
            ns = `AXI_STATE_LOAD_BLOCK_DATA5;
        end
        `AXI_STATE_LOAD_BLOCK_DATA5: begin
            ns = `AXI_STATE_LOAD_BLOCK_DATA6;
        end
        `AXI_STATE_LOAD_BLOCK_DATA6: begin
            ns = `AXI_STATE_LOAD_BLOCK_DATA7;
        end
        `AXI_STATE_LOAD_BLOCK_DATA7: begin
            // ns = `AXI_STATE_LOAD_BLOCK_FINISH;
            ns = `AXI_STATE_WAIT;
        end
        `AXI_STATE_REQ_STORE_BLOCK: begin
            ns = `AXI_STATE_STORE_BLOCK_WAIT_AWREADY;
        end
        `AXI_STATE_STORE_BLOCK_WAIT_AWREADY: begin
            if(awready)begin
                ns = `AXI_STATE_STORE_BLOCK_WAIT_WREADY; 
            end
            else begin
                ns = `AXI_STATE_STORE_BLOCK_WAIT_AWREADY;
            end
        end
        `AXI_STATE_STORE_BLOCK_WAIT_WREADY: begin
            if(wready)begin
                ns = `AXI_STATE_STORE_BLOCK_DATA0;
            end
            else begin
                ns = `AXI_STATE_STORE_BLOCK_WAIT_WREADY;
            end
        end
        `AXI_STATE_STORE_BLOCK_DATA0: begin
            ns = `AXI_STATE_STORE_BLOCK_DATA1;
        end
        `AXI_STATE_STORE_BLOCK_DATA1: begin
            ns = `AXI_STATE_STORE_BLOCK_DATA2;
        end
        `AXI_STATE_STORE_BLOCK_DATA2: begin
            ns = `AXI_STATE_STORE_BLOCK_DATA3;
        end
        `AXI_STATE_STORE_BLOCK_DATA3: begin
            ns = `AXI_STATE_STORE_BLOCK_DATA4;
        end
        `AXI_STATE_STORE_BLOCK_DATA4: begin
            ns = `AXI_STATE_STORE_BLOCK_DATA5;
        end
        `AXI_STATE_STORE_BLOCK_DATA5: begin
            ns = `AXI_STATE_STORE_BLOCK_DATA6;
        end
        `AXI_STATE_STORE_BLOCK_DATA6: begin
            ns = `AXI_STATE_STORE_BLOCK_DATA7;
        end
        `AXI_STATE_STORE_BLOCK_DATA7: begin
            ns = `AXI_STATE_STORE_BLOCK_WAIT_BVALID;
        end
        `AXI_STATE_STORE_BLOCK_WAIT_BVALID: begin
            if(bvaild)begin
                ns = `AXI_STATE_WAIT;
            end
            else begin
                ns = `AXI_STATE_STORE_BLOCK_WAIT_BVALID;
            end
        end
        `AXI_STATE_REQ_LOAD_WORD: begin
            ns = `AXI_STATE_LOAD_WORD_WAIT_ARREADY;
        end
        `AXI_STATE_LOAD_WORD_WAIT_ARREADY: begin
            if(arready)begin
                ns = `AXI_STATE_LOAD_WORD_WAIT_RVALID;
            end
            else begin
                ns = `AXI_STATE_LOAD_WORD_WAIT_ARREADY;
            end
        end
        `AXI_STATE_LOAD_WORD_WAIT_RVALID: begin
            if(rvalid)begin
                ns = `AXI_STATE_LOAD_WORD_SUCCESS;
            end
            else begin 
                ns = `AXI_STATE_LOAD_WORD_WAIT_RVALID;
            end
        end
        `AXI_STATE_LOAD_WORD_SUCCESS: begin
            ns = `AXI_STATE_WAIT;
        end
        `AXI_STATE_REQ_STORE_WORD: begin
            ns = `AXI_STATE_STORE_WORD_WAIT_AWREADY;
        end
        `AXI_STATE_STORE_WORD_WAIT_AWREADY: begin
            if(awready)begin
                ns = `AXI_STATE_STORE_WORD_WAIT_WREADY;
            end
            else begin
                ns = `AXI_STATE_STORE_WORD_WAIT_AWREADY;
            end
        end
        `AXI_STATE_STORE_WORD_WAIT_WREADY: begin
            ns = `AXI_STATE_STORE_WORD_WAIT_BVALID;
        end
        `AXI_STATE_STORE_WORD_WAIT_BVALID: begin
            if(bvaild)begin
                ns = `AXI_STATE_WAIT;
            end
            else begin
                ns = `AXI_STATE_STORE_WORD_WAIT_BVALID;
            end
        end
    endcase
end

always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_LOAD_BLOCK: begin
            arid <= `AXI_READ_ID;
        end
        `AXI_STATE_REQ_LOAD_WORD: begin
            arid <= `AXI_READ_ID;
        end
    endcase
end

always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_LOAD_BLOCK: begin
            araddr <= {reg_ad[31:4], {4{1'b0}}};
        end
        `AXI_STATE_REQ_LOAD_WORD: begin
            araddr <= reg_ad;
        end
    endcase
end

always_ff @(posedge clk)begin
    if(~rstn)begin
        arvalid <= `UNREADY;
    end
    else begin
        unique case(ns)
            `AXI_STATE_WAIT: arvalid <= `UNREADY;
            `AXI_STATE_REQ_LOAD_BLOCK: begin
                arvalid <= `READY;
            end
            `AXI_STATE_REQ_LOAD_WORD: begin
                arvalid <= `READY;
            end
            `AXI_STATE_LOAD_BLOCK_WAIT_RVALID: begin
                arvalid <= `UNREADY;
            end
            `AXI_STATE_LOAD_WORD_WAIT_RVALID: begin
                arvalid <= `UNREADY;
            end
        endcase
    end
end

always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_LOAD_BLOCK: begin
            arburst <= `AXI_BURST_INCR;
        end
        `AXI_STATE_REQ_LOAD_WORD: begin
            arburst <= `AXI_BURST_FIXED;
        end
    endcase
end



always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_LOAD_BLOCK: begin
            arlen <= `AXI_LEN_BLOCK;
        end
        `AXI_STATE_REQ_LOAD_WORD: begin
            arlen <= `AXI_LEN_SINGAL;
        end
    endcase
end

always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_LOAD_BLOCK: begin
            arsize <= `AXI_SIZE_WORD;
        end
        `AXI_STATE_REQ_LOAD_WORD: begin
            // unique case(rword_en)
            //     4'b1111: begin
            //         arsize <= `AXI_SIZE_WORD;
            //     end
            //     4'b1100: begin
            //         arsize <= `AXI_SIZE_HALF_WORD;
            //     end
            //     4'b0011: begin
            //         arsize <= `AXI_SIZE_HALF_WORD;
            //     end
            //     default: begin
            //         arsize <= `AXI_SIZE_BYTE;
            //     end
            // endcase
            unique case(rword_en)
                `DCACHE_REQ_REN_WORD: begin
                    arsize <= `AXI_SIZE_WORD;
                end
                `DCACHE_REQ_REN_HALF_WORD: begin
                    arsize <= `AXI_SIZE_HALF_WORD;
                end
                `DCACHE_REQ_REN_BYTE: begin
                    arsize <= `AXI_SIZE_BYTE;
                end
            endcase
        end
    endcase
end



always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_STORE_BLOCK: begin
            awaddr <= {reg_ad[31:4], {4{1'b0}}};
        end
        `AXI_STATE_REQ_STORE_WORD: begin
            awaddr <= reg_ad;
        end
    endcase
end

always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_STORE_BLOCK: begin
            awlen <= `AXI_LEN_BLOCK;
        end
        `AXI_STATE_REQ_STORE_WORD: begin
            awlen <= `AXI_LEN_SINGAL;
        end
    endcase 
end
always_ff @(posedge clk)begin
    // unique case(ns)
    //     `AXI_STATE_REQ_STORE_BLOCK: begin
    //         awsize <= `AXI_SIZE_WORD;
    //     end
    //     `AXI_STATE_REQ_STORE_WORD: begin
    //         // unique case(wword_en)
    //         //     4'b1111: begin
    //         //         awsize <= `AXI_SIZE_WORD;
    //         //     end
    //         //     4'b1100: begin
    //         //         awsize <= `AXI_SIZE_HALF_WORD;
    //         //     end
    //         //     4'b0011: begin
    //         //         awsize <= `AXI_SIZE_HALF_WORD;
    //         //     end
    //         //     default: begin
    //         //         awsize <= `AXI_SIZE_BYTE;
    //         //     end
    //         // endcase
    //     end
    // endcase
    awsize <= `AXI_SIZE_WORD; 
end
always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_STORE_BLOCK: begin
            awburst <= `AXI_BURST_INCR;
        end
        `AXI_STATE_REQ_STORE_WORD: begin
            awburst <= `AXI_BURST_FIXED;
        end
    endcase 
end
always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_STORE_BLOCK: begin
            awcache <= `AXI_CACHE_CACHE;
        end
        `AXI_STATE_REQ_STORE_WORD: begin
            awcache <= `AXI_CACHE_CACHE;
        end
    endcase 
end
always_ff @(posedge clk)begin
    if(~rstn)begin
        awvalid <= `UNREADY;
    end
    else begin
        unique case(ns)
            `AXI_STATE_REQ_STORE_BLOCK: begin
                awvalid <= `READY;
            end
            `AXI_STATE_REQ_STORE_WORD: begin
                awvalid <= `READY;
            end
            `AXI_STATE_STORE_BLOCK_WAIT_WREADY: begin
                awvalid <= `UNREADY;
            end
            `AXI_STATE_STORE_WORD_WAIT_WREADY: begin
                awvalid <= `UNREADY;
            end
            `AXI_STATE_WAIT: begin
                awvalid <= `UNREADY;
            end
        endcase 
    end
end

always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_LOAD_BLOCK: begin
            rready <= `READY;
        end
        `AXI_STATE_REQ_LOAD_WORD: begin
            rready <= `READY;
        end
        `AXI_STATE_WAIT: begin
            rready <= `UNREADY;
        end
    endcase
end

// always_ff @(posedge clk)begin
//     awprot <= `AXI_PORT_INS;
// end

// always_ff @(posedge clk)begin
//     awlock <= `AXI_LOCK_NORMAL;
// end


always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_STORE_WORD: begin
            wdata <= wword;
        end
        `AXI_STATE_STORE_BLOCK_DATA0: begin
            wdata <= wblock[31:0];
        end
        `AXI_STATE_STORE_BLOCK_DATA1: begin
            wdata <= wblock[63:32];
        end
        `AXI_STATE_STORE_BLOCK_DATA2: begin
            wdata <= wblock[95:64];
        end
        `AXI_STATE_STORE_BLOCK_DATA3: begin
            wdata <= wblock[127:96];
        end
        `AXI_STATE_STORE_BLOCK_DATA4: begin
            wdata <= wblock[159:128];
        end
        `AXI_STATE_STORE_BLOCK_DATA5: begin
            wdata <= wblock[191:160];
        end
        `AXI_STATE_STORE_BLOCK_DATA6: begin
            wdata <= wblock[223:192];
        end
        `AXI_STATE_STORE_BLOCK_DATA7: begin
            wdata <= wblock[255:224];
        end
    endcase
end



always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_REQ_STORE_BLOCK: begin
            wstrb <= 4'b1111;
        end
        `AXI_STATE_REQ_STORE_WORD: begin
            wstrb <= wword_en;
        end
    endcase
end

always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_STORE_BLOCK_DATA7: begin
            wlast <= 1'b1;
        end
        `AXI_STATE_STORE_WORD_WAIT_BVALID: begin
            wlast <= 1'b1;
        end
        default: begin
            wlast <= 1'b0;
        end
    endcase
end

always_ff @(posedge clk)begin
    if(~rstn)begin
        wvalid <= `UNREADY;
    end
    else begin
        unique case(ns)
            `AXI_STATE_REQ_STORE_BLOCK: begin
                wvalid <= 1'b1;
            end
            `AXI_STATE_REQ_STORE_WORD: begin
                wvalid <= 1'b1;
            end
            `AXI_STATE_STORE_BLOCK_WAIT_BVALID: begin
                wvalid <= 1'b0;
            end
            `AXI_STATE_STORE_WORD_WAIT_BVALID: begin
                wvalid <= 1'b0;
            end
        endcase
    end
end

always_ff @(posedge clk)begin
    if(~rstn)begin
        bready <= `UNREADY;
    end 
    else begin
        unique case(ns)
            `AXI_STATE_STORE_BLOCK_WAIT_BVALID: begin
                bready <= `READY;
            end
            `AXI_STATE_STORE_WORD_WAIT_BVALID: begin
                bready <= `READY;
            end
            `AXI_STATE_WAIT: begin
                bready <= `UNREADY;
            end
        endcase
    end
end

always_ff @(posedge clk)begin
    if(ns == `AXI_STATE_WAIT && cs != `AXI_STATE_WAIT)begin
        task_finish <= 1'b1;
    end
    else begin
        task_finish <= 1'b0;
    end
end

always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_LOAD_BLOCK_DATA0: begin
            rblock[31:0] <= rdata;
        end
        `AXI_STATE_LOAD_BLOCK_DATA1: begin
            rblock[63:32] <= rdata;
        end
        `AXI_STATE_LOAD_BLOCK_DATA2: begin
            rblock[95:64] <= rdata;
        end
        `AXI_STATE_LOAD_BLOCK_DATA3: begin
            rblock[127:96] <= rdata;
        end
        `AXI_STATE_LOAD_BLOCK_DATA4: begin
            rblock[159:128] <= rdata;
        end
        `AXI_STATE_LOAD_BLOCK_DATA5: begin
            rblock[191:160] <= rdata;
        end
        `AXI_STATE_LOAD_BLOCK_DATA6: begin
            rblock[223:192] <= rdata;
        end
        `AXI_STATE_LOAD_BLOCK_DATA7: begin
            rblock[255:224] <= rdata;
        end
    endcase
end

always_ff @(posedge clk)begin
    unique case(ns)
        `AXI_STATE_LOAD_WORD_SUCCESS: begin
            rword <= rdata;
        end
    endcase
end


assign ready_to_pipline = (cs == `AXI_STATE_WAIT)? `READY: `UNREADY;

// always_ff @(posedge clk)begin
//     rword_en <= 4'b1111;
// end

// blk_mem_gen_0 blk(.s_aclk(clk), .s_aresetn(rst_n),
//                     .s_axi_araddr(araddr), .s_axi_arburst(arburst), .s_axi_arid(arid), .s_axi_arlen(arlen), .s_axi_arready(arready), .s_axi_arsize(arsize), .s_axi_arvalid(arvalid),
//                     .s_axi_awaddr(awaddr), .s_axi_awburst(awburst), .s_axi_awid(awid), .s_axi_awlen(awlen), .s_axi_awready(awready), .s_axi_awsize(awsize), .s_axi_awvalid(awvalid), 
//                     .s_axi_bid(bid), .s_axi_bready(bready), .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), 
//                     .s_axi_rdata(rdata), .s_axi_rid(rid), .s_axi_rlast(rlast), .s_axi_rready(rready), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), 
//                     .s_axi_wdata(wdata), .s_axi_wlast(wlast), .s_axi_wready(wready), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid));
endmodule