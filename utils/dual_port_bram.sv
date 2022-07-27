module DualPortBram #(
  parameter WID = 32,
  parameter SIZE = 256
)(
  input logic clk,
  input logic ena, enb, wea,        //TO BE FIXED
  input logic [$clog2(SIZE)-1:0] addra, addrb,
  input logic [WID-1:0] dina,
  output logic [WID-1:0] doutb
);

    (* ram_style = "block" *) logic [WID-1:0] ram [SIZE-1:0];

    always_ff @(posedge clk) begin
        if(ena & wea) begin
            ram[addra] <= dina;
        end
    end

    always_ff @(posedge clk) begin
        if(enb) begin
            doutb <= ram[addrb];
        end
    end

endmodule