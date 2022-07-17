module Fetch1 (
    output reg [31:0] pc,

    // segment-register input
    input [31:0] next_pc,
    
    input stall, clear,
    output reg clear_pass,
    input clk,

    // interface with TLB
    // interface with ICache
    output [31:0] v_addr
);

always @(posedge clk) begin
    if (clear) begin
        clear_pass <= 1;
    end
    else begin
        clear_pass <= 0;
        if (stall) begin
            pc <= pc;
        end
        else begin
            pc <= next_pc;
        end
    end
end

assign v_addr = pc;

endmodule