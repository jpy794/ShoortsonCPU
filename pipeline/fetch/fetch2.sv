`include "cpu_defs.svh"

module Fetch2 (
    input logic clk, rst_n,

    /* from cache */
    input logic icache_ready,
    input u32_t icache_data,
    input logic icache_data_valid,

    /* pipeline */
    input logic flush_i, stall_i,
    output logic stall_o,

    /* ctrl */
    output logic bp_update_flush,

    /* branch prediction invalid */
    output wr_pc_req_t wr_pc_req,
    output btb_invalid_t btb_invalid,

    input fetch1_fetch2_pass_t pass_in,
    input excp_pass_t excp_pass_in,
    output fetch2_decode_pass_t pass_out,
    output excp_pass_t excp_pass_out
);

    /* pipeline start */
    fetch1_fetch2_pass_t pass_in_r;
    excp_pass_t excp_pass_in_r;

    logic icache_data_stall;
    assign icache_data_stall = eu_do & pass_in_r.icache_req & ~icache_data_valid;
    assign stall_o = stall_i | icache_data_stall;

    logic valid_o;
    assign valid_o = pass_in_r.valid & ~stall_o;        // if ~valid_i, do not set exception valid

    /* for this stage */
    logic eu_do;
    assign eu_do = pass_in_r.valid & ~excp_pass_out.valid;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n | flush_i) begin
            pass_in_r.valid <= 1'b0;
            excp_pass_in_r.valid <= 1'b0;
            pass_in_r.icache_req <= 1'b0;       // do not wait for the req if flush
        end else if(~stall_o) begin
            pass_in_r <= pass_in;
            excp_pass_in_r <= excp_pass_in;
        end
    end

    /* out */
    `PASS(pc);
    assign pass_out.valid = valid_o;
    assign pass_out.inst = icache_data;
    
    /* exeption */
    always_comb begin
        excp_pass_out = excp_pass_in_r;
        excp_pass_out.valid = excp_pass_out.valid & valid_o;
    end
    /* pipeline end */

    /* icache */
    assign icache_data_ready = ~stall_i;

    /* check branch prediction error */
    /* reprediction of return instruction */
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

    logic is_call;
    logic is_return;
    assign is_call = inst_bl;
    assign is_return = (inst == {6'b010011, 16'b0, 5'b00001, 5'b0});

    logic bp_error;
    assign bp_error = working & ~is_br && pass_in_r.next.is_predict && (pass_in_r.next.pc != pass_in_r.pc + 4);
    assign btb_invalid.valid = bp_error;
    assign btb_invalid.pc = pass_in_r.pc;

    virt_t ra;
    logic ra_valid;
    logic pop;
    assign pop = working & is_return & ra_valid;
    RAS U_RAS (
        .ra(ra),
        .ra_valid(ra_valid),
        .pop(pop),
        .npc(pass_in_r.pc + 4),
        .push(is_call),
        .clk(clk),
        .rst_n(rst_n)
    );

    logic bp_repredict;
    assign bp_repredict = working & is_return & ra_valid;

    logic bp_advance;
    virt_t jump_to;
    assign bp_advance = working & (inst_b | inst_bl);
    assign jump_to = pass_in_r.pc + {{4 {inst[9]}}, inst[9:0], inst[25:10], 2'b0};
    
    assign bp_update_flush = bp_error | bp_repredict | bp_advance;

    always_comb begin
        if (bp_error) begin
            wr_pc_req.valid = 1;
            wr_pc_req.pc = pass_in_r.pc + 4;
            wr_pc_req.is_predict = 0;
            pass_out.next.pc = pass_in_r.pc + 4;
            pass_out.next.is_predict = 0;
        end
        else if (bp_advance) begin
            wr_pc_req.valid = 1;
            wr_pc_req.pc = jump_to;
            wr_pc_req.is_predict = 0;
            pass_out.next.pc = jump_to;
            pass_out.next.is_predict = 0;
        end
        else if (bp_repredict) begin
            wr_pc_req.valid = 1;
            wr_pc_req.pc = ra;
            wr_pc_req.is_predict = 1;
            pass_out.next.pc = ra;
            pass_out.next.is_predict = 1;
        end
        else begin
            wr_pc_req.valid = 0;
            wr_pc_req.pc = 0;
            wr_pc_req.is_predict = 0;
            pass_out.next = pass_in_r.next;
        end
    end

endmodule