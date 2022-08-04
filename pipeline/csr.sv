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

    /* ex */
    output csr_t ex_rd,

    /* mem1 */
    output csr_t mem1_rd,
    input logic is_ertn,

    /* tlb */
    output csr_t tlb_rd,
    input tlb_wr_csr_req_t tlb_wr_req,

    /* excp */
    output csr_t excp_rd,
    input excp_wr_csr_req_t excp_wr_req,
    input logic [12:0] is,

    /* swi */
    output logic [1:0] swi, swi_clr,

    /* ti */
    output logic ti, ti_clr

`ifdef DIFF_TEST
    ,output csr_t mem2_rd
`endif
);

    /* verilator lint_off UNOPTFLAT  */
    /* verilator lint_off BLKANDNBLK */
    csr_t csr;
    /* verilator lint_on UNOPTFLAT */
    /* verilator lint_on BLKANDNBLK */

    /* swi */
    logic swi_we;
    assign swi_we = we && (addr == 'h5);
    assign swi = swi_we ? wr_data[1:0] : 2'b0;
    assign swi_clr = swi_we ? ~wr_data[1:0] : 2'b0;

    /* tim and int */
    logic tim_cfg, tim_en;
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            tim_en <= 1'b0;
        end else if(tim_cfg) begin
            tim_en <= wr_data[0];
            csr.tcfg <= wr_data;
            csr.tval <= {wr_data[31:2], 2'b0};
        end else if(tim_en) begin
            if(csr.tval == 32'b0) begin
                tim_en <= csr.tcfg.periodic;
                csr.tval <= csr.tcfg.periodic ? {csr.tcfg.initval, 2'b0} : 32'hffff_ffff;
            end else begin
                csr.tval <= csr.tval - 1;
            end
        end
    end
    assign ti = (csr.tval == 32'b0) && tim_en;
    assign ti_clr = we && (addr == 'h44) && wr_data[0];
    assign tim_cfg = we && (addr == 'h41);

    /* read */
    assign if_rd = csr;
    assign id_rd = csr;
    assign ex_rd = csr;
    assign mem1_rd = csr;
    assign tlb_rd = csr;
    assign excp_rd = csr;
`ifdef DIFF_TEST
    assign mem2_rd = csr;
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
            
            'h40: rd_data = csr.tid;
            'h41: rd_data = csr.tcfg;
            'h42: rd_data = csr.tval;
            'h44: rd_data = csr.ticlr;
            /* TODO
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

            csr.ecfg.lie <= 13'b0;

            /* TODO
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
                csr.crmd.da <= excp_wr_req.crmd.da;
                csr.crmd.pg <= excp_wr_req.crmd.pg;
                
                csr.prmd.pplv <= excp_wr_req.prmd.pplv;
                csr.prmd.pie <= excp_wr_req.prmd.pie;

                csr.estat.r_esubcode_ecode <= excp_wr_req.estat.r_esubcode_ecode;

                csr.era <= excp_wr_req.era;

                csr.badv <= excp_wr_req.badv;
                csr.tlbehi.vppn <= excp_wr_req.tlbehi.vppn;
            end else begin
                unique case(1'b1)
                    tlb_wr_req.we: begin
                        /* wr from tlb */
                        {csr.tlbidx[31], csr.tlbidx[29:24], csr.tlbidx[TLB_IDX_WID-1:0]} <= {tlb_wr_req.tlbidx[31], tlb_wr_req.tlbidx[29:24], tlb_wr_req.tlbidx[TLB_IDX_WID-1:0]};
                        csr.tlbehi[31:13] <= tlb_wr_req.tlbehi[31:13];
                        {csr.tlbelo[0][PALEN-5:8] ,csr.tlbelo[0][6:0]} <= {tlb_wr_req.tlbelo[0][PALEN-5:8] ,tlb_wr_req.tlbelo[0][6:0]};
                        {csr.tlbelo[1][PALEN-5:8] ,csr.tlbelo[1][6:0]} <= {tlb_wr_req.tlbelo[1][PALEN-5:8] ,tlb_wr_req.tlbelo[1][6:0]};
                        csr.asid[9:0] <= tlb_wr_req.asid[9:0];
                    end
                    we: begin
                        /* wr from csr inst */
                        case(addr)
                            'h0: csr.crmd[8:0] <= wr_data[8:0];
                            'h1: csr.prmd[2:0] <= wr_data[2:0];
                            'h2: csr.euen[0:0] <= wr_data[0:0];
                            'h4: csr.ecfg.lie <= wr_data[12:0];
                            'h5: ;                                      // swi
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

                            'h40: csr.tid <= wr_data;
                            'h41: ;                         // use it seperately
                            'h42: ;                         // tval read only
                            'h44: ;                         // handle ticlr in exception
                            /* TODO
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
                    is_ertn: begin
                        /* TODO: llbit also need to be changed here*/
                        csr.crmd.plv <= csr.prmd.pplv;
                        csr.crmd.ie <= csr.prmd.pie;

                        if(csr.estat.r_esubcode_ecode == TLBR) begin
                            csr.crmd.da <= 1'b0;
                            csr.crmd.pg <= 1'b1;
                        end
                    end
                endcase
            end
        end
    end

    /* r0 and r bits of csr */
    assign csr.crmd.r0_1 = '0;
    assign csr.prmd.r0_1 = '0;
    assign csr.euen.r0_1 = '0;
    /* ecfg */
    assign csr.ecfg.r0_1 = '0;
    /* ecfg end */
    /* estat */
    assign csr.estat.r0_1 = '0;
    assign csr.estat.r0_2 = '0;
    assign csr.estat.is = is;
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
    /* tim */
    assign csr.ticlr = '0;      // w1


endmodule
