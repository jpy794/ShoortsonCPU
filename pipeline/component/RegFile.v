/**
 * A RegFile with forwarding inside
 */

module RegFile (
    output [31:0] rj_read,
    output [31:0] rk_read,
    input [31:0] rd_write,
    input we,
    input [4:0] rj_index,
    input [4:0] rk_index,
    input [4:0] rd_index,
    input clk
);

always @(posedge clk ) begin
    
end

endmodule