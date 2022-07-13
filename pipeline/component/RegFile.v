/**
 * A RegFile with forwarding inside
 */

module RegFile (
    output reg [31:0] rj_read,
    output reg [31:0] rk_read,
    input [31:0] rd_write,
    input we,
    input [4:0] rj_index,
    input [4:0] rk_index,
    input [4:0] rd_index,
    input clk
);

reg [31:0] rf [0:31];

always @(*) begin
    if (rj_index == 0) rj_read = 0;
    else rj_read = rf[rj_index];
end

always @(*) begin
    if (rk_index == 0) rk_read = 0;
    else rk_read = rf[rk_index];
end

always @(posedge clk ) begin
    if (we) rf[rd_index] <= rd_write;
end

endmodule