`include "cpu_defs.svh"

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
        if(we && (rj == rd))    rj_data = rd_data;
        else                    rj_data = regfile[rj];
    end

    always_comb begin
        if(we && (rkd == rd))   rkd_data = rd_data;
        else                    rkd_data = regfile[rkd];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n)                      regfile[0] <= '0;
        else if(we && rd != 5'b0)       regfile[rd] <= rd_data;
    end

    /* difftest */
    DifftestGRegState DifftestGRegState(
        .clock              (clk            ),
        .coreid             (0              ),
        .gpr_0              (regfile[0]     ),
        .gpr_1              (regfile[1]     ),
        .gpr_2              (regfile[2]     ),
        .gpr_3              (regfile[3]     ),
        .gpr_4              (regfile[4]     ),
        .gpr_5              (regfile[5]     ),
        .gpr_6              (regfile[6]     ),
        .gpr_7              (regfile[7]     ),
        .gpr_8              (regfile[8]     ),
        .gpr_9              (regfile[9]     ),
        .gpr_10             (regfile[10]    ),
        .gpr_11             (regfile[11]    ),
        .gpr_12             (regfile[12]    ),
        .gpr_13             (regfile[13]    ),
        .gpr_14             (regfile[14]    ),
        .gpr_15             (regfile[15]    ),
        .gpr_16             (regfile[16]    ),
        .gpr_17             (regfile[17]    ),
        .gpr_18             (regfile[18]    ),
        .gpr_19             (regfile[19]    ),
        .gpr_20             (regfile[20]    ),
        .gpr_21             (regfile[21]    ),
        .gpr_22             (regfile[22]    ),
        .gpr_23             (regfile[23]    ),
        .gpr_24             (regfile[24]    ),
        .gpr_25             (regfile[25]    ),
        .gpr_26             (regfile[26]    ),
        .gpr_27             (regfile[27]    ),
        .gpr_28             (regfile[28]    ),
        .gpr_29             (regfile[29]    ),
        .gpr_30             (regfile[30]    ),
        .gpr_31             (regfile[31]    )
    );

endmodule