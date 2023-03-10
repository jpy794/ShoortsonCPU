`include "common_defs.svh"

module FakeCache (
    input logic clk, rst_n,

    input logic icache_req_valid, stall_icache,
    input u32_t icache_pa,
    output u32_t icache_data,
    output logic icache_busy, icache_data_valid,

    input logic dcache_req_valid, dcache_store, stall_dcache,
    input u32_t dcache_pa,
    input byte_type_t dcache_byte_type,
    input u32_t wr_dcache_data,
    output u32_t rd_dcache_data,
    output logic dcache_busy, dcache_data_valid,

    //AXI interface
    //read reqest
    output logic  [ 3:0] arid,
    output logic  [31:0] araddr,
    output logic  [ 7:0] arlen,
    output logic  [ 2:0] arsize,
    output logic  [ 1:0] arburst,
    output logic  [ 1:0] arlock,
    output logic  [ 3:0] arcache,
    output logic  [ 2:0] arprot,
    output logic         arvalid,
    input  logic         arready,
    //read back
    input  logic  [ 3:0] rid,
    input  logic  [31:0] rdata,
    input  logic  [ 1:0] rresp,
    input  logic         rlast,
    input  logic         rvalid,
    output logic         rready,
    //write request
    output logic  [ 3:0] awid,
    output logic  [31:0] awaddr,
    output logic  [ 7:0] awlen,
    output logic  [ 2:0] awsize,
    output logic  [ 1:0] awburst,
    output logic  [ 1:0] awlock,
    output logic  [ 3:0] awcache,
    output logic  [ 2:0] awprot,
    output logic         awvalid,
    input  logic         awready,
    //write data
    output logic  [ 3:0] wid,
    output logic  [31:0] wdata,
    output logic  [ 3:0] wstrb,
    output logic         wlast,
    output logic         wvalid,
    input  logic         wready,
    //write back
    input  logic  [ 3:0] bid,
    input  logic  [ 1:0] bresp,
    input  logic         bvalid,
    output logic         bready
);

    //unused signal
    assign awlock = '0;
    assign awcache ='0;
    assign awprot = '0;

    assign arlock = '0;
    assign arcache = '0;
    assign arprot = '0;

    assign awid = 4'b0001;      // dcache
    assign wid = 4'b0001;
    assign arid = (next_busy == ICACHE_BUSY) ? 4'b0000 : 4'b0001;      // icache / dcache

    //write
    assign awlen = 0;         // 1
    assign awsize = 3'b010;   // 2^2 = 4bytes
    assign awburst = 2'b01;   // INC

    assign wlast = wvalid;

    byte_type_t byte_type, byte_type_next;
    always_comb begin
        wstrb = 4'b0000;
        unique case(byte_type)
            BYTE:       wstrb[dcache_pa[1:0]] = 1'b1;
            HALF_WORD:  wstrb[dcache_pa[1:0]+:2] = 2'b11;
            WORD:       wstrb = 4'b1111;
            default: ;
        endcase
    end

    //read
    assign arlen = 0;
    assign arsize = 3'b010;
    assign arburst = 2'b01;

    typedef enum logic [3:0] { 
        S_IDLE,
        S_READ_WAIT_DATA,
        S_READ_WAIT_ADDR,
        S_WRITE_WAIT_DATA,
        S_WRITE_WAIT_ADDR,
        S_WRITE_WAIT_RESP
    } state_t;
    state_t state, next;

    typedef enum logic [1:0] { 
        ICACHE_BUSY,
        DCACHE_WR_BUSY,
        DCACHE_RD_BUSY,
        NO_BUSY
    } busy_t;
    busy_t busy, next_busy;

    logic no_busy;
    assign no_busy = (busy == NO_BUSY);
    assign icache_busy = ~no_busy | dcache_req_valid;
    assign dcache_busy = ~no_busy;

    assign icache_data_valid = rready && (busy == ICACHE_BUSY);
    assign dcache_data_valid = rready && (busy == DCACHE_RD_BUSY);

    assign icache_data = rdata;
    assign rd_dcache_data = rdata;

    u32_t wr_data, wr_data_next;
    assign wdata = wr_data;

    u32_t addr, addr_next;
    assign araddr = addr;
    assign awaddr = addr;

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            state <= S_IDLE;
            busy <= NO_BUSY;
        end else begin
            state <= next;
            busy <= next_busy;
            wr_data <= wr_data_next;
            byte_type <= byte_type_next;
            addr <= addr_next;
        end
    end

    always_comb begin
        next = state;
        next_busy = busy;

        wr_data_next = wr_data;
        byte_type_next = byte_type;
        addr_next = addr;

        arvalid = 1'b0;
        rready = 1'b0;

        awvalid = 1'b0;
        wvalid = 1'b0;
        bready = 1'b0;

        case(state)
            S_IDLE: begin
                wr_data_next = wr_dcache_data;
                byte_type_next = dcache_byte_type;
                next_busy = NO_BUSY;
                if(dcache_req_valid) begin
                    addr_next = dcache_pa;
                    if(dcache_store) begin
                        next_busy = DCACHE_WR_BUSY;
                        next = S_WRITE_WAIT_ADDR;
                    end else begin
                        next_busy = DCACHE_RD_BUSY;
                        next = S_READ_WAIT_ADDR;
                    end
                end else if(icache_req_valid) begin
                    addr_next = icache_pa;
                    next_busy = ICACHE_BUSY;
                    next = S_READ_WAIT_ADDR;
                end
            end
            S_READ_WAIT_ADDR: begin
                arvalid = 1'b1;
                if(arready) next = S_READ_WAIT_DATA;
            end
            S_READ_WAIT_DATA: begin                
                if(rvalid) begin
                    if(busy == ICACHE_BUSY) begin
                        if(~stall_icache) begin
                            rready = 1'b1;
                            next = S_IDLE;
                            next_busy = NO_BUSY;
                        end
                    end else begin
                        if(~stall_dcache) begin
                            rready = 1'b1;
                            next = S_IDLE;
                            next_busy = NO_BUSY;
                        end
                    end
                end
            end
            S_WRITE_WAIT_ADDR: begin
                awvalid = 1'b1;
                if(awready) next = S_WRITE_WAIT_DATA;
            end
            S_WRITE_WAIT_DATA: begin
                wvalid = 1'b1;
                if(wready) next = S_WRITE_WAIT_RESP;
            end
            S_WRITE_WAIT_RESP: begin
                bready = 1'b1;
                if(bvalid) begin
                    next = S_IDLE;
                    next_busy = NO_BUSY;
                end
            end
            default: ;
        endcase
    end


endmodule