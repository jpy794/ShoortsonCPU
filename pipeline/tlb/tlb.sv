`include "cpu_defs.svh"

module TLB (
    input logic clk,

    /* write */
    input logic [TLB_IDX_WID-1:0] wr_idx,
    input tlb_entry_t wr_entry,
    input logic we,

    /* lookup */
    output tlb_entry_t itlb_lookup[TLB_ENTRY_NUM],
    output tlb_entry_t dtlb_lookup[TLB_ENTRY_NUM]
);

tlb_entry_t entrys[TLB_ENTRY_NUM];

always_ff @(posedge clk) begin
    if(we) begin
        entrys[wr_idx] <= wr_entry;
    end
end

endmodule