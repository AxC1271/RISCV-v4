module free_list 
    import core_types_pkg::*;
(
    input  logic clk,
    input  logic rst_n,

    // allocate requests from renaming
    input  logic alloc_req0,
    input  logic alloc_req1,

    output logic alloc_valid0,
    output phys_tag_t alloc_tag0,

    output logic alloc_valid1,
    output phys_tag_t alloc_tag1,

    // returned physical regs
    input  logic free_valid0,
    input  phys_tag_t free_tag0,

    input  logic free_valid1,
    input  phys_tag_t free_tag1,

    output logic [$clog2(PHYS_REGS+1)-1:0] free_count
);

endmodule