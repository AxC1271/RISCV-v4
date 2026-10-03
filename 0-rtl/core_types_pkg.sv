package core_types_pkg;
    
    parameter int XLEN = 32;

    parameter int ARCH_REGS = 32;
    parameter int PHYS_REGS = 64;

    parameter int FETCH_WIDTH  = 2;
    parameter int DECODE_WIDTH = 2;
    parameter int RENAME_WIDTH = 2;
    parameter int ISSUE_WIDTH  = 2;
    parameter int COMMIT_WIDTH = 2;

    parameter int ROB_ENTRIES = 32;
    parameter int IQ_ENTRIES  = 16;
    parameter int LSQ_ENTRIES = 16;

    parameter int NUM_BRANCH_CHECKPOINTS = 8;

    localparam int ARCH_TAG_W =
        (ARCH_REGS > 1) ? $clog2(ARCH_REGS) : 1;

    localparam int PHYS_TAG_W =
        (PHYS_REGS > 1) ? $clog2(PHYS_REGS) : 1;

    localparam int ROB_TAG_W =
        (ROB_ENTRIES > 1) ? $clog2(ROB_ENTRIES) : 1;

    localparam int IQ_TAG_W =
        (IQ_ENTRIES > 1) ? $clog2(IQ_ENTRIES) : 1;

    localparam int LSQ_TAG_W =
        (LSQ_ENTRIES > 1) ? $clog2(LSQ_ENTRIES) : 1;

    localparam int BRANCH_CKPT_W =
        (NUM_BRANCH_CHECKPOINTS > 1)
            ? $clog2(NUM_BRANCH_CHECKPOINTS)
            : 1;

    typedef logic [XLEN-1:0] data_t;
    typedef logic [XLEN-1:0] addr_t;

    typedef logic [ARCH_TAG_W-1:0] arch_tag_t;
    typedef logic [PHYS_TAG_W-1:0] phys_tag_t;
    typedef logic [ROB_TAG_W-1:0]  rob_tag_t;
    typedef logic [IQ_TAG_W-1:0]   iq_tag_t;
    typedef logic [LSQ_TAG_W-1:0]  lsq_tag_t;

    typedef logic [BRANCH_CKPT_W-1:0] branch_ckpt_t;

    typedef enum logic [2:0] {
        FU_ALU,
        FU_BRANCH,
        FU_MULDIV,
        FU_LOAD,
        FU_STORE
    } fu_type_t;

    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_AND  = 4'b0010,
        ALU_OR   = 4'b0011,
        ALU_XOR  = 4'b0100,
        ALU_SLL  = 4'b0101,
        ALU_SRL  = 4'b0110,
        ALU_SRA  = 4'b0111,
        ALU_SLT  = 4'b1000,
        ALU_SLTU = 4'b1001
    } alu_op_t;

    typedef enum logic [2:0] {
        MULDIV_MUL,
        MULDIV_MULH,
        MULDIV_MULHSU,
        MULDIV_MULHU,
        MULDIV_DIV,
        MULDIV_DIVU,
        MULDIV_REM,
        MULDIV_REMU
    } muldiv_op_t;

    typedef enum logic [2:0] {
        BR_BEQ,
        BR_BNE,
        BR_BLT,
        BR_BGE,
        BR_BLTU,
        BR_BGEU,
        BR_JAL,
        BR_JALR
    } branch_op_t;

    typedef enum logic [3:0] {
        MEM_LB,
        MEM_LH,
        MEM_LW,
        MEM_LBU,
        MEM_LHU,
        MEM_SB,
        MEM_SH,
        MEM_SW
    } mem_op_t;

    typedef struct packed {
        logic       valid;
        addr_t      pc;
        logic [31:0] instruction;
        arch_tag_t  rs1;
        arch_tag_t  rs2;
        arch_tag_t  rd;
        logic       uses_rs1;
        logic       uses_rs2;
        logic       writes_rd;
        data_t      immediate;
        fu_type_t   fu_type;
        alu_op_t    alu_op;
        muldiv_op_t muldiv_op;
        branch_op_t branch_op;
        mem_op_t    mem_op;
        logic       is_branch;
        logic       is_load;
        logic       is_store;
        logic       predicted_taken;
        addr_t      predicted_target;

    } decoded_uop_t;

    typedef struct packed {
        logic       valid;
        addr_t      pc;
        logic [31:0] instruction;
        phys_tag_t  prs1;
        phys_tag_t  prs2;
        phys_tag_t  pdst;
        phys_tag_t  old_pdst;
        arch_tag_t  arch_rd;
        logic       uses_rs1;
        logic       uses_rs2;
        logic       writes_rd;
        data_t      immediate;
        fu_type_t   fu_type;
        alu_op_t    alu_op;
        muldiv_op_t muldiv_op;
        branch_op_t branch_op;
        mem_op_t    mem_op;
        rob_tag_t   rob_tag;
        logic       is_branch;
        logic       is_load;
        logic       is_store;
        logic       predicted_taken;
        addr_t      predicted_target;
        logic         has_checkpoint;
        branch_ckpt_t checkpoint_id;

    } renamed_uop_t;

    typedef struct packed {
        logic       valid;
        rob_tag_t   rob_tag;
        fu_type_t   fu_type;
        alu_op_t    alu_op;
        muldiv_op_t muldiv_op;
        branch_op_t branch_op;
        mem_op_t    mem_op;
        phys_tag_t  prs1;
        phys_tag_t  prs2;
        phys_tag_t  pdst;
        logic       uses_rs1;
        logic       uses_rs2;
        logic       src1_ready;
        logic       src2_ready;
        data_t      immediate;
        addr_t      pc;
        logic       is_branch;
        logic       is_load;
        logic       is_store;
    } iq_entry_t;

    typedef struct packed {
        logic       valid;
        rob_tag_t   rob_tag;
        fu_type_t   fu_type;
        alu_op_t    alu_op;
        muldiv_op_t muldiv_op;
        branch_op_t branch_op;
        mem_op_t    mem_op;
        phys_tag_t  pdst;
        data_t      src1_value;
        data_t      src2_value;
        data_t      immediate;
        addr_t      pc;
        logic       writes_rd;
        logic       is_branch;
        logic       is_load;
        logic       is_store;
    } issued_uop_t;

    typedef struct packed {
        logic       valid;
        rob_tag_t   rob_tag;
        logic       writes_reg;
        phys_tag_t  pdst;
        data_t      value;
        logic       exception;
        logic [3:0] exception_code;
    } writeback_t;

    typedef struct packed {
        logic       valid;
        rob_tag_t   rob_tag;
        logic       taken;
        addr_t      target;
        logic       mispredict;
        logic         has_checkpoint;
        branch_ckpt_t checkpoint_id;
    } branch_result_t;

    typedef struct packed {
        logic       valid;
        logic       complete;
        addr_t      pc;
        arch_tag_t  arch_rd;
        phys_tag_t  pdst;
        phys_tag_t  old_pdst;
        logic       writes_rd;
        logic       is_branch;
        logic       is_load;
        logic       is_store;
        logic       predicted_taken;
        addr_t      predicted_target;
        logic         has_checkpoint;
        branch_ckpt_t checkpoint_id;
        logic       exception;
        logic [3:0] exception_code;

    } rob_entry_t;

    typedef struct packed {
        logic       valid;
        rob_tag_t   rob_tag;
        logic       is_load;
        logic       is_store;
        mem_op_t    mem_op;
        logic       address_valid;
        addr_t      address;
        logic       data_valid;
        data_t      store_data;
        phys_tag_t  pdst;
        logic       complete;
    } lsq_entry_t;
endpackage