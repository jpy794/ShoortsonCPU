`include "cpu_defs.svh"
module Exception(
    input logic ti_in,
    input logic [7:0] hwi_in,

    /* wb stage */
    input logic wb_flush,
    input logic wb_ertn,
    input u32_t pc_wb,
    input excp_pass_t excp_wb,

    /* to if1 */
    output wr_pc_req_t wr_pc_req,

    /* csr */
    input csr_t rd_csr,
    output excp_wr_csr_req_t wr_csr_req
);

    virt_t eret_pc, excp_entry_pc;
    assign eret_pc = rd_csr.era;
    assign excp_entry_pc = (excp_wb.esubcode_ecode == TLBR) ? rd_csr.tlbrentry : rd_csr.eentry;
    assign wr_pc_req.valid = wb_ertn | excp_wb.valid;
    assign wr_pc_req.pc = excp_wb.valid ? excp_entry_pc : eret_pc;

    logic [12:0] int_vec;
    assign int_vec = {1'b0, ti_in, 1'b0, hwi_in, rd_csr.estat.is.swi};  // no ipi int
    logic is_int;
    assign is_int = rd_csr.crmd.ie & (|(int_vec & rd_csr.ecfg.lie));

    logic is_excp = excp_wb.valid;

    always_comb begin
        wr_csr_req.we = 1'b0;
        wr_csr_req.crmd = rd_csr.crmd;
        wr_csr_req.prmd = rd_csr.prmd;
        wr_csr_req.estat = rd_csr.estat;
        wr_csr_req.era = rd_csr.era;
        wr_csr_req.badv = rd_csr.badv;
        if(~wb_flush) begin
            if(is_int) begin
                wr_csr_req.we = 1'b1;

                wr_csr_req.crmd.plv = 2'b0;
                wr_csr_req.crmd.ie = 1'b0;

                wr_csr_req.prmd.pplv = rd_csr.crmd.plv;
                wr_csr_req.prmd.pie = rd_csr.crmd.ie;
                
                wr_csr_req.era = pc_wb;

                wr_csr_req.estat.is = int_vec;
            end else if(is_excp) begin
                wr_csr_req.we = 1'b1;

                wr_csr_req.crmd.plv = 2'b0;
                wr_csr_req.crmd.ie = 1'b0;

                wr_csr_req.prmd.pplv = rd_csr.crmd.plv;
                wr_csr_req.prmd.pie = rd_csr.crmd.ie;
                
                wr_csr_req.era = pc_wb;

                wr_csr_req.estat.r_esubcode_ecode = excp_wb.esubcode_ecode;
            end else if(wb_ertn) begin
                wr_csr_req.we = 1'b1;

                wr_csr_req.crmd.plv = rd_csr.prmd.pplv;
                wr_csr_req.crmd.ie = rd_csr.prmd.pie;
            end
        end
    end

endmodule