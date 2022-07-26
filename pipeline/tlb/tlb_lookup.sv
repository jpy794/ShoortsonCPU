`include "cpu_defs.svh"

module TLBLookup(
    /* from tlb */
    input tlb_entry_t entrys[TLB_ENTRY_NUM],
    /* from csr */
    input asid_t asid,
    input plv_t plv,
    /* lookup req */
    input virt_t va,
    input tlb_lookup_type_t lookup_type,
    /* result */
    output phy_t pa,
    output mat_t mat,
    output esubcode_ecode_t ecode,
    output logic is_exc
);

logic tlb_found;
tlb_entry_phy_t phy;

/* lookup */
integer i;
always_comb begin
    tlb_found = '0;
    phy = '0;
    pa = '0;
    mat = '0;
    for(i=0; i<$size(entrys); i=i+1) begin
        if(entrys[i].e && (entrys[i].g || entrys[i].asid == asid)) begin
            if(entrys[i].ps[0]) begin
                /* 4MB */
                if({entrys[i].vppn, 13'b0}[VALEN-1:PS_4MB+1] == va[VALEN-1:PS_4MB+1]) begin
                    tlb_found = '1;
                    phy = entrys[i].phy[va[PS_4MB]];
                    pa = {{entrys[i].phy[va[PS_4MB]].ppn, 12'b0}[VALEN-1:PS_4MB+1], va[PS_4MB:0]};
                    mat = entrys[i].phy[va[PS_4MB]].mat;
                end
            end else begin
                /* 4KB */
                if({entrys[i].vppn, 13'b0}[VALEN-1:PS_4KB+1] == va[VALEN-1:PS_4KB+1]) begin
                    tlb_found = '1;
                    phy = entrys[i].phy[va[PS_4KB]];
                    pa = {{entrys[i].phy[va[PS_4KB]].ppn, 12'b0}[VALEN-1:PS_4KB+1], va[PS_4KB:0]};
                    mat = entrys[i].phy[va[PS_4KB]].mat;
                end
            end
        end
    end
end

/* exception */
always_comb begin
    is_exc = '1;
    ecode = '0;
    if(~tlb_found) begin
        ecode = TLBR;
    end else begin
        if(~phy.v) begin
            ecode = {5'b0, lookup_type};
        end else if (plv > phy.plv) begin
            ecode = PPI;
        end else if (lookup_type == LOOKUP_STORE && ~phy.d) begin
            ecode = PME;
        end else begin
            is_exc = '0;
        end
    end
end

endmodule