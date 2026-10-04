// 64kB 4-way set-associative cache
// each set has 4 lines, each being 32 bytes
// 2**16 bytes / (4 ways/set * 32 bytes/way)
// 2**16 bytes / (2**7 bytes/set) = 512 sets
// 9 bits for index, 5 bits for byte offset
// the remaining 18 bits are the tags

module l2_cache # (
    parameter NUM_SETS       = 512,
    parameter ADDR_BITS      = 32,
    parameter WORDS_PER_LINE = 8,
    parameter NUM_WAYS       = 4
) (
    input  logic clk,
    input  logic rst_n,

    input  logic                  req_valid,
    output logic                  req_ready,
    input  logic [ADDR_BITS-1:0]  req_addr,
    input  logic                  req_write,
    input  logic [ADDR_BITS-1:0]  req_wdata,
    input  logic [3:0]            req_wstrb,

    output logic                  resp_valid,
    input  logic                  resp_ready,
    output logic [ADDR_BITS-1:0]  resp_rdata,

    output logic                  mem_req_valid,
    input  logic                  mem_req_ready,
    output logic [ADDR_BITS-1:0]  mem_req_addr,
    output logic                  mem_req_write,
    output logic [ADDR_BITS-1:0]  mem_req_wdata,
    output logic [3:0]            mem_req_wstrb,

    input  logic                  mem_resp_valid,
    input  logic [ADDR_BITS-1:0]  mem_resp_rdata
);

endmodule