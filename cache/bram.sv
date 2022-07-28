`include "cache.svh"

module data (
    input logic [`INDEX_WIDTH]addra,
    input logic clka,
    input logic [`DATA_WIDTH]dina,
    input logic ena,
    input logic [`BLOCK_EN]wea,
    input logic [`INDEX_WIDTH]addrb,
    input logic clkb,
    output logic [`DATA_WIDTH]doutb
);
logic enb;
assign enb = 1'b1;
ByteEnDualPortBram #(
    .WID(32),
    .SIZE(128)
) U1_ByteEnDualPortBram (
    .clk(clka), 
    .ena(ena),
    .enb(enb),
    .wea(wea),
    .addra(addra),
    .addrb(addrb),
    .dina(dina),
    .doutb(doutb)
);
    
endmodule

`include "cache.svh"

module tag (
    input logic [`INDEX_WIDTH]addra,
    input logic clka,
    input logic [`TAG_WIDTH]dina,
    input logic ena,
    input logic wea,
    input logic [`INDEX_WIDTH]addrb,
    input logic clkb,
    output logic [`TAG_WIDTH]doutb
);
logic enb;
assign enb = 1'b1;
DualPortBram #(.WID(20), .SIZE(128))
dualportbram(.clk(clka), 
             .ena(ena),
             .enb(enb),
             .wea(wea),
             .addra(addra),
             .addrb(addrb),
             .dina(dina),
             .doutb(doutb) );
    
endmodule

`include "cache.svh"

module vl (
    input logic [`INDEX_WIDTH]addra,
    input logic clka,
    input logic dina,
    input logic ena,
    input logic wea,
    input logic [`INDEX_WIDTH]addrb,
    input logic clkb,
    output logic doutb
);
logic enb;
assign enb = 1'b1;
DualPortBram #(.WID(1), .SIZE(128))
dualportbram(.clk(clka), 
             .ena(ena),
             .enb(enb),
             .wea(wea),
             .addra(addra),
             .addrb(addrb),
             .dina(dina),
             .doutb(doutb) );
    
endmodule

`include "cache.svh"

module llit (
    input logic [`INDEX_WIDTH]addra,
    input logic clka,
    input logic [7:0]dina,
    input logic ena,
    input logic wea,
    input logic [`INDEX_WIDTH]addrb,
    input logic clkb,
    output logic [7:0]doutb
);
logic enb;
assign enb = 1'b1;
DualPortBram #(.WID(8), .SIZE(128))
dualportbram(.clk(clka), 
             .ena(ena),
             .enb(enb),
             .wea(wea),
             .addra(addra),
             .addrb(addrb),
             .dina(dina),
             .doutb(doutb) );
    
endmodule