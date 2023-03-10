module DualPortDmem #(
  parameter WID = 32,
  parameter SIZE = 256
)(
  input logic clk,
  input logic wea,
  input logic [$clog2(SIZE)-1:0] addra, addrb,
  input logic [WID-1:0] dina,
  output logic [WID-1:0] douta, doutb
);

    (* ram_style = "distributed" *) logic [WID-1:0] ram [SIZE-1:0];

    always_ff @(posedge clk) begin
        if(wea) begin
            ram[addra] <= dina;
        end
    end

    always_comb begin
        douta = ram[addra];
        doutb = ram[addrb];
    end

endmodule