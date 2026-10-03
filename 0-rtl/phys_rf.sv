module phys_rf 
    import core_types_pkg::*;    
(
    input  logic clk,

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

    // read data
    assign rdata0 = regs[raddr0];
    assign rdata1 = regs[raddr1];
    assign rdata2 = regs[raddr2];
    assign rdata3 = regs[raddr3];

    // handle writes here
    always_ff @(posedge clk) begin
        if (we0 && (waddr0 != '0))
            regs[waddr0] <= wdata0;
    
        if (we1 && (waddr1 != '0))
            regs[waddr1] <= wdata1;
    end

    /*
    1. My formal properties live here
    2. All asserts, assumes, and covers are defined here
    3. Use these during SymbiYosys for formal verification
    */

endmodule