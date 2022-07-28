`include "cpu_defs.svh"

module Fetch2 (
    input logic clk, rst_n,

    /* from cache */
    input logic icache_ready,
    input u32_t icache_data,

    /* ctrl */
    output logic icache_stall,

    /* pipeline */
    input logic is_stall,
    input logic is_flush,

    input fetch1_fetch2_pass_t pass_in,
    input excp_pass_t excp_pass_in,
    output fetch2_decode_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    fetch1_fetch2_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pass_in_r.is_flush <= 1'b1;
        end else if(~is_stall) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    logic if2_flush;
    assign if2_flush = is_flush | pass_in_r.is_flush;

    /* out for ctrl */
    assign icache_stall = ~icache_ready & ~if2_flush;

    /* out to next stage */
    assign pass_out.is_flush = if2_flush | icache_stall;
    assign pass_out.inst = icache_data;

    `PASS(pc);
    `PASS(btb_pre);

    assign excp_pass_out = excp_pass_in_r;

endmodule