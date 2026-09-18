module alu
    import core_types_pkg::*;
(
    input  data_t   a,
    input  data_t   b,
    input  alu_op_t alu_opcode,
    output data_t   result
);

    /*
    1. All of my RTL logic lives here
    2. All combinational/registered logic are defined here
    3. Use these during testbenches/simulations 
    */

    always_comb begin
        case (alu_opcode)

            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;

            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];

            ALU_SLT:
                result = ($signed(a) < $signed(b))
                       ? 32'd1 : 32'd0;

            ALU_SLTU:
                result = (a < b)
                       ? 32'd1 : 32'd0;

            default:
                result = '0;

        endcase
    end

    /*
    1. My formal properties live here
    2. All asserts, assumes, and covers are defined here
    3. Use these during SymbiYosys for formal verification
    */

endmodule