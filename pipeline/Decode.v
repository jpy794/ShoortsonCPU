module Decode (
    // SIG
    output execute_type,
    output writeback_valid,
    output [1:0] memory_rw,

    output [31:0] immediate_number,
    output [63:0] register_read,
    input [31:0] inst,
    input [31:0] register_writeback,
    input register_writeback_valid
);

// RegFile

endmodule