//INFO
`define WAY 1:0
`define BLOCK 7:0
`define BLOCK_EN 3:0

`define WAY_NUM 2
`define BLOCK_NUM 8
`define WAY_PART 0:0

//state 
`define DATA_WRITE_ENABLE 4'b1111
`define DATA_WRITE_UNABLE 4'b0000
`define ENABLE 1'b1;
`define UNABLE 1'b0;
`define HIT 1'b1;
`define MISS 1'b0
`define CLEAR_TAG 20'b0000_0000_0000_0000_0000
`define SET_V 1'b1;
`define CLEAR_V 1'b0;

`define CLEAR_DIRTY 1'b0;
`define SET_DIRTY 1'b1

`define READY 1'b1
`define UNREADY 1'b0

`define UNCACHED 1'b0;
`define CACHED 1'b1
//BUS
`define DATA_WIDTH 31 : 0
`define WRITE_ENABLE 3 : 0
`define ADDRESS_WIDTH 31 : 0
`define VA_WIDTH 11 : 0
`define PA_WIDTH 19 : 0
`define BLOCK_WIDTH 255 : 0
`define TAG_WIDTH 19:0
`define INDEX_WIDTH 6:0
`define TAG_PART 31:12
`define INDEX_PART 11:5
`define OFFSET_PART 4:2
`define LLIT_WIDTH  7:0

//op
`define ICACHE_OP_WIDTH 2:0
`define DCACHE_OP_WIDTH 4:0

//finate machine
`define ICACHE_STATE_WIDTH 4:0
`define I_LOAD 4'b0001
`define I_WRITE_TAG 4'b0010
`define I_WRITE_V 4'b0011
`define I_WRITE 4'b0100 
`define I_REQ_BLOCK 4'b0101 
`define I_NONE 4'b0000
`define I_REQ_WORD 4'b0110
`define I_DONE 4'b0111
`define I_WAIT_LOAD_BLOCK_FINISH 4'b1000
`define I_WAIT_LOAD_WORD_FINISH 4'b1001

`define ICACHE_REQ_NONE 3'b000
`define ICACHE_REQ_INITIALIZE 3'b101
`define ICACHE_REQ_LOAD_INS 3'b001
`define ICACHE_REQ_INDEX_INVALIDATA 3'b110
`define ICACHE_REQ_HIT_INVALIDATA 3'b111

`define DCACHE_STATE_WIDTH 4:0
`define D_LOAD 5'b00001
`define D_WRITE_TAG 5'b00010
`define D_WRITE_V 5'b00011
`define D_CLEAR_LLIT 5'b00100 
`define D_SET_LLIT 5'b00101 
`define D_STORE 5'b00110 
`define D_WRITE 5'b00111 
`define D_WAIT_UNCACHED_LOAD 5'b01000 
`define D_WAIT_UNCACHED_WRITE 5'b01001
`define D_WAIT_STORE 5'b01010 
`define D_WAIT_LOAD 5'b01011
`define D_WAIT_LOAD_ATOM 5'b01100 
`define D_WAIT_STORE_LOAD 5'b01101
`define D_WAIT_STORE_STORE 5'b01110 
`define D_WAIT_STORE_LOAD_ATOM 5'b01111 
`define D_NONE 5'b00000

`define DCACHE_REQ_NONE 5'b00000
`define DCACHE_REQ_LOAD_ATOM 5'b01100
`define DCACHE_REQ_LOAD_WORD 5'b01000
`define DCACHE_REQ_LOAD_HALF_WORD 5'b01001
`define DCACHE_REQ_LOAD_BYTE 5'b01010
`define DCACHE_REQ_STORE_ATOM 5'b10100
`define DCACHE_REQ_STORE_WORD 5'b10000
`define DCACHE_REQ_STORE_HALF_WORD 5'b10001
`define DCACHE_REQ_STORE_BYTE 5'b10010
`define DCACHE_REQ_INITIALIZE 5'b11000
`define DCACHE_REQ_INDEX_INVALIDATA 5'b11001
`define DCACHE_REQ_HIT_INVALIDATA 5'b11010
`define DCACHE_REQ_PRELD 5'b11011
`define DCACHE_REQ_CLEAR_LLIT 5'b11100
//pipline
`define ICACHE_REQ_TO_PIPLINE_WIDTH 1 : 0
`define ICACHE_REQ_TO_PIPLINE_NONE 2'b00
`define ICACHE_REQ_TO_PIPLINE_BLOCK 2'b01  
`define ICACHE_REQ_TO_PIPLINE_WORD 2'b10


