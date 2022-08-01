`include "cpu_defs.svh"

module Memory2 (
    input clk, rst_n,

    /* forward */
    output forward_req_t fwd_req,

    /* from dcache */
    input u32_t rd_dcache_data,
    input logic dcache_data_valid,

    /* pipeline */
    input logic flush, next_rdy_in,
    output logic rdy_in,
    input memory1_memory2_pass_t pass_in,
    input excp_pass_t excp_pass_in,

    output memory2_writeback_pass_t pass_out,

    output excp_req_t excp_req
);

    memory1_memory2_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pass_in_r.valid <= 1'b0;
        end else if(rdy_in) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    logic dcache_data_stall;
    logic rdy_out;
    logic mem2_flush, mem2_stall;
    assign mem2_flush = flush | ~pass_in_r.valid;
    assign mem2_stall = ~next_rdy_in | dcache_data_stall;

    assign rdy_in = mem2_flush | ~mem2_stall;
    assign rdy_out = ~mem2_flush & ~mem2_stall;        // only use this for pass_out.valid

    assign dcache_data_stall = pass_in_r.is_mem & ~pass_in_r.is_store & ~dcache_data_valid;

    /* forward */
    // be careful of load-use stall
    assign fwd_req.valid = (pass_in_r.rd != 5'b0) && pass_in_r.is_wr_rd && ~mem2_flush;
    assign fwd_req.idx = pass_in_r.rd;
    assign fwd_req.data_valid = ~(pass_in_r.is_mem & ~pass_in_r.is_store);
    always_comb begin
        if(pass_in_r.is_wr_rd_pc_plus4) fwd_req.data = pass_in_r.pc_plus4;
        else                            fwd_req.data = pass_in_r.ex_out;
    end

    /* exception */
    assign excp_req.excp_pass = excp_pass_in_r;
    assign excp_req.epc = pass_in_r.pc;

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
    `PASS(is_wr_csr);
    `PASS(csr_addr);
    `PASS(csr_data);

`ifdef DIFF_TEST
    `PASS(inst);
    `PASS(is_modify_csr);
    `PASS(csr);
    
    `PASS(is_ld);
    `PASS(is_st);
    `PASS(va);
    `PASS(pa);
    `PASS(st_data);
    `PASS(byte_valid);
`endif

endmodule