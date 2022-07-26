`include "cpu_defs.svh"

module TLB (
    input logic clk,

    /* from csr */
    input csr_t rd_csr,

    /* to csr */
    output tlb_wr_csr_req_t wr_csr_req,

    /* tlb instruction */
    input tlb_op_t tlb_op,
    input logic [4:0] invtlb_op,
    input vppn_t invtlb_vppn,
    input asid_t invtlb_asid,

    /* lookup */
    output tlb_entry_t itlb_lookup[TLB_ENTRY_NUM],
    output tlb_entry_t dtlb_lookup[TLB_ENTRY_NUM]
);

    tlb_idx_t rand_idx;
    Counter #(.WID(TLB_IDX_WID)) U_Counter(
        .clk,
        .clr(0),
        .cnt(rand_idx)
    );

    tlb_entry_t entrys[TLB_ENTRY_NUM];

    logic tlbsrch_found;
    tlb_idx_t tlbsrch_idx;

    tlb_idx_t idx;
    assign idx = rd_csr.tlbidx.index;

    integer j;
    tlb_idx_t wr_idx;
    logic we_entrys;
    always_ff @(posedge clk) begin
        unique case(tlb_op)
        TLBWR, TLBFILL: begin
            if(rd_csr.estat.r_esubcode_ecode == TLBR) entrys[wr_idx].e <= ~rd_csr.tlbidx.ne;
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
            case(invtlb_op)
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
                    if(~entrys[j].g && invtlb_asid == entrys[j].asid) entrys[j].e <= '0;
                end
            end
            5'h5: begin
                for(j=0; j<TLB_ENTRY_NUM; j++) begin
                    if(~entrys[j].g && invtlb_asid == entrys[j].asid && invtlb_vppn == entrys[j].vppn) entrys[j].e <= '0;
                end
            end
            5'h6: begin
                for(j=0; j<TLB_ENTRY_NUM; j++) begin
                    if((entrys[j].g || invtlb_asid == entrys[j].asid) && invtlb_vppn == entrys[j].vppn) entrys[j].e <= '0;
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
        wr_csr_req.tlbehi = rd_csr.tlbehi;
        wr_csr_req.tlbelo[0] = rd_csr.tlbelo[0];
        wr_csr_req.tlbelo[1] = rd_csr.tlbelo[1];
        wr_csr_req.tlbidx = rd_csr.tlbidx;

        we_entrys = '0;
        wr_idx = idx;

        unique case(tlb_op)
        TLBSRCH: begin
            wr_csr_req.we = '1;
            wr_csr_req.tlbidx.ne = ~tlbsrch_found;
            if(tlbsrch_found)
                wr_csr_req.tlbidx.index = tlbsrch_idx;
        end
        TLBRD: begin
            wr_csr_req.we = '1;
            if(entrys[idx].e) begin
                wr_csr_req.tlbidx.ps = entrys[idx].ps;
                wr_csr_req.tlbehi.vppn = entrys[idx].vppn;
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
            we_entrys = '1;
        end
        TLBFILL: begin
            we_entrys = '1;
            wr_idx = rand_idx;
        end
        INVTLB: begin
        end
        default: ;
        endcase
    end

    /* for tlbsrch */
    integer i;
    always_comb begin
        tlbsrch_found = '0;
        tlbsrch_idx = '0;
        for(i=0; i<$size(entrys); i=i+1) begin
            if(entrys[i].g || entrys[i].asid == rd_csr.asid.asid) begin
                if(entrys[i].vppn == rd_csr.tlbehi.vppn) begin
                    tlbsrch_found = '1;
                    tlbsrch_idx = i[TLB_IDX_WID-1:0];
                end
            end
        end
    end

endmodule