module immediate_generator (
    input  logic[31:0] instr,
    output logic[31:0] imm
);

    /*
    1. All of my RTL logic lives here
    2. All combinational/registered logic are defined here
    3. Use these during testbenches/simulations 
    */

    localparam OPCODE_R      = 7'b0110011;
    localparam OPCODE_I_LOAD = 7'b0000011;
    localparam OPCODE_I_REG  = 7'b0010011;
    localparam OPCODE_S      = 7'b0100011;
    localparam OPCODE_B      = 7'b1100011;
    localparam OPCODE_LUI    = 7'b0110111;
    localparam OPCODE_AUIPC  = 7'b0010111;
    localparam OPCODE_J      = 7'b1101111;
    localparam OPCODE_JALR   = 7'b1100111;

    always_comb begin
        case (instr[6:0])
            OPCODE_R: begin
                imm = 32'b0;
            end

            OPCODE_I_LOAD: begin
                imm = {{20{instr[31]}}, instr[31:20]};
            end

            OPCODE_I_REG: begin
                imm = {{20{instr[31]}}, instr[31:20]};
            end

            OPCODE_S: begin
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end

            OPCODE_B: begin
                imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            end

            OPCODE_LUI: begin
                imm = {instr[31:12], 12'b0};
            end

            OPCODE_AUIPC: begin
                imm = {instr[31:12], 12'b0};
            end

            OPCODE_J: begin
                imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            end

            OPCODE_JALR: begin
                imm = {{20{instr[31]}}, instr[31:20]};
            end

            default: imm = 32'b0;
        endcase
    end

    /*
    1. My formal properties live here
    2. All asserts, assumes, and covers are defined here
    3. Use these during SymbiYosys for formal verification
    */
    
endmodule