// 4kB 2-way set-associative cache
// each set has 2 lines, each being 32 bytes
// 4096 bytes / (2 ways/set * 32 bytes/way)
// 4096 bytes / (64 bytes/set) = 64 sets
// 6 bits for index, 5 bits for byte offset
// the remaining 21 bits are the tags

module l1_icache # (
    parameter ADDR_BITS      = 32,
    parameter NUM_SETS       = 64,
    parameter NUM_WAYS       = 2,
    parameter WORDS_PER_LINE = 8
) (
    input  logic clk,
    input  logic rst_n,

    input  logic                  req_valid,
    output logic                  req_ready,
    input  logic [ADDR_BITS-1:0]  req_pc,

    output logic                  resp_valid,
    input  logic                  resp_ready,

    output logic [ADDR_BITS-1:0]  resp_instr0,
    output logic [ADDR_BITS-1:0]  resp_instr1,

    output logic                  resp_instr0_valid,
    output logic                  resp_instr1_valid,

    input  logic                  flush,

    output logic                  mem_req_valid,
    input  logic                  mem_req_ready,
    output logic [ADDR_BITS-1:0]  mem_req_addr,

    input  logic                  mem_resp_valid,
    input  logic [ADDR_BITS-1:0]  mem_resp_data
);

    logic [31:0] data_ram
    [0:NUM_WAYS-1]
    [0:NUM_SETS-1]
    [0:WORDS_PER_LINE-1];

    logic [TAG_BITS-1:0] tag_ram
    [0:NUM_WAYS-1]
    [0:NUM_SETS-1];

    logic valid_ram
    [0:NUM_WAYS-1]
    [0:NUM_SETS-1];

    logic lru_ram [0:NUM_SETS-1];

endmodule