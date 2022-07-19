`include "../cpu_defs.svh"
module Exception(
    input logic ti_in,
    input logic [7:0] hwi_in,

    /* wb stage */
    input logic inst_eret,
    output u32_t old_pc,

    input u32_t excp_pc,
    input excp_pass_t wb_excp,
    output u32_t excp_entry_pc,

    /* csr */
    input csr_t rd_csr,
    output excp_wr_csr_req_t wr_csr_req
);

assign old_pc = rd_csr.era;
assign excp_entry_pc = (wb_excp.esubcode_ecode == TLBR) ? rd_csr.tlbrentry : rd_csr.eentry;

logic [12:0] int_vec;
assign int_vec = {1'b0, ti_in, 1'b0, hwi_in, rd_csr.estat.is.swi};  // no ipi int
logic is_int;
assign is_int = rd_csr.crmd.ie & (|(int_vec & rd_csr.ecfg.lie));

logic is_excp = wb_excp.is_excp;

always_comb begin
    wr_csr_req.we = 1'b1;
    wr_csr_req.crmd = rd_csr.crmd;
    wr_csr_req.prmd = rd_csr.prmd;
    wr_csr_req.estat = rd_csr.estat;
    wr_csr_req.era = rd_csr.era;
    wr_csr_req.badv = rd_csr.badv;
    if(is_int) begin
        wr_csr_req.crmd.plv = 2'b0;
        wr_csr_req.crmd.ie = 1'b0;

        wr_csr_req.prmd.pplv = rd_csr.crmd.plv;
        wr_csr_req.prmd.pie = rd_csr.crmd.ie;
        
        wr_csr_req.era = excp_pc;

        wr_csr_req.estat.is = int_vec;
    end else if(is_excp) begin
        wr_csr_req.crmd.plv = 2'b0;
        wr_csr_req.crmd.ie = 1'b0;

        wr_csr_req.prmd.pplv = rd_csr.crmd.plv;
        wr_csr_req.prmd.pie = rd_csr.crmd.ie;
        
        wr_csr_req.era = excp_pc;

        wr_csr_req.estat.r_esubcode_ecode = wb_excp.esubcode_ecode;
    end else if(inst_eret) begin
        wr_csr_req.crmd.plv = rd_csr.prmd.pplv;
        wr_csr_req.crmd.ie = rd_csr.prmd.pie;
    end else begin
        wr_csr_req.we = 1'b0;
    end
end

endmodule