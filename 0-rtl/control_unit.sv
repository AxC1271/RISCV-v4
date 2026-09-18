module control_unit (
    input  logic[31:0] instruction,

    output logic[3:0] alu_opcode,
    output logic[1:0] op_a_sel,   // 00 = rs1, 01 = pc, 10 = zero
    output logic      alusrc,     // 0 = rs2, 1 = imm
    output logic      regwrite,
    output logic      memread,
    output logic      memwrite,
    output logic      branch,
    output logic      memtoreg,
    output logic      jump,       
    output logic      jalr,       
    output logic      uses_rs1,   
    output logic      uses_rs2,
    output logic      ebreak
);

    /*
    1. All of my RTL logic lives here
    2. All combinational/registered logic are defined here
    3. Use these during testbenches/simulations 
    */

    localparam OP_R_TYPE  = 7'b0110011;
    localparam OP_I_ARITH = 7'b0010011;
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_JALR    = 7'b1100111;
    localparam OP_LUI     = 7'b0110111;
    localparam OP_AUIPC   = 7'b0010111;
    localparam OP_FENCE   = 7'b0001111;
    localparam OP_SYSTEM  = 7'b1110011;

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    localparam OPA_RS1  = 2'b00;
    localparam OPA_PC   = 2'b01;
    localparam OPA_ZERO = 2'b10;

    always_comb begin
        // default values
        alu_opcode = ALU_ADD;
        op_a_sel   = OPA_RS1;
        alusrc     = 1'b0;
        regwrite   = 1'b0;
        memread    = 1'b0;
        memwrite   = 1'b0;
        memtoreg   = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        uses_rs1   = 1'b0;
        uses_rs2   = 1'b0;
        ebreak     = 1'b0;

        case (instruction[6:0]) // opcode check
            OP_R_TYPE: begin
                regwrite = 1'b1;
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;

                case (instruction[14:12]) // check funct3
                    3'b000: alu_opcode  = instruction[30] ? ALU_SUB : ALU_ADD;
                    3'b001: alu_opcode  = ALU_SLL;
                    3'b010: alu_opcode  = ALU_SLT;
                    3'b011: alu_opcode  = ALU_SLTU;
                    3'b100: alu_opcode  = ALU_XOR;
                    3'b101: alu_opcode  = instruction[30] ? ALU_SRA : ALU_SRL;
                    3'b110: alu_opcode  = ALU_OR;
                    3'b111: alu_opcode  = ALU_AND;
                    default: alu_opcode = ALU_ADD;
                endcase
            end

            OP_I_ARITH: begin
                regwrite = 1'b1;
                alusrc   = 1'b1;
                uses_rs1 = 1'b1;

                case (instruction[14:12])
                    3'b000: alu_opcode  = ALU_ADD;
                    3'b001: alu_opcode  = ALU_SLL;
                    3'b010: alu_opcode  = ALU_SLT;
                    3'b011: alu_opcode  = ALU_SLTU;
                    3'b100: alu_opcode  = ALU_XOR;
                    3'b101: alu_opcode  = instruction[30] ? ALU_SRA : ALU_SRL;
                    3'b110: alu_opcode  = ALU_OR;
                    3'b111: alu_opcode  = ALU_AND;
                    default: alu_opcode = ALU_ADD;
                endcase
            end

            OP_LOAD: begin
                alusrc   = 1'b1;
                regwrite = 1'b1;
                memread  = 1'b1;
                memtoreg = 1'b1;
                uses_rs1 = 1'b1;
            end

            OP_STORE: begin
                alusrc   = 1'b1;
                memwrite = 1'b1;
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
            end

            OP_BRANCH: begin
                branch   = 1'b1;
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
            end

            OP_JAL: begin
                regwrite = 1'b1;
                jump     = 1'b1;
            end

            OP_JALR: begin
                regwrite = 1'b1;
                jump     = 1'b1;
                jalr     = 1'b1;
                alusrc   = 1'b1;
                uses_rs1 = 1'b1;
            end

            OP_LUI: begin
                regwrite = 1'b1;
                alusrc   = 1'b1;
                op_a_sel = OPA_ZERO;
            end

            OP_AUIPC: begin
                regwrite = 1'b1;
                alusrc   = 1'b1;
                op_a_sel = OPA_PC;
            end

            OP_FENCE: begin
                // single hart, no reordering between this core and memory: NOP
            end

            OP_SYSTEM: begin
                // no CSRs / trap handling in base rv32i, for my implementation
                // it's functionally equivalent to a nop instruction
                if (instruction[31:20] == 12'h001) begin
                    ebreak = 1'b1;
                end
            end

            default: begin
                // undecoded = NOP (all controls deasserted)
            end
        endcase
    end

    /*
    1. My formal properties live here
    2. All asserts, assumes, and covers are defined here
    3. Use these during SymbiYosys for formal verification
    */
    
endmodule