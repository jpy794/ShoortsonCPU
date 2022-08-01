`include "cpu_defs.svh"
module Exception(
    input logic clk,

    input logic ti_in, ti_clr,
    input logic [7:0] hwi_in,

    /* from mem1 */
    excp_req_t req,

    /* to if1 */
    output wr_pc_req_t wr_pc_req,

    /* ctrl */
    output logic excp_flush,

    /* csr */
    input csr_t rd_csr,
    output excp_wr_csr_req_t wr_csr_req,
    output logic [12:0] is

`ifdef DIFF_TEST
    ,output excp_event_t excp_event_out
`endif
);

    logic is_excp;
    assign is_excp = req.excp_pass.valid;       // if excp valid, can not be a bubble

    /* to ctrl */
    assign excp_flush = is_excp | is_int;

    virt_t excp_entry_pc;
    assign excp_entry_pc = (req.excp_pass.esubcode_ecode == TLBR) && (is_excp) ? rd_csr.tlbrentry : rd_csr.eentry;
    assign wr_pc_req.valid = excp_flush;
    assign wr_pc_req.pc = excp_entry_pc;

    logic [12:0] int_vec, int_vec_r;
    assign int_vec = {1'b0, ti_in, 1'b0, hwi_in, rd_csr.estat.is.swi};  // no ipi int
    always_ff @(posedge clk) begin
        if(ti_clr)  int_vec_r[11] <= 1'b0;
        else        int_vec_r <= int_vec | int_vec_r;
    end
    assign is = int_vec_r;

    logic is_int;
    assign is_int = req.valid & rd_csr.crmd.ie & (|(int_vec_r & rd_csr.ecfg.lie));      // in case it is a bubble

    always_comb begin
        wr_csr_req.we = 1'b0;
        wr_csr_req.crmd = rd_csr.crmd;
        wr_csr_req.prmd = rd_csr.prmd;
        wr_csr_req.estat = rd_csr.estat;
        wr_csr_req.era = rd_csr.era;
        wr_csr_req.badv = rd_csr.badv;
        if(is_int) begin
            wr_csr_req.we = 1'b1;

            wr_csr_req.crmd.plv = KERNEL;
            wr_csr_req.crmd.ie = 1'b0;

            wr_csr_req.prmd.pplv = rd_csr.crmd.plv;
            wr_csr_req.prmd.pie = rd_csr.crmd.ie;
            
            wr_csr_req.era = req.epc;

            wr_csr_req.estat.r_esubcode_ecode = INT;
        end else if(is_excp) begin
            wr_csr_req.we = 1'b1;

            wr_csr_req.crmd.plv = KERNEL;
            wr_csr_req.crmd.ie = 1'b0;

            wr_csr_req.prmd.pplv = rd_csr.crmd.plv;
            wr_csr_req.prmd.pie = rd_csr.crmd.ie;
            
            wr_csr_req.era = req.epc;

            wr_csr_req.estat.r_esubcode_ecode = req.excp_pass.esubcode_ecode;
        end
    end

`ifdef DIFF_TEST
    assign excp_event_out.valid = wr_csr_req.we;
    assign excp_event_out.ecode = wr_csr_req.estat.r_esubcode_ecode[5:0];
    assign excp_event_out.int_no = int_vec_r[12:2];
`endif

endmodule