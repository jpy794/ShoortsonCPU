`include "cpu_defs.svh"
module Exception(
    input logic ti_in,
    input logic [7:0] hwi_in,

    /* from mem1 */
    excp_req_t req,

    /* to if1 */
    output wr_pc_req_t wr_pc_req,

    /* ctrl */
    output logic excp_flush,

    /* csr */
    input csr_t rd_csr,
    output excp_wr_csr_req_t wr_csr_req

`ifdef DIFF_TEST
    ,output excp_event_t excp_event_out
`endif
);

    logic is_excp;
    assign is_excp = req.valid & req.excp_pass.valid;

    logic is_ertn;
    assign is_ertn = req.valid & req.inst_ertn;

    /* to ctrl */
    assign excp_flush = is_excp | is_int | is_ertn;

    virt_t ertn_pc, excp_entry_pc;
    assign ertn_pc = rd_csr.era;
    assign excp_entry_pc = (req.excp_pass.esubcode_ecode == TLBR) ? rd_csr.tlbrentry : rd_csr.eentry;
    assign wr_pc_req.valid = excp_flush;
    assign wr_pc_req.pc = ~req.inst_ertn ? excp_entry_pc : ertn_pc;

    logic [12:0] int_vec;
    assign int_vec = {1'b0, ti_in, 1'b0, hwi_in, rd_csr.estat.is.swi};  // no ipi int
    logic is_int;
    assign is_int = rd_csr.crmd.ie & (|(int_vec & rd_csr.ecfg.lie));

    always_comb begin
        wr_csr_req.we = 1'b0;
        wr_csr_req.crmd = rd_csr.crmd;
        wr_csr_req.prmd = rd_csr.prmd;
        wr_csr_req.estat = rd_csr.estat;
        wr_csr_req.era = rd_csr.era;
        wr_csr_req.badv = rd_csr.badv;
        if(is_int) begin
            wr_csr_req.we = 1'b1;

            wr_csr_req.crmd.plv = 2'b0;
            wr_csr_req.crmd.ie = 1'b0;

            wr_csr_req.prmd.pplv = rd_csr.crmd.plv;
            wr_csr_req.prmd.pie = rd_csr.crmd.ie;
            
            wr_csr_req.era = req.epc;

            wr_csr_req.estat.is = int_vec;
            wr_csr_req.estat.r_esubcode_ecode = INT;
        end else if(is_excp) begin
            wr_csr_req.we = 1'b1;

            wr_csr_req.crmd.plv = 2'b0;
            wr_csr_req.crmd.ie = 1'b0;

            wr_csr_req.prmd.pplv = rd_csr.crmd.plv;
            wr_csr_req.prmd.pie = rd_csr.crmd.ie;
            
            wr_csr_req.era = req.epc;

            wr_csr_req.estat.r_esubcode_ecode = req.excp_pass.esubcode_ecode;
        end else if(is_ertn) begin
            wr_csr_req.we = 1'b1;

            wr_csr_req.crmd.plv = rd_csr.prmd.pplv;
            wr_csr_req.crmd.ie = rd_csr.prmd.pie;
        end
    end

`ifdef DIFF_TEST
    assign excp_event_out.valid = wr_csr_req.we;
    assign excp_event_out.ecode = wr_csr_req.estat.r_esubcode_ecode[5:0];
    assign excp_event_out.is_eret = is_ertn;
    assign excp_event_out.int_no = int_vec[12:2];
`endif

endmodule