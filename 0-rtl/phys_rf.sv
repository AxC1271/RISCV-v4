module phys_rf 
    import core_types_pkg::*;    
(
    input  logic clk,
    input  logic rst_n,

    input  phys_tag_t raddr0,
    output data_t rdata0,

    input  phys_tag_t raddr1,
    output data_t rdata1,

    input  phys_tag_t raddr2,
    output data_t rdata2,

    input  phys_tag_t raddr3,
    output data_t rdata3,

    input  logic we0,
    input  phys_tag_t waddr0,
    input  data_t wdata0,

    input  logic we1,
    input  phys_tag_t waddr1,
    input data_t wdata1
);

    /*
    1. All of my RTL logic lives here
    2. All combinational/registered logic are defined here
    3. Use these during testbenches/simulations 
    */

    data_t regs[PHYS_REGS];

    /*
    1. My formal properties live here
    2. All asserts, assumes, and covers are defined here
    3. Use these during SymbiYosys for formal verification
    */

endmodule