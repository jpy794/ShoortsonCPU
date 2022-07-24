`include "../cpu_defs.svh"

// TODO: hazard detect

module Decode (
    input logic clk, rst_n,

    /* from regfile */
    output logic [4:0] rj, rk,      // TODO: store the data in rd, mux rk here,
    input u32_t rj_data, rk_data,   //       or we can rename rd in store to rk (lol)

    /* ctrl */
    output logic load_use_stall,

    /* pipeline */
    input logic is_stall,
    input logic is_flush,
    input fetch2_decode_pass_t pass_in,
    input excp_pass_t excp_pass_in,

    output decode_execute_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    fetch2_decode_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            pass_in_r.is_flush <= 1'b1;
        end else if(~is_stall) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    /* decode stage */



    /* out to next stage */
    assign pass_out.is_flush = is_flush | pass_in_r.is_flush;
    assign pass_out.pc = pass_in_r.pc;

    assign excp_pass_out = excp_pass_in_r;

endmodule