`define DCACHE_REQ_TO_PIPLINE_WIDTH 2 : 0
`define DCACHE_REQ_TO_PIPLINE_NONE 3'b000
`define DCACHE_REQ_TO_PIPLINE_LOAD_BLOCK 3'b001
`define DCACHE_REQ_TO_PIPLINE_LOAD_WORD 3'b010
`define DCACHE_REQ_TO_PIPLINE_LOAD_STORE_BLOCK 3'b101
`define DCACHE_REQ_TO_PIPLINE_STORE_WORD 3'b110

`define RESPONSE_FROM_PIPLINE_WIDTH 1 : 0
`define FINISH_ICACHE_REQ   2'b01
`define FINISH_DCACHE_REQ   2'b10
`define FINISH_CACHE_REQ_NONE 2'b00

`define DCACHE_CNT_WIDTH 6:0
`define DCACHE_CNT_FINISH 7'b111_1111
`define DCACHE_CNT_START 7'b000_0000

`define DCACHE_REQ_STORE_ATOM_SUCCESS 32'h0000_0001
`define DCACHE_REQ_STORE_ATOM_FAIL 32'h0000_0000

`define DCACHE_REQ_REN_WIDTH 1 : 0
`define DCACHE_REQ_REN_WORD  2'b11
`define DCACHE_REQ_REN_HALF_WORD 2'b10
`define DCACHE_REQ_REN_BYTE 2'b01

//pipline
`define PIPLINE_STATE_WIDTH 4 : 0
`define PIPLINE_WAIT 5'b00000
`define PIPLINE_REQ_STORE_BLOCK 5'b00001
`define PIPLINE_STORE_BLOCK_WAIT_READY 5'b00010
`define PIPLINE_STORE_BLOCK_WAIT_FINISH 5'b00011
`define I_PIPLINE_REQ_LOAD_BLOCK 5'b00100
`define I_PIPLINE_LOAD_BLOCK_WAIT_READY 5'b00101
`define I_PIPLINE_LOAD_BLOCK_WAIT_FINISH 5'b00110
`define PIPLINE_REQ_STORE_WORD 5'b01000
`define PIPLINE_STORE_WORD_WAIT_READY 5'b01001
`define PIPLINE_STORE_WORD_WAIT_FINISH 5'b01010
`define I_PIPLINE_REQ_LOAD_WORD 5'b01011
`define I_PIPLINE_LOAD_WORD_WAIT_READY 5'b01100
`define I_PIPLINE_LOAD_WORD_WAIT_FINISH 5'b01101
`define I_PIPLINE_LOAD_BLOCK_FINISH 5'b01110
`define I_PIPLINE_LOAD_WORD_FINISH 5'b01111
`define D_PIPLINE_REQ_LOAD_BLOCK 5'b10000
`define D_PIPLINE_LOAD_BLOCK_WAIT_READY 5'b10001
`define D_PIPLINE_LOAD_BLOCK_WAIT_FINISH 5'b10010
`define D_PIPLINE_LOAD_BLOCK_FINISH 5'b10011
`define D_PIPLINE_REQ_LOAD_WORD 5'b10100
`define D_PIPLINE_LOAD_WORD_WAIT_READY 5'b10101
`define D_PIPLINE_LOAD_WORD_WAIT_FINISH 5'b10110
`define D_PIPLINE_LOAD_WORD_FINISH 5'b10111
`define PIPLINE_STORE_WORD_FINISH 5'b11000
`define PIPLINE_STORE_BLOCK_FINISH 5'b11001

`define REQ_TO_AXI_WRITE_BLOCK 3'b001
`define REQ_TO_AXI_LOAD_BLOCK 3'b010
`define REQ_TO_AXI_WRITE_WORD 3'b011
`define REQ_TO_AXI_LOAD_WORD 3'b100
`define REQ_TO_AXI_NONE 3'b000
//axi
`define AXI_REQ_WIDTH 2 : 0
`define AXI_RESPONSE_WIDTH 2 : 0
`define AXI_ID_WIDTH 3:0
`define AXI_LEN_WIDTH 3 : 0
`define AXI_SIZE_WIDTH 2 : 0
`define AXI_BURST_WIDTH 1 : 0
`define AXI_LOCK_WIDTH 1 : 0
`define AXI_CACHE_WIDTH 3:0
`define AXI_PROT_WIDTH 2 : 0
`define AXI_RESP_WIDTH 1 : 0
`define AXI_STRB_WIDTH 3 : 0
`define AXI_STATE_WIDTH 5 : 0

