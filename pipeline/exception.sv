`include "cpu_defs.svh"
module Exception(
    input logic clk, rst_n,

    input logic ti_in, ti_clr,
    input logic [1:0] swi_in, swi_clr,
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

    logic [12:0] int_vec;
    logic [1:0] [12:0] int_vec_r;
    logic [12:0] clr;
    assign clr = {1'b0, ti_clr, 1'b0, 8'b0, swi_clr};
    assign int_vec = {1'b0, ti_in, 1'b0, hwi_in, swi_in};  // no ipi int
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n)  begin
            int_vec_r[1] <= 13'b0;                     // reset swi
            int_vec_r[0] <= 13'b0;
        end else begin
            int_vec_r[1] <= ~clr & (int_vec | int_vec_r[1]);
            int_vec_r[0] <= int_vec_r[1];
        end
    end
    assign is = int_vec_r[0];

    logic is_int;
    assign is_int = req.valid & rd_csr.crmd.ie & (|(int_vec_r[0] & rd_csr.ecfg.lie));      // in case it is a bubble

    esubcode_ecode_t ecode;
    assign ecode = req.excp_pass.esubcode_ecode;
    logic wr_badv;
    assign wr_badv = (ecode == TLBR) ||
                     (ecode == ADEF) ||
                     (ecode == ADEM) ||
                     (ecode == ALE) ||
                     (ecode == PIL) ||
                     (ecode == PIS) ||
                     (ecode == PIF) ;

    logic excp_tlbr;
    assign excp_tlbr = (ecode == TLBR);

    logic wr_tlbehi = (ecode == TLBR) ||
                      (ecode == PIS) ||
                      (ecode == PIF) ||
                      (ecode == PIL) ||
                      (ecode == PME) ||
                      (ecode == PPI) ;

    always_comb begin
        wr_csr_req.we = 1'b0;
        wr_csr_req.crmd = rd_csr.crmd;
        wr_csr_req.prmd = rd_csr.prmd;
        wr_csr_req.estat.r_esubcode_ecode = rd_csr.estat.r_esubcode_ecode;
        wr_csr_req.era = rd_csr.era;
        wr_csr_req.badv = rd_csr.badv;
        wr_csr_req.tlbehi = rd_csr.tlbehi;
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

            if(excp_tlbr) begin
                wr_csr_req.crmd.da = 1'b1;
                wr_csr_req.crmd.pg = 1'b0;
            end

            wr_csr_req.crmd.plv = KERNEL;
            wr_csr_req.crmd.ie = 1'b0;

            wr_csr_req.prmd.pplv = rd_csr.crmd.plv;
            wr_csr_req.prmd.pie = rd_csr.crmd.ie;
            
            wr_csr_req.era = req.epc;

            wr_csr_req.estat.r_esubcode_ecode = req.excp_pass.esubcode_ecode;

            if(wr_tlbehi)
                wr_csr_req.tlbehi.vppn = req.excp_pass.badv[31:13];

            if(wr_badv)
                wr_csr_req.badv = req.excp_pass.badv;
        end
    end

`ifdef DIFF_TEST
    assign excp_event_out.valid = wr_csr_req.we;
    assign excp_event_out.ecode = wr_csr_req.estat.r_esubcode_ecode[5:0];
    assign excp_event_out.int_no = int_vec_r[0][12:2];
`endif

endmodule