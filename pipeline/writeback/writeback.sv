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
    /* debug */
    output memory2_writeback_pass_t pass_out,
);

    memory2_writeback_pass_t pass_in_r;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pass_in_r.is_flush <= 1'b1;
        end else if(~is_stall) begin
            pass_in_r <= pass_in;
        end
    end

    /* writeback stage */

    // TODO
    assign pass_out = pass_in_r;
    
    assign reg_idx = pass_in_r.rd;
    assign reg_data = pass_in_r.is_wr_rd_pc_plus4 ? pass_in_r.pc_plus4 : pass_in_r.ex_mem_out;
    assign reg_we = ~wb_flush & pass_in_r.is_wr_rd;

    assign csr_addr = pass_in_r.csr_addr;
    assign csr_data = pass_in_r.ex_mem_out;
    assign csr_we = ~wb_flush & pass_in_r.is_wr_csr;
    
    /* difftest */
    DifftestInstrCommit DifftestInstrCommit(
        .clock              (clk            ),
        .coreid             (0              ),
        .index              (0              ),
        .valid              (reg_we | csr_we),
        .pc                 (pass_in_r.pc   ),
        .instr              (0              ),
        .skip               (0              ),
        .is_TLBFILL         (0 ),
        .TLBFILL_index      (0 ),
        .is_CNTinst         (0   ),
        .timer_64_value     (0   ),
        .wen                (reg_we        ),
        .wdest              (reg_idx      ),
        .wdata              (reg_data      ),
        .csr_rstat          (0),
        .csr_data           (0   )
    );

endmodule