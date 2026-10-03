`timescale 1ns/1ps

module tb_ipc;

    localparam logic [31:0] BASE = 32'h0000_0000;
    localparam int IMEM_WORDS = 256;
    localparam int NUM_ALU_INSTR = 120;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic cpu_enable = 1'b0;
    logic [1:0] predictor_sel = 2'b00;

    logic [31:0] imem_addr;
    logic        imem_req;
    logic [31:0] imem_rdata1, imem_rdata2;
    logic        imem_ready;

    logic [31:0] dmem_addr;
    logic        dmem_rd_en, dmem_wr_en;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_wstrb;
    logic [31:0] dmem_rdata;
    logic        dmem_ready;

    logic        debug_halted;

    logic [31:0] imem [0:IMEM_WORDS-1];
    integer imem_index;
    integer imem_index2;

    integer cycles;
    integer retired;
    integer dual_issue_cycles;
    integer single_issue_cycles;
    integer no_issue_cycles;
    integer dual_retire_cycles;
    integer stall_cycles;
    integer replay_cycles;
    integer flush_cycles;
    integer i, r;
    integer timeout;

    logic halted_seen;

    core_riscv_ooo dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_enable(cpu_enable),
        .predictor_sel(predictor_sel),

        .imem_addr(imem_addr),
        .imem_req(imem_req),
        .imem_rdata1(imem_rdata1),
        .imem_rdata2(imem_rdata2),
        .imem_ready(imem_ready),

        .dmem_addr(dmem_addr),
        .dmem_rd_en(dmem_rd_en),
        .dmem_wr_en(dmem_wr_en),
        .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),

        .debug_halted(debug_halted)
    );

    always #5 clk = ~clk;

    // Zero-latency instruction memory for a pure front-end/issue throughput test.
    always_comb begin
        imem_index  = (imem_addr - BASE) >> 2;
        imem_index2 = imem_index + 1;

        imem_rdata1 = 32'h00000013; // NOP
        imem_rdata2 = 32'h00000013; // NOP

        if (imem_index >= 0 && imem_index < IMEM_WORDS)
            imem_rdata1 = imem[imem_index];

        if (imem_index2 >= 0 && imem_index2 < IMEM_WORDS)
            imem_rdata2 = imem[imem_index2];
    end

    assign imem_ready = imem_req;

    // This benchmark intentionally performs no data-memory operations.
    assign dmem_rdata = 32'b0;
    assign dmem_ready = 1'b1;

    // Encode: addi rd, x0, imm
    function automatic [31:0] enc_addi(
        input logic [4:0] rd,
        input integer imm
    );
        logic [11:0] imm12;
        begin
            imm12 = imm[11:0];
            enc_addi = {imm12, 5'd0, 3'b000, rd, 7'b0010011};
        end
    endfunction

    function automatic [31:0] read_reg(input int unsigned n);
        read_reg = dut.registers.registers[n];
    endfunction

    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1)
            imem[i] = 32'h00000013;

        /*
         * 120 independent ALU instructions.
         *
         * Destinations rotate x1..x30.  A register is not reused until
         * 30 instructions later, so there are no nearby RAW or WAW hazards.
         * Every instruction reads only x0.
         *
         * Adjacent instructions should therefore be dual-issuable.
         */
        for (i = 0; i < NUM_ALU_INSTR; i = i + 1) begin
            r = (i % 30) + 1;
            imem[i] = enc_addi(r[4:0], i + 1);
        end

        // Stop after the throughput stream.
        imem[NUM_ALU_INSTR] = 32'h00100073; // EBREAK

        cycles              = 0;
        retired             = 0;
        dual_issue_cycles   = 0;
        single_issue_cycles = 0;
        no_issue_cycles     = 0;
        dual_retire_cycles  = 0;
        stall_cycles        = 0;
        replay_cycles       = 0;
        flush_cycles        = 0;
        halted_seen         = 1'b0;

        repeat (5) @(posedge clk);
        rst_n <= 1'b1;

        repeat (2) @(posedge clk);
        cpu_enable <= 1'b1;

        $display("[TB] Independent ALU throughput benchmark started");
        $display("[TB] Instructions under test: %0d", NUM_ALU_INSTR);
    end

    always @(posedge clk) begin
        if (rst_n && cpu_enable && !halted_seen) begin
            cycles <= cycles + 1;

            retired <= retired
                + ((dut.wb1_valid && !dut.wb1_ebreak) ? 1 : 0)
                + ((dut.wb2_valid && !dut.wb2_ebreak) ? 1 : 0);

            if (dut.id1_valid && dut.id2_valid &&
                dut.issue_0 && dut.issue_1 && !dut.stall_pipeline)
                dual_issue_cycles <= dual_issue_cycles + 1;
            else if ((dut.issue_0 || dut.issue_1) && !dut.stall_pipeline)
                single_issue_cycles <= single_issue_cycles + 1;
            else
                no_issue_cycles <= no_issue_cycles + 1;

            if (dut.wb1_valid && !dut.wb1_ebreak &&
                dut.wb2_valid && !dut.wb2_ebreak)
                dual_retire_cycles <= dual_retire_cycles + 1;

            if (dut.stall_pipeline)
                stall_cycles <= stall_cycles + 1;

            if (dut.replay_second)
                replay_cycles <= replay_cycles + 1;

            if (dut.flush)
                flush_cycles <= flush_cycles + 1;

            if (debug_halted)
                halted_seen <= 1'b1;
        end
    end

    initial begin
        timeout = 0;
        wait(rst_n && cpu_enable);

        while (!halted_seen && timeout < 1000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        // Allow nonblocking counters from the halt cycle to settle.
        @(negedge clk);

        if (!halted_seen) begin
            $display("FAIL: timeout waiting for EBREAK");
            $finish;
        end

        $display("");
        $display("========== THROUGHPUT RESULTS ==========");
        $display("cycles              = %0d", cycles);
        $display("retired ALU instr   = %0d", retired);
        $display("IPC                 = %0f",
                 (cycles != 0) ? (1.0 * retired / cycles) : 0.0);
        $display("dual issue cycles   = %0d", dual_issue_cycles);
        $display("single issue cycles = %0d", single_issue_cycles);
        $display("no issue cycles     = %0d", no_issue_cycles);
        $display("dual retire cycles  = %0d", dual_retire_cycles);
        $display("stall cycles        = %0d", stall_cycles);
        $display("replay cycles       = %0d", replay_cycles);
        $display("flush cycles        = %0d", flush_cycles);
        $display("========================================");

        // 120 instructions / 30 registers = 4 writes per register.
        // Last write to x1 is instruction 91, x2 is 92, ... x30 is 120.
        for (r = 1; r <= 30; r = r + 1) begin
            if (read_reg(r) !== (90 + r)) begin
                $display("FAIL: x%0d = 0x%08h, expected %0d",
                         r, read_reg(r), 90 + r);
                $finish;
            end
        end

        if (retired != NUM_ALU_INSTR) begin
            $display("FAIL: retired=%0d, expected=%0d",
                     retired, NUM_ALU_INSTR);
            $finish;
        end

        if (stall_cycles != 0) begin
            $display("WARNING: %0d pipeline stall cycles occurred in an independent ALU stream.",
                     stall_cycles);
        end

        if ((1.0 * retired / cycles) > 1.5)
            $display("PASS: superscalar throughput is clearly above 1 IPC.");
        else
            $display("WARNING: IPC did not exceed 1.5; inspect issue/replay/front-end behavior.");

        $finish;
    end

endmodule
