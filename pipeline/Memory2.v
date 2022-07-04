module Memory2 (
    output [31:0] result,
    output ready,
    input [1:0] memory_rw,
    input [31:0] data_write,
    input [31:0] forwarding,
    input p_address_valid,
    input [31:0] p_address,
    input [127:0] data_read
);

endmodule