module Counter #(
    parameter WID = 32
)(
    input logic clk,
    input logic clr,
    output logic [WID-1:0] cnt
);

    always_ff @(posedge clk) begin
        if(clr) cnt <= '0;
        else    cnt <= cnt + 1;
    end

endmodule