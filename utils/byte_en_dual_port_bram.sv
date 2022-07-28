module ByteEnDualPortBram #(
  parameter WID = 32,
  parameter SIZE = 256
)(
  input logic clk,
  input logic ena, enb,
  input logic [WID/8-1:0] wea,
  input logic [$clog2(SIZE)-1:0] addra, addrb,
  input logic [WID-1:0] dina,
  output logic [WID-1:0] doutb
);

    (* ram_style = "block" *) logic [WID-1:0] ram [SIZE-1:0];

    integer i;
    always_ff @(posedge clk) begin
        if(ena) begin
            for(i=0; i<WID/8; i=i+1) begin
                if(wea[i]) begin
                    ram[addra][i*8+:8] <= dina[i*8+:8];
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if(enb) begin
            doutb <= ram[addrb];
        end
    end

endmodule