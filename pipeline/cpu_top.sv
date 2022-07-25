module CPUTop (
    input logic clk, rst_n
);
logic btb_is_stall;     //QUES: btb is_stall from fetch1?
u32_t btb_pc;               //QUES: 同上
btb_predict_t predict_out_from_btb;
btb_resolved_t ex_resolved_in;
wr_pc_req_tl ex_wr_pc_req;
fetch1_fetch2_pass_t pass_out_from_fetch1;
fetch2_decode_pass_t pass_out_from_fetch2;
decode_execute_pass_t pass_out_from_decode;
execute_mem1_pass_t pass_out_from_exec;
memory1_memory2_pass_t pass_out_from_mem1;
memory2_writeback_pass_t pass_out_from_mem2;
excp_pass_t excp_pass_out_from_fetch1;
excp_pass_t excp_pass_out_from_fetch2;
excp_pass_t excp_pass_out_from_decode;
excp_pass_t excp_pass_out_from_exception;
excp_pass_t excp_pass_out_from_mem1;
logic is_stall;
logic is_flush;
logic [11:0]icache_idx;
logic [2:0]icache_op;
u32_t icache_pa;            //QUES:cache里认为接收到的pa是20位的
logic icache_is_cached;
logic icache_ready;
u32_t icache_data;
logic icache_stall_from_fetch2;
logic dcache_ready;
u32_t dcache_data;
logic dcache_stall;
logic [11:0]dcache_idx;
logic [2:0]dcache_op;
u32_t dcache_pa;
logic dcache_is_cached;
byte_type_t dcache_byte_type;

u32_t rj_data, rk_data;     //QUES:将decode和regfile中的rk和rkd相连
reg_idx_t rj, rk;  
u32_t out_from_alu;
logic [63:0] out_from_mul;  
forward_req_t mem1_req;   
forward_req_t mem2_req;    
csr_t rd_from_csr_to_excp;
excp_wr_csr_req_t excp_wr_csr_req;
logic reg_we;
csr_t tlb_rd;
tlb_wr_csr_req_t tlb_wr_req;
csr_addr_t wb_addr_to_csr;
logic wb_we_to_csr;
u32_t wb_data_to_csr;
u32_t csr_rd_data_to_regfile;       //QUES: why regfile rd_data from csr
reg_idx_t rd_from_wb;
u32_t rd_data_from_wb;
u32_t old_pc_from_exception;

BTB btb(.clk(clk), .rst_n(rst_n), .is_stall(),  .pc(btb_pc), 
        .predict_out(predict_out_from_btb), .ex_resolved_in(ex_resolved_in));
Fetch1 fetch1(.clk(clk), .rst_n(rst_n), 
                .btb_is_stall(), .btb_pc(btb_pc), .btb_predict(predict_out_from_btb), 
                .ex_wr_pc_req(ex_wr_pc_req), 
                .rd_csr(), 
                .tlb_entrys(), 
                .icache_idx(icache_idx), .icache_op(icache_op), .icache_pa(icache_pa), .icache_is_cached(icache_is_cached),
                .is_stall(), .is_flush(),
                .pass_out(pass_out_from_fetch1), .excp_pass_out(excp_pass_out_from_fetch1));
Fetch2 fetch2(.clk(clk), .rst_n(rst_n), 
                .icache_ready(icache_ready), .icache_data(icache_data), .icache_stall(icache_stall_from_fetch2), 
                .is_stall(), .is_flush(), 
                .pass_in(pass_out_from_fetch1), .excp_pass_in(excp_pass_out_from_fetch1), .pass_out(pass_out_from_fetch2), .excp_pass_out(excp_pass_out_from_fetch2));

Decode decode(.clk(clk), .rst_n(rst_n),
                .rj(rj), .rk(), .rj_data(rj_data), .rk_data(rk_data),
                .load_use_stall(), 
                .is_stall(), .is(), .pass_in(pass_out_from_fetch2), .excp_pass_in(excp_pass_out_from_fetch2),
                .pass_out(pass_out_from_decode), .excp_pass_out(excp_pass_out_from_decode));

