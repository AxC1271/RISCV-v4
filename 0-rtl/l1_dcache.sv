// 4kB 4-way set-associative cache
// each set has 4 lines, each being 32 bytes
// 4096 bytes / (4 ways/set * 32 bytes/way)
// 4096 bytes / (128 bytes/set) = 32 sets
// 5 bits for index, 5 bits for byte offset
// the remaining 22 bits are the tags

module l1_dcache # (
    parameter ADDR_BITS      = 32,
    parameter NUM_SETS       = 32,
    parameter NUM_WAYS       = 4,
    parameter WORDS_PER_LINE = 8
) (
    input  logic clk,
    input  logic rst_n,
);

endmodule