module SinglePortBram #(
  parameter WID = 32,
  parameter SIZE = 256
)(
  input logic clk,
  input logic en, we,
  input logic [$clog2(SIZE)-1:0] addr,
  input logic [WID-1:0] din,
  output logic [WID-1:0] dout
);

    (* ram_style = "block" *) logic [WID-1:0] ram [SIZE-1:0];

    always_ff @(posedge clk) begin
        if(en) begin
            if (we)
                ram[addr] <= din;
            else
                dout <= ram[addr];
        end
    end

endmodule