RegFile regfile(.clk(clk), .rst_n(rst_n),
                .rj(rj), .rkd(rk), .rj_data(rj_data), .rkd_data(rk_data),
                .we(reg_we), .rd(rd_from_wb), .rd_data(rd_data_from_wb));

Execute execute(.clk(clk), .rst_n(rst_n), 
                .eu_stall(), .bp_miss_flush(), 
                .wr_pc_req(ex_wr_pc_req),
                .mem1_req(mem1_req), .mem2_req(mem2_req),
                .rd_csr(), 
                .is_stall(), .is_flush(), 
                .pass_in(pass_out_from_decode), .excp_pass_in(excp_pass_out_from_decode), .pass_out(pass_out_from_exec), .excp_pass_out(excp_pass_out_from_exception));

Memory1 memory1(.clk(clk), .rst_n(rst_n), 
                .fwd_req(mem1_req), 
                .rd_csr(),
                .tlb_entrys(), 
                
                .dcache_idx(dcache_idx), .dcache_op(dcache_op), .dcache_pa(dcache_pa), .dcache_is_cached(dcache_is_cached), .dcache_byte_type(dcache_byte_type),
                .is_stall(), .is_flush(), 
                .pass_in(pass_out_from_exec), .excp_pass_in(excp_pass_out_from_exception), 
                .pass_out(), .excp_pass_out(excp_pass_out_from_mem1));

Memory2 memory2(.clk(clk), .rst_n(rst_n), 
                .fwd_req(mem2_req), 
                .dcache_ready(dcache_ready), .dcache_data(dcache_data), .dcache_stall(dcache_stall), 
                .is_stall(), .is_flush(), 
                .pass_in(pass_out_from_mem1), .excp_pass_in(excp_pass_out_from_mem1), 
                .pass_out(pass_out_from_mem2), .excp_pass_out());


Writeback writeback(.clk(clk), .rst_n(rst_n),
                    .reg_idx(rd_from_wb), .reg_we(reg_we), .reg_data(rd_data_from_wb), 
                    .csr_addr(wb_addr_to_csr), .csr_we(wb_we_to_csr), .csr_data(wb_data_to_csr), 
                    .is_stall(), .is_flush(),
                    .pass_in(pass_out_from_mem2));


TLB tlb(.clk(clk),
        .rd_csr_asid(tlb_rd.asid), .rd_csr_tlbehi(tlb_rd.tlbehi), .rd_csr_tlbelo(tlb_rd.tlbelo), .rd_csr_tlbidx(tlb_rd.tlbidx), .rd_csr_estat(tlb_rd.estat),
        .we_tlb_csr(tlb_wr_req.we), .wr_csr_asid(tlb_wr_req.asid), .wr_csr_tlbehi(tlb_wr_req.tlbehi), .wr_csr_tlbelo(tlb_wr_req.tlbelo), .wr_csr_tlbidx(tlb_wr_req.tlbidx),
        .tlbsrch(), .tlbrd(), .tlbwr(), .tlbfill(), .invtlb(), .invtlb_op(), .invtlb_asid(),
        .itlb_lookup(), .dtlb_lookup());

Exception exception(.ti_in(), .hwi_in(), 
                    .inst_eret(), .old_pc(old_pc_from_exception), 
                    .excp_pc(), .wb_excp(), .excp_entry_pc(), 
                    .rd_csr(rd_from_csr_to_excp), .wr_csr_req(excp_wr_csr_req));

CSR csr(.clk(clk), rst_n(rst_n), 
        .addr(wb_addr_to_csr), .rd_data(), .we(wb_we_to_csr), .wr_data(wb_data_to_csr),
        .tlb_rd(tlb_rd), .tlb_wr_req(tlb_wr_req), 
        .excp_rd(rd_from_csr_to_excp), .excp_wr_req(excp_wr_csr_req));




endmodule
