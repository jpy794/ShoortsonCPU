`include "cpu_defs.svh"
/* btb should only predict control transfer inst */
module BTB(
    input logic clk, rst_n,

    /* fetch1 */
    input logic is_stall,
    input u32_t pc,
    output u32_t target_pc,
    output target_valid,

    /* TODO from decode(bht) */

    /* from if2 */
    input btb_invalid_t btb_invalid_in,

    /* from ex */
    input br_resolved_t ex_resolved_in
);

btb_idx_t rd_idx;
btb_entry_t rd_entry;
virt_t pc_hold;
logic valid_hold;
assign rd_idx = pc[INST_ALIGN_WID+:BTB_IDX_WID];
assign target_pc = {rd_entry.target, {INST_ALIGN_WID{1'b0}}};
assign target_valid = (rd_entry.tag == pc_hold[INST_ALIGN_WID+BTB_IDX_WID+:BTB_TAG_WID]) & valid_hold;

logic wea;
btb_idx_t wr_idx;
btb_entry_t wr_entry;
assign wea = ex_resolved_in.valid;
assign wr_idx = ex_resolved_in.pc[INST_ALIGN_WID+:BTB_IDX_WID];
assign wr_entry.tag = ex_resolved_in.pc[INST_ALIGN_WID+BTB_IDX_WID+:BTB_TAG_WID];
assign wr_entry.target = ex_resolved_in.target_pc[INST_ALIGN_WID+:BTB_TARGET_WID];


DualPortBram #(
    .WID($bits(btb_entry_t)),
    .SIZE(BTB_SIZE)
) U_Bram (
    .clk,
    .ena(1'b1),
    .enb(~is_stall),
    .wea,
    .addra(wr_idx),
    .dina(wr_entry),
    .addrb(rd_idx),
    .doutb(rd_entry)
);

always_ff @(posedge clk) begin
    pc_hold <= pc;
    valid_hold <= valid[rd_idx];
end

/* impl valid separately with lut so that we can reset btb in one clk */
logic [BTB_IDX_WID-1:0] invalid_idx;
assign invalid_idx = btb_invalid_in.pc[INST_ALIGN_WID+:BTB_IDX_WID];

logic [BTB_SIZE-1:0] valid;

always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        valid <= '0;
    end else if (btb_invalid_in.valid) begin
        valid[invalid_idx] <= 0;
    end
    else begin
        valid[wr_idx] <= ex_resolved_in.valid;
    end
end

endmodule