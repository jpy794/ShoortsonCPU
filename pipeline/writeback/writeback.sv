`include "cpu_defs.svh"

module Writeback (
    input clk, rst_n,

    /* to regfile */
    output reg_idx_t reg_idx,
    output logic reg_we,
    output u32_t reg_data,

    /* to csr */
    output csr_addr_t csr_addr,
    output logic csr_we,
    output u32_t csr_data,

    /* pipeline */
    input logic is_stall,
    input logic is_flush,

    input memory2_writeback_pass_t pass_in,
    input excp_pass_t excp_pass_in,
    /* debug */
    output memory2_writeback_pass_t pass_out,
    /* to exception */
    output logic wb_flush,
    output excp_pass_t excp_pass_out,
    output virt_t pc_out,
    output logic inst_ertn
);

    memory2_writeback_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            pass_in_r.is_flush <= 1'b1;
            excp_pass_in_r.valid <= 1'b0;
        end else if(~is_stall) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    assign wb_flush = is_flush | pass_in_r.is_flush;

    /* writeback stage */

    // TODO
    assign inst_ertn = 1'b0;
    assign excp_pass_out = excp_pass_in_r;
    assign pc_out = pass_in_r.pc;
    assign pass_out = pass_in_r;
    
    assign reg_idx = pass_in_r.rd;
    assign reg_data = pass_in_r.is_wr_rd_pc_plus4 ? pass_in_r.pc_plus4 : pass_in_r.ex_mem_out;
    assign reg_we = ~wb_flush & pass_in_r.is_wr_rd;

    assign csr_addr = pass_in_r.csr_addr;
    assign csr_data = pass_in_r.ex_mem_out;
    assign csr_we = ~wb_flush & pass_in_r.is_wr_csr;

endmodule