`define AXI_STATE_WAIT 6'b000000
`define AXI_STATE_REQ_STORE_BLOCK 6'b000001
`define AXI_STATE_REQ_STORE_WORD 6'b000010
`define AXI_STATE_REQ_LOAD_BLOCK 6'b000011
`define AXI_STATE_REQ_LOAD_WORD 6'b000100
`define AXI_STATE_STORE_BLOCK_WAIT_AWREADY 6'b000101
`define AXI_STATE_STORE_BLOCK_WAIT_WREADY 6'b000110
`define AXI_STATE_STORE_BLOCK_WAIT_BVALID 6'b000111
`define AXI_STATE_STORE_BLOCK_DATA0 6'b001001
`define AXI_STATE_STORE_BLOCK_DATA1 6'b001010
`define AXI_STATE_STORE_BLOCK_DATA2 6'b001011 
`define AXI_STATE_STORE_BLOCK_DATA3 6'b001100 
`define AXI_STATE_STORE_BLOCK_DATA4 6'b001101 
`define AXI_STATE_STORE_BLOCK_DATA5 6'b001110 
`define AXI_STATE_STORE_BLOCK_DATA6 6'b001111 
`define AXI_STATE_STORE_BLOCK_DATA7 6'b010000 
`define AXI_STATE_LOAD_BLOCK_WAIT_ARREADY 6'b010001
`define AXI_STATE_LOAD_BLOCK_WAIT_RVALID 6'b100000
`define AXI_STATE_LOAD_BLOCK_DATA0 6'b010010
`define AXI_STATE_LOAD_BLOCK_DATA1 6'b010011
`define AXI_STATE_LOAD_BLOCK_DATA2 6'b010100
`define AXI_STATE_LOAD_BLOCK_DATA3 6'b010101
`define AXI_STATE_LOAD_BLOCK_DATA4 6'b010110
`define AXI_STATE_LOAD_BLOCK_DATA5 6'b010111
`define AXI_STATE_LOAD_BLOCK_DATA6 6'b011000
`define AXI_STATE_LOAD_BLOCK_DATA7 6'b011001
`define AXI_STATE_LOAD_BLOCK_FINISH 6'b011010
`define AXI_STATE_STORE_WORD_WAIT_AWREADY 6'b011011
`define AXI_STATE_STORE_WORD_WAIT_WREADY 6'b011100
`define AXI_STATE_STORE_WORD_WAIT_BVALID 6'b011101 
`define AXI_STATE_LOAD_WORD_WAIT_ARREADY 6'b011110 
`define AXI_STATE_LOAD_WORD_WAIT_RVALID 6'b011111
`define AXI_STATE_LOAD_WORD_SUCCESS 6'b100011


`define AXI_READ_ID 4'b0000
`define AXI_WRITE_ID 4'b0001
`define AXI_BURST_INCR 2'b01
`define AXI_BURST_FIXED 2'b00
`define AXI_LOCK_NORMAL 2'b00
`define AXI_LEN_SINGAL 4'b0000
`define AXI_LEN_BLOCK 4'b1000
`define AXI_SIZE_WORD 3'b101
`define AXI_SIZE_HALF_WORD 3'b100
`define AXI_SIZE_BYTE 3'b011

`define AXI_CACHE_CACHE 4'b0000    //TODO
`define AXI_PORT_INS 3'b100
`define AXI_PORT_DATA 3'b000;

`define ICACHE_WAIT 4'b0000
`define ICACHE_LOOKUP 4'b0001
`define ICACHE_INDEX_WRITE_V 4'b0010
`define ICACHE_WRITE_TAG 4'b0011
`define ICACHE_REQ_LOAD_WORD 4'b0100
`define ICACHE_REQ_LOAD_BLOCK 4'b0101
`define ICACHE_LOAD_WORD_WAIT 4'b0110
`define ICACHE_LOAD_BLOCK_WAIT 4'b0111
`define ICACHE_WRITE 4'b1000
`define ICACHE_HIT_WRITE_V 4'b1001


