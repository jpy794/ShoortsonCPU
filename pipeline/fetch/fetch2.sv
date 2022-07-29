`include "cpu_defs.svh"

module Fetch2 (
    input logic clk, rst_n,

    /* from cache */
    input logic icache_ready,
    input u32_t icache_data,
    input logic icache_data_valid,

    /* pipeline */
    input logic flush, next_rdy_in,
    output logic rdy_in,

    /* ctrl */
    output logic bp_error_flush,

    /* branch prediction invalid */
    output wr_pc_req_t wr_pc_req,
    output btb_invalid_t btb_invalid,

    input fetch1_fetch2_pass_t pass_in,
    input excp_pass_t excp_pass_in,
    output fetch2_decode_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    fetch1_fetch2_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            pass_in_r.valid <= 1'b0;
        end else if(rdy_in) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    logic rdy_out;
    logic if2_flush, if2_stall;
    assign if2_flush = flush | ~pass_in_r.valid;
    assign if2_stall = ~next_rdy_in | ~icache_data_valid;

    assign rdy_in = if2_flush | ~if2_stall;
    assign rdy_out = ~if2_flush & ~if2_stall;        // only use this for pass_out.valid

    /* out to next stage */
    assign pass_out.valid = rdy_out;
    assign pass_out.inst = icache_data;

    /* check branch prediction error */
    // TODO: RAS
    u32_t inst;
    assign inst = icache_data;

    logic inst_jirl;
    logic inst_b;
    logic inst_bl;
    logic inst_beq;
    logic inst_bne;
    logic inst_blt;
    logic inst_bge;
    logic inst_bltu;
    logic inst_bgeu;

    always_comb begin
        inst_jirl = 1'b0;
        inst_b = 1'b0;
        inst_bl = 1'b0;
        inst_beq = 1'b0;
        inst_bne = 1'b0;
        inst_blt = 1'b0;
        inst_bge = 1'b0;
        inst_bltu = 1'b0;
        inst_bgeu = 1'b0;
        unique casez(inst)
            {6'b010011, {26{1'b?}}}: inst_jirl = 1'b1;
            {6'b010100, {26{1'b?}}}: inst_b = 1'b1;
            {6'b010101, {26{1'b?}}}: inst_bl = 1'b1;
            {6'b010110, {26{1'b?}}}: inst_beq = 1'b1;
            {6'b010111, {26{1'b?}}}: inst_bne = 1'b1;
            {6'b011000, {26{1'b?}}}: inst_blt = 1'b1;
            {6'b011001, {26{1'b?}}}: inst_bge = 1'b1;
            {6'b011010, {26{1'b?}}}: inst_bltu = 1'b1;
            {6'b011011, {26{1'b?}}}: inst_bgeu = 1'b1;
        endcase
    end

    logic is_br_off;
    assign is_br_off =  inst_b    |
                        inst_bl   |
                        inst_beq  |
                        inst_bne  |
                        inst_blt  |
                        inst_bge  |
                        inst_bltu |
                        inst_bgeu ;
    logic is_br_reg;
    assign is_br_reg = inst_jirl ;

    logic is_br;
    assign is_br = is_br_off | is_br_reg;

    assign bp_error_flush = ~is_br && pass_in_r.is_pred && (pass_in_r.btb_pre != pass_in_r.pc + 4);
    assign btb_invalid.valid = bp_error_flush;
    assign btb_invalid.pc = pass_in_r.pc;

    assign wr_pc_req.valid = bp_error_flush;
    assign wr_pc_req.pc = pass_in_r.pc + 4;

    `PASS(pc);
    `PASS(btb_pre);
    `PASS(is_pred);

    assign excp_pass_out = excp_pass_in_r;

endmodule