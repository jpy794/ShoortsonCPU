`include "cpu_defs.svh"

module TLB (
    input logic clk,

    /* from csr */
    input csr_t rd_csr,

    /* to csr */
    output tlb_wr_csr_req_t wr_csr_req,

    /* tlb instruction */
    input tlb_op_req_t tlb_req,

    /* lookup */
    output tlb_entry_t itlb_lookup[TLB_ENTRY_NUM],
    output tlb_entry_t dtlb_lookup[TLB_ENTRY_NUM]
`ifdef DIFF_TEST
    ,output tlb_idx_t tlb_wr_idx
`endif
);

`ifdef DIFF_TEST
    assign tlb_wr_idx = wr_idx;
`endif

    tlb_idx_t rand_idx;
    Counter #(.WID(TLB_IDX_WID)) U_Counter(
        .clk,
        .clr(0),
        .cnt(rand_idx)
    );

    tlb_entry_t entrys[TLB_ENTRY_NUM];

    assign itlb_lookup = entrys;
    assign dtlb_lookup = entrys;

    logic tlbsrch_found;
    assign tlbsrch_found = tlb_req.found;
    tlb_idx_t tlbsrch_idx;
    assign tlbsrch_idx = tlb_req.found_idx;

    tlb_idx_t idx;
    assign idx = rd_csr.tlbidx.index;

    integer j;
    tlb_idx_t wr_idx;
    always_ff @(posedge clk) begin
        unique case(tlb_req.tlb_op)
        TLBNOP: ;
        TLBWR, TLBFILL: begin
            if(rd_csr.estat.r_esubcode_ecode != TLBR) entrys[wr_idx].e <= ~rd_csr.tlbidx.ne;
            else                                      entrys[wr_idx].e <= '1;

            entrys[wr_idx].g <= rd_csr.tlbelo[0].g & rd_csr.tlbelo[1].g;
            entrys[wr_idx].vppn <= rd_csr.tlbehi.vppn;
            entrys[wr_idx].ps <= rd_csr.tlbidx.ps;
            entrys[wr_idx].asid <= rd_csr.asid.asid;

            for(j=0; j<2; j=j+1) begin
                entrys[wr_idx].phy[j].ppn <= rd_csr.tlbelo[j].ppn;
                entrys[wr_idx].phy[j].plv <= rd_csr.tlbelo[j].plv;
                entrys[wr_idx].phy[j].mat <= rd_csr.tlbelo[j].mat;
                entrys[wr_idx].phy[j].d <= rd_csr.tlbelo[j].d;
                entrys[wr_idx].phy[j].v <= rd_csr.tlbelo[j].v;
            end
        end
        INVTLB: begin
            unique case(tlb_req.invtlb_op)
            5'h0: begin
                for(j=0; j<TLB_ENTRY_NUM; j++) begin
                    entrys[j].e <= '0;
                end
            end
            5'h1: begin
                for(j=0; j<TLB_ENTRY_NUM; j++) begin
                    entrys[j].e <= '0;
                end
            end
            5'h2: begin
                for(j=0; j<TLB_ENTRY_NUM; j++) begin
                    if(entrys[j].g) entrys[j].e <= '0;
                end
            end
            5'h3: begin
                for(j=0; j<TLB_ENTRY_NUM; j++) begin
                    if(~entrys[j].g) entrys[j].e <= '0;
                end
            end
            5'h4: begin
                for(j=0; j<TLB_ENTRY_NUM; j++) begin
                    if(~entrys[j].g && tlb_req.invtlb_asid == entrys[j].asid) entrys[j].e <= '0;
                end
            end
            5'h5: begin
                for(j=0; j<TLB_ENTRY_NUM; j++) begin
                    if(~entrys[j].g && tlb_req.invtlb_asid == entrys[j].asid && tlb_req.invtlb_vppn == entrys[j].vppn) entrys[j].e <= '0;
                end
            end
            5'h6: begin
                for(j=0; j<TLB_ENTRY_NUM; j++) begin
                    if((entrys[j].g || tlb_req.invtlb_asid == entrys[j].asid) && tlb_req.invtlb_vppn == entrys[j].vppn) entrys[j].e <= '0;
                end
            end
            default: ;
            endcase
        end
        default: ;
        endcase
    end

    always_comb begin
        wr_csr_req.we = '0;
        wr_csr_req.asid = rd_csr.asid;
        wr_csr_req.tlbehi = rd_csr.tlbehi;
        wr_csr_req.tlbelo[0] = rd_csr.tlbelo[0];
        wr_csr_req.tlbelo[1] = rd_csr.tlbelo[1];
        wr_csr_req.tlbidx = rd_csr.tlbidx;

        wr_idx = idx;

        unique case(tlb_req.tlb_op)
        TLBNOP: ;
        TLBSRCH: begin
            wr_csr_req.we = '1;
            wr_csr_req.tlbidx.ne = ~tlbsrch_found;
            if(tlbsrch_found)
                wr_csr_req.tlbidx.index = tlbsrch_idx;
        end
        TLBRD: begin
            wr_csr_req.we = '1;
            if(entrys[idx].e) begin
                wr_csr_req.tlbidx.ne = 1'b0;
                wr_csr_req.tlbidx.ps = entrys[idx].ps;
                wr_csr_req.tlbehi.vppn = entrys[idx].vppn;
                wr_csr_req.asid.asid = entrys[idx].asid;
                for(j=0; j<2; j=j+1) begin
                    wr_csr_req.tlbelo[j].ppn = entrys[idx].phy[j].ppn;
                    wr_csr_req.tlbelo[j].plv = entrys[idx].phy[j].plv;
                    wr_csr_req.tlbelo[j].mat = entrys[idx].phy[j].mat;
                    wr_csr_req.tlbelo[j].d = entrys[idx].phy[j].d;
                    wr_csr_req.tlbelo[j].v = entrys[idx].phy[j].v;
                    wr_csr_req.tlbelo[j].g = entrys[idx].g;
                end
            end else begin
                wr_csr_req.tlbidx.ne = '1;
                wr_csr_req.asid.asid = '0;
                wr_csr_req.tlbehi = '0;
                wr_csr_req.tlbelo[0] = '0;
                wr_csr_req.tlbelo[1] = '0;
                wr_csr_req.tlbidx.ps = '0;
            end
        end
        TLBWR: begin
        end
        TLBFILL: begin
            wr_idx = rand_idx;
        end
        INVTLB: begin
        end
        default: ;
        endcase
    end

endmodule