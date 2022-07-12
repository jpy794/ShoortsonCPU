/*
 * A RegFile with forwarding inside
 */

module RegFile (
    input logic clk,

    /* read */
    input logic [4:0] rj_index,
    input logic [4:0] rk_index,
    output logic [31:0] rj_read,
    output logic [31:0] rk_read,

    /* write */
    input logic we,
    input logic [4:0] rd_index
    input logic [31:0] rd_write,
);

logic [31:0] regfile [32];

/* fowarding */
always_comb begin
    if(we & ~(rj_index ^ rd_index)) rj_read = rd_write;
    else                            rj_read = regfile[rj_index];
end

always_comb begin
    if(we & ~(rj_index ^ rd_index)) rk_read = rd_write;
    else                            rk_read = regfile[rk_index];
end

always_ff @(posedge clk) begin
    if(we) regfile[rd_index] <= rd_write;
end

endmodule