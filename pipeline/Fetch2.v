module Fetch2 (
    output reg [31:0] inst,

    // segment-register input
    input [31:0] pc_RegInput,
    output reg [31:0] pc,

    input stall_RegInput, clear_RegInput,
    output reg clear,
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
    if (clear_RegInput) begin
        clear <= 1;
    end
    else begin
        clear <= 0;
        if (stall_RegInput) begin
            inst    <= inst;
            pc      <= pc;
        end
        else begin
            inst    <= cache_read;
            pc      <= pc_RegInput;
        end
    end
end

endmodule