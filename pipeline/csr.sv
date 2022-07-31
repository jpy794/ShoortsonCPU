`include "cpu_defs.svh"

module RegCSR (
    input logic clk, rst_n,

    /* rw inst */
    input csr_addr_t addr,
    output u32_t rd_data,
    input logic we,
    input u32_t wr_data,

    /* if */
    output csr_t if_rd,

    /* id */
    output csr_t id_rd,

    /* mem1 */
    output csr_t mem1_rd,

    /* tlb */
    output csr_t tlb_rd,
    input tlb_wr_csr_req_t tlb_wr_req,

    /* excp */
    output csr_t excp_rd,
    input excp_wr_csr_req_t excp_wr_req

`ifdef DIFF_TEST
    ,output csr_t wb_rd
`endif
);

    /* verilator lint_off UNOPTFLAT  */
    /* verilator lint_off BLKANDNBLK */
    csr_t csr;
    /* verilator lint_on UNOPTFLAT */
    /* verilator lint_on BLKANDNBLK */

    /* read */
    assign if_rd = csr;
    assign id_rd = csr;
    assign mem1_rd = csr;
    assign tlb_rd = csr;
    assign excp_rd = csr;
`ifdef DIFF_TEST
    assign wb_rd = csr;
`endif
    always_comb begin
        case(addr)
            'h0: rd_data = csr.crmd;
            'h1: rd_data = csr.prmd;
            'h2: rd_data = csr.euen;
            'h4: rd_data = csr.ecfg;
            'h5: rd_data = csr.estat;
            'h6: rd_data = csr.era;
            'h7: rd_data = csr.badv;
            'hc: rd_data = csr.eentry;
            'h10: rd_data = csr.tlbidx;
            'h11: rd_data = csr.tlbehi;
            'h12: rd_data = csr.tlbelo[0];
            'h13: rd_data = csr.tlbelo[1];
            'h18: rd_data = csr.asid;
            'h19: rd_data = csr.pgdl;
            'h1a: rd_data = csr.pgdh;
            'h1b: rd_data = csr.pgd;
            'h20: rd_data = csr.cpuid;
            'h30: rd_data = csr.save[0];
            'h31: rd_data = csr.save[1];
            'h32: rd_data = csr.save[2];
            'h33: rd_data = csr.save[3];
            /* TODO
            'h40: rd_data = csr.tid;
            'h41: rd_data = csr.tcfg;
            'h42: rd_data = csr.tval;
            'h44: rd_data = csr.ticlr;
            'h60: rd_data = csr.llbctl;
            */
            'h88: rd_data = csr.tlbrentry;
            /* TODO
            'h98: rd_data = csr.ctag;
            */
            'h180: rd_data = csr.dmw[0];
            'h181: rd_data = csr.dmw[1];
            default: rd_data = '0;
        endcase
    end

    /* write */

    /* write csr at wb stage */
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            csr.crmd.plv <= plv_t'(2'b0);
            csr.crmd.ie <= 1'b0;
            csr.crmd.da <= 1'b1;
            csr.crmd.pg <= 1'b0;
            csr.crmd.datf <= dat_t'(SUC);
            csr.crmd.datm <= dat_t'(SUC);

            csr.euen.fpe <= 1'b0;

            {csr.ecfg[12:11], csr.ecfg[9:0]} <= 12'b0;      // lie

            csr.estat.is.swi <= 2'b0;

            /* TODO
            csr.tcfg.en = 1'b0;
            csr.llbcrl.klo = '0;
            */
            csr.dmw[0].plv0 <= 1'b0;
            csr.dmw[0].plv3 <= 1'b0;
            csr.dmw[1].plv0 <= 1'b0;
            csr.dmw[1].plv3 <= 1'b0;
        end else begin
            if(excp_wr_req.we) begin
                /* wr from exception */
                csr.crmd.plv <= excp_wr_req.crmd.plv;
                csr.crmd.ie <= excp_wr_req.crmd.ie;
                
                csr.prmd.pplv <= excp_wr_req.prmd.pplv;
                csr.prmd.pie <= excp_wr_req.prmd.pie;

                csr.estat.r_esubcode_ecode <= excp_wr_req.estat.r_esubcode_ecode;
                csr.estat.is.r_ipi <= excp_wr_req.estat.is.r_ipi;
                csr.estat.is.r_ti <= excp_wr_req.estat.is.r_ti;
                csr.estat.is.r_hwi <= excp_wr_req.estat.is.r_hwi;
                csr.estat.is.swi <= excp_wr_req.estat.is.swi;

                csr.era <= excp_wr_req.era;

                csr.badv <= excp_wr_req.badv;
            end else if(tlb_wr_req.we) begin
                /* wr from tlb */
                {csr.tlbidx[31], csr.tlbidx[29:24], csr.tlbidx[TLB_IDX_WID-1:0]} <= {tlb_wr_req.tlbidx[31], tlb_wr_req.tlbidx[29:24], tlb_wr_req.tlbidx[TLB_IDX_WID-1:0]};
                csr.tlbehi[31:13] <= tlb_wr_req.tlbehi[31:13];
                {csr.tlbelo[0][PALEN-5:8] ,csr.tlbelo[0][6:0]} <= {tlb_wr_req.tlbelo[0][PALEN-5:8] ,tlb_wr_req.tlbelo[0][6:0]};
                {csr.tlbelo[1][PALEN-5:8] ,csr.tlbelo[1][6:0]} <= {tlb_wr_req.tlbelo[1][PALEN-5:8] ,tlb_wr_req.tlbelo[1][6:0]};
                csr.asid[9:0] <= tlb_wr_req.asid[9:0];
            end else if(we) begin
                /* wr from csr inst */
                case(addr)
                    'h0: csr.crmd[8:0] <= wr_data[8:0];
                    'h1: csr.prmd[2:0] <= wr_data[2:0];
                    'h2: csr.euen[0:0] <= wr_data[0:0];
                    'h4: {csr.ecfg[12:11], csr.ecfg[9:0]} <= {wr_data[12:11], wr_data[9:0]};
                    'h5: csr.estat[1:0] <= wr_data[1:0];
                    'h6: csr.era <= wr_data;
                    'h7: csr.badv <= wr_data;
                    'hc: csr.eentry[31:6] <= wr_data[31:6];
                    'h10: {csr.tlbidx[31], csr.tlbidx[29:24], csr.tlbidx[TLB_IDX_WID-1:0]} <= {wr_data[31], wr_data[29:24], wr_data[TLB_IDX_WID-1:0]};
                    'h11: csr.tlbehi[31:13] <= wr_data[31:13];
                    'h12: {csr.tlbelo[0][PALEN-5:8] ,csr.tlbelo[0][6:0]} <= {wr_data[PALEN-5:8] ,wr_data[6:0]};
                    'h13: {csr.tlbelo[1][PALEN-5:8] ,csr.tlbelo[1][6:0]} <= {wr_data[PALEN-5:8] ,wr_data[6:0]};
                    'h18: csr.asid[9:0] <= wr_data[9:0];
                    'h19: csr.pgdl[31:12] <= wr_data[31:12];
                    'h1a: csr.pgdh[31:12] <= wr_data[31:12];
                    'h20: ;
                    'h30: csr.save[0] <= wr_data;
                    'h31: csr.save[1] <= wr_data;
                    'h32: csr.save[2] <= wr_data;
                    'h33: csr.save[3] <= wr_data;
                    /* TODO
                    'h40: csr.tid <= wr_data;
                    'h41: csr.tcfg <= wr_data;
                    'h42: csr.tval <= wr_data;
                    'h44: csr.ticlr <= wr_data;
                    'h60: csr.llbctl <= wr_data;
                    */
                    'h88: csr.tlbrentry[31:6] <= wr_data[31:6];
                    /* TODO 
                    'h98: csr.ctag <= wr_data;
                    */
                    'h180: {csr.dmw[0][31:29], csr.dmw[0][27:25], csr.dmw[0][5:3], csr.dmw[0][0]} <= {wr_data[31:29], wr_data[27:25], wr_data[5:3], wr_data[0]};
                    'h181: {csr.dmw[1][31:29], csr.dmw[1][27:25], csr.dmw[1][5:3], csr.dmw[1][0]} <= {wr_data[31:29], wr_data[27:25], wr_data[5:3], wr_data[0]};
                endcase
            end
        end
    end

    /* r0 and r bits of csr */
    assign csr.crmd.r0_1 = '0;
    assign csr.prmd.r0_1 = '0;
    assign csr.euen.r0_1 = '0;
    /* ecfg */
    assign csr.ecfg.lie.r0_1 = '0;
    assign csr.ecfg.r0_1 = '0;
    /* ecfg end */
    /* estat */
    assign csr.estat.r0_1 = '0;
    assign csr.estat.r0_2 = '0;
    assign csr.estat.is.r0_1 = '0;
    /* estat end */
    assign csr.eentry.r0_1 = '0;
    /* cpu id */
    assign csr.cpuid.r0_1 = '0;
    assign csr.cpuid.r_coreid = '0;             // single core, always zero
    /* cpu id end */
    /* tlbidx */
    assign csr.tlbidx.r0_1 = '0;
    assign csr.tlbidx.r0_2 = '0;
    assign csr.tlbidx.r0_3 = '0;
    /* tlbidx end */
    assign csr.tlbehi.r0_1 = '0;
    assign csr.tlbelo[0].r0_1 = '0;
    assign csr.tlbelo[0].r0_2 = '0;
    assign csr.tlbelo[1].r0_1 = '0;
    assign csr.tlbelo[1].r0_2 = '0;
    /* asid */
    assign csr.asid.r0_1 = '0;
    assign csr.asid.r0_2 = '0;
    assign csr.asid.r_asidbits = ASID_WID;
    /* asid end */
    assign csr.pgdl.r0_1 = '0;
    assign csr.pgdh.r0_1 = '0;
    /* pgd */
    assign csr.pgd.r0_1 = '0;
    assign csr.pgd.base = csr.badv[31] ? csr.pgdh.base : csr.pgdl.base;
    /* pgd end */
    assign csr.tlbrentry.r0_1 = '0; 
    /* dmw */
    assign csr.dmw[0].r0_1 = '0;
    assign csr.dmw[0].r0_2 = '0;
    assign csr.dmw[0].r0_3 = '0;
    assign csr.dmw[1].r0_1 = '0;
    assign csr.dmw[1].r0_2 = '0;
    assign csr.dmw[1].r0_3 = '0;
    /* dmw end */


endmodule
