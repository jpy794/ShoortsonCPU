module Fetch2 (
    output reg [31:0] inst,

    // segment-register input
    input [31:0] pc,
    output reg [31:0] pc_pass,

    input stall, clear,
    output reg clear_pass,
    input clk,

    // interface with TLB
    input tlb_hit,
    input [63:0] tlb_read,
    
    // interface with ICache
    output [31:0] p_addr,
    output p_addr_valid,
    input cache_ready,
    input [31:0] cache_read
);

always @(posedge clk) begin
    if (clear) begin
        clear_pass <= 1;
    end
    else begin
        clear_pass <= 0;
        if (stall) begin
            inst <= inst;
            pc_pass <= pc_pass;
        end
        else begin
            inst <= cache_read;
            pc_pass <= pc;
        end
    end
end

endmodule