`include "cpu_defs.svh"

module AddrTrans (
    input virt_t va,
    input tlb_lookup_type_t lookup_type,
    input byte_type_t byte_type,
    output mat_t mat,
    output phy_t pa,
    output excp_pass_t excp,

    input csr_t rd_csr,
    input tlb_entry_t tlb_entrys[TLB_ENTRY_NUM]
);

    /* tlb_lookup */
    /* TODO: mux dmw mat/pa and tlb mat/pa */
    mat_t tlb_mat;
    esubcode_ecode_t tlb_ecode;
    logic tlb_is_exc;
    phy_t tlb_pa;
    TLBLookup U_TLBLookup (
        .entrys(tlb_entrys),

        .asid(rd_csr.asid.asid),
        .plv(rd_csr.crmd.plv),

        .va,
        .lookup_type,

        .pa(tlb_pa),
        .mat(tlb_mat),
        .ecode(tlb_ecode),
        .is_exc(tlb_is_exc)
    );

    /* addr translate */
    logic is_direct;
    assign is_direct = rd_csr.crmd.da; // maybe consider crmd.pg ?

    logic is_dmw_found;
    assign is_dmw_found = 1'b0; // TODO: dmw

    logic is_tlb;
    assign is_tlb = ~is_direct & ~is_dmw_found;

    // TODO: dmw
    always_comb begin
        mat = tlb_mat;
        pa = tlb_pa;
        if(is_direct) begin
            if(lookup_type == LOOKUP_FETCH) begin
                mat = rd_csr.crmd.datf;
            end else begin
                mat = rd_csr.crmd.datm;
            end
            pa = va;
        end else if(is_dmw_found) begin
            /* dmw */

        end else begin
            /* tlb */
            mat = tlb_mat;
            pa = tlb_pa;
        end
    end

    /* align check */
    logic align_ok;
    always_comb begin
        align_ok = 1'b0;
        unique case(byte_type)
            BYTE:       align_ok = 1'b1;
            HALF_WORD:  align_ok = ~va[0];
            WORD:       align_ok = ~va[1] & ~va[0];
            default: //$stop;
                align_ok = 1'b0;
        endcase
    end

    /* exception*/
    assign excp.badv = va;
    always_comb begin
        excp.valid = 1'b0;
        excp.esubcode_ecode = tlb_ecode;
        if(~align_ok) begin
            /* unaligned */
            excp.valid = 1'b1;
            excp.esubcode_ecode = ALE;
        end else if(tlb_is_exc & is_tlb) begin
            /* tlb exception */
            excp.valid = 1'b1;
        end
    end

endmodule