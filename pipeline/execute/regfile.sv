`include "../cpu_defs.svh"

module RegFile (
    input logic clk, rst_n,

    /* read */
    input reg_idx_t rj,
    input reg_idx_t rkd,
    output u32_t rj_data,
    output u32_t rkd_data,

    /* write */
    input logic we,
    input reg_idx_t rd,
    input u32_t rd_data
);

    logic [31:0] regfile [32];

    /* fowarding */
    always_comb begin
        if(we && (rj == rkd))    rj_data = rkd_data;
        else                    rj_data = regfile[rj];
    end

    always_comb begin
        if(we && (rj == rkd))    rk_data = rkd_data;
        else                    rk_data = regfile[rk];
    end

    always_ff @(posedge clk) begin
        if(~rst_n)                      regfile[0] <= '0;
        else if(we && rkd != 5'b0)       regfile[rkd] <= rkd_data;
    end

endmodule