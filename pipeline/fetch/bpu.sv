`include "cpu_defs.svh"
module BPU(
    input logic clk, rst_n,

    /* fetch1 */
    input logic is_stall,
    input u32_t pc,
    output btb_predict_t predict_out,

    /* from if2 */
    input btb_invalid_t btb_invalid_in,

    /* from ex */
    input br_resolved_t ex_resolved_in
);

localparam  STRONGLY_NOTTAKEN = 2'b00,
            WEAKLY_NOTTAKEN = 2'b01,
            WEAKLY_TAKEN = 2'b10,
            STRONGLY_TAKEN = 2'b11;

// GHR
logic [BRHISTORY_LENGTH-1 : 0] br_history;
always_ff @(posedge clk) begin
    if (ex_resolved_in.valid)
        br_history <= (br_history << 1) + ex_resolved_in.taken;
end

// PHT
// 2-bit branch prediction
logic pht_wen;
logic [BTB_IDX_WID - 1 + BRHISTORY_LENGTH : 0] pht_wr_idx, pht_lookup_idx;
logic [1:0] pht_wr_data, pht_rd_data, pht_lookup_data;
assign pht_wen = ex_resolved_in.valid;
assign pht_wr_idx = {ex_resolved_in.pc[INST_ALIGN_WID +: BTB_IDX_WID], br_history};
assign pht_lookup_idx = {pc[INST_ALIGN_WID +: BTB_IDX_WID], br_history};

always_comb begin
    if (ex_resolved_in.taken && pht_rd_data != 2'b11) pht_wr_data = pht_rd_data + 1;
    else if (~ex_resolved_in.taken && pht_rd_data != 2'b00) pht_wr_data = pht_rd_data - 1;
    else pht_wr_data = pht_rd_data;
end

DualPortDmem #(
    .WID(2),
    .SIZE(BTB_SIZE * BRHISTORY_LENGTH),
    .INIT(WEAKLY_NOTTAKEN)
) U_PHT (
    .clk(clk),
    .wea(pht_wen),
    .addra(pht_wr_idx),
    .dina(pht_wr_data),
    .douta(pht_rd_data),
    .addrb(pht_lookup_idx),
    .doutb(pht_lookup_data)
);

// BTB
u32_t target_pc;
logic target_valid;
BTB U_BTB (
    .clk(clk),
    .rst_n(rst_n),
    .is_stall(is_stall),
    .pc(pc),
    .target_pc(target_pc),
    .target_valid(target_valid),
    .btb_invalid_in(btb_invalid_in),
    .ex_resolved_in(ex_resolved_in)
);

logic pht_lookup_data_hold;
always_ff @(posedge clk) begin
    pht_lookup_data_hold <= pht_lookup_data;
end

assign predict_out.valid = target_valid & (pht_lookup_data_hold >= 2);
assign predict_out.npc = target_pc;

endmodule