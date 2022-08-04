`include "cpu_defs.svh"

module StableCNT (
    input logic clk, rst_n,
    input csr_t rd_csr,
    input cnt_op_t op,
    output u32_t out
`ifdef DIFF_TEST
    ,output logic [63:0] out_64
`endif
);

    /* stable counter */
    logic [63:0] stable_cnt;
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) stable_cnt <= 64'b0;
        else       stable_cnt <= stable_cnt + 1;
    end

`ifdef DIFF_TEST
    assign out_64 = stable_cnt;
`endif

    always_comb begin
        out = 32'b0;
        unique case(op)
            CNTID: out = rd_csr.tid;
            CNTVH: out = stable_cnt[63:32];
            CNTVL: out = stable_cnt[31:0];
            default: ;
        endcase
    end

endmodule