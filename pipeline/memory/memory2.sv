`include "cpu_defs.svh"

module Memory2 (
    input clk, rst_n,

    /* forward */
    output forward_req_t fwd_req,

    /* from dcache */
    input logic dcache_ready,
    input u32_t rd_dcache_data,

    /* ctrl */
    output logic dcache_stall,

    /* pipeline */
    input logic is_stall,
    input logic is_flush,
    input memory1_memory2_pass_t pass_in,

    output memory2_writeback_pass_t pass_out
);

    memory1_memory2_pass_t pass_in_r;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pass_in_r.is_flush <= 1'b1;
        end else if(~is_stall) begin
            pass_in_r <= pass_in;
        end
    end

    logic mem2_flush = is_flush | pass_in_r.is_flush;

    /* forward */
    // be careful of load-use stall
    assign fwd_req.valid = pass_in_r.is_wr_rd;
    assign fwd_req.idx = pass_in_r.rd;
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
        if(pass_in_r.byte_en[0])  mem_half_word = rd_dcache_data[31:16];
        else            mem_half_word = rd_dcache_data[15:0];
    end

    u32_t mem_out;
    always_comb begin
        unique case(pass_in_r.byte_type)
            BYTE:       mem_out = pass_in_r.is_signed ? {{24{mem_byte[7]}}, mem_byte} : {{24{1'b0}}, mem_byte};
            HALF_WORD:  mem_out = pass_in_r.is_signed ? {{16{mem_half_word[15]}}, mem_half_word} : {{16{1'b0}}, mem_half_word};
            WORD:       mem_out = rd_dcache_data;
        endcase
    end

    /* sel ex_mem_out */
    u32_t ex_mem_out;
    always_comb begin
        if(pass_in_r.is_mem) ex_mem_out = mem_out;
        else                 ex_mem_out = pass_in_r.ex_out;
    end

    /* out for ctrl */
    assign dcache_stall = ~dcache_ready & pass_in_r.is_mem & ~mem2_flush;


    /* out to next stage */
    assign pass_out.is_flush = mem2_flush | dcache_stall;
    assign pass_out.ex_mem_out = ex_mem_out;
    
    `PASS(pc);
    `PASS(inst);
    `PASS(is_wr_rd);
    `PASS(is_wr_rd_pc_plus4);
    `PASS(pc_plus4);
    `PASS(rd);
    `PASS(is_wr_csr);
    `PASS(csr_addr);

`ifdef DIFF_TEST
    `PASS(inst);
    
    `PASS(is_ld);
    `PASS(is_st);
    `PASS(va);
    `PASS(pa);
    `PASS(st_data);
`endif

endmodule