// 4kB 2-way set-associative cache
// each set has 2 lines, each being 32 bytes
// 4096 bytes / (2 ways/set * 32 bytes/way)
// 4096 bytes / (64 bytes/set) = 64 sets
// 6 bits for index, 5 bits for byte offset
// the remaining 21 bits are the tags

module l1_dcache # (
    parameter NUM_SETS       = 64,
    parameter ADDR_BITS      = 32,
    parameter WORDS_PER_LINE = 8,
    parameter NUM_WAYS       = 2
) (
    input  logic clk,
    input  logic rst_n,
);

endmodule