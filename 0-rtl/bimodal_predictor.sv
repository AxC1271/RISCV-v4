module bimodal_predictor (
    input  logic       clk,
    input  logic       rst_n,
    input  logic[31:0] pc,
    input  logic[31:0] pc2,
    output logic       prediction,
    output logic       prediction2,

    // update from the ex stage
    input  logic[31:0] branch_pc,
    input  logic       branch_taken,
    input  logic       branch_valid
);

    /*
    1. All of my RTL logic lives here
    2. All combinational/registered logic are defined here
    3. Use these during testbenches/simulations 
    */

    // branch predictor scheme is defined as a 2-bit saturating
    // counter. 00 means strongly not taken, 01 means weakly not taken,
    // 10 means weakly taken, and 11 means strongly taken
    logic[1:0] bht [0:511];
    logic[8:0] rd_idx, rd_idx2, wr_idx;

    // prediction lookup, purely combinational
    assign rd_idx = pc[10:2];
    assign rd_idx2 = pc2[10:2];
    assign prediction = bht[rd_idx][1];
    assign prediction2 = bht[rd_idx2][1];

    // prediction update, sequential in WB stage
    assign wr_idx = branch_pc[10:2];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 512; i++) 
                bht[i] <= 2'b00;
        end else if (branch_valid) begin
            if (branch_taken && bht[wr_idx] != 2'b11)
                bht[wr_idx] <= bht[wr_idx] + 2'b01;
            else if (!branch_taken && bht[wr_idx] != 2'b00)
                bht[wr_idx] <= bht[wr_idx] - 2'b01;
        end
    end

    /*
    1. My formal properties live here
    2. All asserts, assumes, and covers are defined here
    3. Use these during SymbiYosys for formal verification
    */

endmodule