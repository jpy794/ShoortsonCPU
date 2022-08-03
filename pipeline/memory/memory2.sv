`include "cpu_defs.svh"

module Memory2 (
    input clk, rst_n,

    /* forward */
    output forward_req_t fwd_req,

    /* from dcache */
    input u32_t rd_dcache_data,
    input logic dcache_data_valid,

    /* from excp */
    input logic excp_flush,

    /* pipeline */
    input logic flush, next_rdy_in,
    output logic rdy_in,
    input memory1_memory2_pass_t pass_in,
    input excp_pass_t excp_pass_in,

    output memory2_writeback_pass_t pass_out,

    output excp_req_t excp_req
`ifdef DIFF_TEST
    ,input csr_t rd_csr
`endif
);

    /* pipeline start */
    memory1_memory2_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    logic dcache_data_stall;
    assign dcache_data_stall = eu_do & pass_in_r.dcache_req & ~dcache_data_valid;
    assign stall_o = stall_i | dcache_data_stall;

    logic valid_o;
    assign valid_o = pass_in_r.valid & ~stall_o;        // if ~valid_i, do not set exception valid

    /* for this stage */
    logic eu_do;
    assign eu_do = pass_in_r.valid & ~excp_pass_out.valid;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n | flush_i) begin
            pass_in_r.valid <= 1'b0;
            excp_pass_in_r.valid <= 1'b0;
            pass_in_r.dcache_req <= 1'b0;       // do not wait for the req if flush
        end else if(~stall_o) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end
    
    /* exeption */
    always_comb begin
        excp_pass_out = excp_pass_in_r;
        excp_pass_out.valid = excp_pass_out.valid & valid_o;
    end
    /* pipeline end */

    /* forward */
    // be careful of load-use stall
    assign fwd_req.valid = (pass_in_r.rd != 5'b0) && pass_in_r.is_wr_rd && eu_do;
    assign fwd_req.idx = pass_in_r.rd;
    assign fwd_req.data_valid = ~(pass_in_r.is_mem & ~pass_in_r.is_store);
    always_comb begin
        if(pass_in_r.is_wr_rd_pc_plus4) fwd_req.data = pass_in_r.pc_plus4;
        else                            fwd_req.data = pass_in_r.ex_out;
    end

    /* memory2 stage */

    /* from dcache */
    logic [7:0] mem_byte;
    always_comb begin
        unique case(pass_in_r.byte_en)
            2'b00:  mem_byte = rd_dcache_data[7:0];
            2'b01:  mem_byte = rd_dcache_data[15:8];
            2'b10:  mem_byte = rd_dcache_data[23:16];
            2'b11:  mem_byte = rd_dcache_data[31:24];
            // full case
        endcase
    end

    logic [15:0] mem_half_word;
    always_comb begin
        if(pass_in_r.byte_en[1])  mem_half_word = rd_dcache_data[31:16];
        else                      mem_half_word = rd_dcache_data[15:0];
    end

    u32_t mem_out;
    always_comb begin
        mem_out = rd_dcache_data;
        unique case(pass_in_r.byte_type)
            BYTE:       mem_out = pass_in_r.is_signed ? {{24{mem_byte[7]}}, mem_byte} : {{24{1'b0}}, mem_byte};
            HALF_WORD:  mem_out = pass_in_r.is_signed ? {{16{mem_half_word[15]}}, mem_half_word} : {{16{1'b0}}, mem_half_word};
            WORD:       mem_out = rd_dcache_data;
            default: ;
        endcase
    end

    /* sel ex_mem_out */
    u32_t ex_mem_out;
    always_comb begin
        if(pass_in_r.is_mem) ex_mem_out = mem_out;
        else                 ex_mem_out = pass_in_r.ex_out;
    end

    /* out to next stage */
    assign pass_out.valid = rdy_out;
    assign pass_out.ex_mem_out = ex_mem_out;
    
    `PASS(pc);
    `PASS(is_wr_rd);
    `PASS(is_wr_rd_pc_plus4);
    `PASS(pc_plus4);
    `PASS(rd);

`ifdef DIFF_TEST
    `PASS(is_wr_csr);
    `PASS(csr_addr);
    `PASS(csr_data);
    `PASS(inst);
    `PASS(is_ertn);
    `PASS(is_modify_csr);
    assign pass_out.csr = rd_csr;
    
    `PASS(is_ld);
    `PASS(is_st);
    `PASS(va);
    `PASS(pa);
    `PASS(st_data);
    `PASS(byte_valid);
`endif

endmodule