`include "cpu_defs.svh"

module Fetch2 (
    input logic clk, rst_n,

    /* from cache */
    input logic icache_ready,
    input u32_t icache_data,
    input logic icache_data_valid,

    /* pipeline */
    input logic flush, next_rdy_in,
    output logic rdy_in,

    input fetch1_fetch2_pass_t pass_in,
    input excp_pass_t excp_pass_in,
    output fetch2_decode_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    fetch1_fetch2_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pass_in_r.valid <= 1'b0;
        end else if(rdy_in) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    logic rdy_out;
    logic if2_flush, if2_stall;
    assign if2_flush = flush | ~pass_in_r.valid;
    assign if2_stall = ~next_rdy_in | ~icache_data_valid;

    assign rdy_in = if2_flush | ~if2_stall;
    assign rdy_out = ~if2_flush & ~if2_stall;        // only use this for pass_out.valid

    /* out to next stage */
    assign pass_out.valid = rdy_out;
    assign pass_out.inst = icache_data;

    `PASS(pc);
    `PASS(btb_pre);

    assign excp_pass_out = excp_pass_in_r;

endmodule