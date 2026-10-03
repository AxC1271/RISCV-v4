`timescale 1ns / 1ps

module core_riscv_tb();
    localparam CLK_PERIOD  = 10;
    localparam IMEM_WORDS  = 1024;   // 4 kB instruction ROM
    localparam DMEM_WORDS  = 16384;  // 64 kB data memory
    localparam BASE        = 32'h0000_0000; // reset vector / .text base

    logic clk;
    logic rst_n;
    logic cpu_enable;
    logic [1:0] predictor_sel;

    logic [31:0] imem_addr;
    logic        imem_req;
    logic [31:0] imem_rdata1, imem_rdata2;
    logic        imem_ready;

    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_wstrb;
    logic        dmem_rd_en;
    logic        dmem_wr_en;
    logic [31:0] dmem_rdata;
    logic        dmem_ready;

    logic [31:0] debug_pc;
    logic [31:0] debug_instr;
    logic [31:0] debug_reg_data;
    logic        debug_halted;

    core_riscv_ooo dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_enable(cpu_enable),
        .predictor_sel(predictor_sel),
        .imem_addr(imem_addr),
        .imem_req(imem_req),
        .imem_rdata1(imem_rdata1), .imem_rdata2(imem_rdata2),
        .imem_ready(imem_ready),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb),
        .dmem_rd_en(dmem_rd_en),
        .dmem_wr_en(dmem_wr_en),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .debug_pc(debug_pc),
        .debug_instr(debug_instr),
        .debug_reg_data(debug_reg_data),
        .debug_halted(debug_halted)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // instruction memory
    logic [31:0] imem [0:IMEM_WORDS-1];
    logic [31:0] imem_index, imem_index2;
    assign imem_index = (imem_addr - BASE) >> 2;
    assign imem_index2 = imem_index + 1;

    int prog;
    int MEM_LATENCY;
    int PREDICTOR;
    initial begin
        if (!$value$plusargs("prog=%d", prog)) prog = 1;
        if (!$value$plusargs("lat=%d", MEM_LATENCY)) MEM_LATENCY = 1;
        if (!$value$plusargs("pred=%d", PREDICTOR)) PREDICTOR = 2;
        predictor_sel = PREDICTOR[1:0];
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // NOP

        if (prog == 2) begin
            imem['h000 >> 2] = 32'h00000097; // auipc x1, 0        # x1=BASE
            imem['h004 >> 2] = 32'h01008093; // addi  x1, x1, 16   # EX->EX
            imem['h008 >> 2] = 32'h00008167; // jalr  x2, x1, 0    # fwd rs1; x2=BASE+0xC
            imem['h00C >> 2] = 32'h06300193; // addi  x3, x0, 99   # SQUASHED
            imem['h010 >> 2] = 32'h40000A13; // addi  x20, x0, 1024
            imem['h014 >> 2] = 32'h05A00213; // addi  x4, x0, 90
            imem['h018 >> 2] = 32'h004A2023; // sw    x4, 0(x20)   # store-data EX->EX
            imem['h01C >> 2] = 32'h000A2283; // lw    x5, 0(x20)   # store->load b2b
            imem['h020 >> 2] = 32'h005A2223; // sw    x5, 4(x20)   # load-use -> store data
            imem['h024 >> 2] = 32'h004A2303; // lw    x6, 4(x20)   # store->load b2b
            imem['h028 >> 2] = 32'h00430463; // beq   x6, x4, +8   # branch on loaded value
            imem['h02C >> 2] = 32'h06300393; // addi  x7, x0, 99   # SQUASHED
            imem['h030 >> 2] = 32'h00300413; // addi  x8, x0, 3
            imem['h034 >> 2] = 32'h000A0493; // addi  x9, x20, 0
            imem['h038 >> 2] = 32'h0A000513; // addi  x10, x0, 0xA0
            imem['h03C >> 2] = 32'h00A4A423; // sw    x10, 8(x9)   # LOOP: dirty a line
            imem['h040 >> 2] = 32'h00150513; // addi  x10, x10, 1
            imem['h044 >> 2] = 32'h40048493; // addi  x9, x9, 1024
            imem['h048 >> 2] = 32'h40048493; // addi  x9, x9, 1024 # stride 0x800: same set
            imem['h04C >> 2] = 32'hFFF40413; // addi  x8, x8, -1
            imem['h050 >> 2] = 32'hFE0416E3; // bne   x8, x0, -20  # BACKWARD branch
            imem['h054 >> 2] = 32'h40000713; // addi  x14, x0, 1024
            imem['h058 >> 2] = 32'h00872583; // lw    x11, 8(x14)  # 0x408 after writeback
            imem['h05C >> 2] = 32'h40070713; // addi  x14, x14, 1024
            imem['h060 >> 2] = 32'h40070713; // addi  x14, x14, 1024
            imem['h064 >> 2] = 32'h00872603; // lw    x12, 8(x14)  # 0xC08
            imem['h068 >> 2] = 32'h40070713; // addi  x14, x14, 1024
            imem['h06C >> 2] = 32'h40070713; // addi  x14, x14, 1024
            imem['h070 >> 2] = 32'h00872783; // lw    x15, 8(x14)  # 0x1408
            imem['h074 >> 2] = 32'h00100073; // ebreak
        end else if (prog == 3) begin
            // cache-friendly hot loop: 1 compulsory miss, then all hits
            imem['h000 >> 2] = 32'h00000093; // addi x1,0,0    sum=0
            imem['h004 >> 2] = 32'h03200113; // addi x2,0,50   count=50
            imem['h008 >> 2] = 32'h10000193; // addi x3,0,256  base
            imem['h00C >> 2] = 32'h00700213; // addi x4,0,7     val
            imem['h010 >> 2] = 32'h0041A023; // sw   x4,0(x3)   compulsory miss
            imem['h014 >> 2] = 32'h0001A283; // lw   x5,0(x3)   hot load (hits)
            imem['h018 >> 2] = 32'h005080B3; // add  x1,x1,x5   load-use
            imem['h01C >> 2] = 32'hFFF10113; // addi x2,x2,-1
            imem['h020 >> 2] = 32'hFE011AE3; // bne  x2,0,loop
            imem['h024 >> 2] = 32'h00100073; // ebreak
        end else begin
        imem['h000 >> 2] = 32'h06400093; // addi  x1, x0, 100   # x1  = 100 (base ptr)
        imem['h004 >> 2] = 32'h02A00113; // addi  x2, x0, 42    # x2  = 42
        imem['h008 >> 2] = 32'h002081B3; // add   x3, x1, x2    # x3  = 142  EX->EX fwd
        imem['h00C >> 2] = 32'h0020A023; // sw    x2, 0(x1)     # mem[100] = 42
        imem['h010 >> 2] = 32'h0000A203; // lw    x4, 0(x1)     # x4  = 42
        imem['h014 >> 2] = 32'h004202B3; // add   x5, x4, x4    # x5  = 84   load-use stall
        imem['h018 >> 2] = 32'h12345337; // lui   x6, 0x12345   # x6  = 0x12345000
        imem['h01C >> 2] = 32'h00000397; // auipc x7, 0         # x7  = BASE+0x1C
        imem['h020 >> 2] = 32'h00C0046F; // jal   x8, +12       # x8  = BASE+0x24, jump to 0x2C
        imem['h024 >> 2] = 32'h06300493; // addi  x9, x0, 99    # SQUASHED
        imem['h028 >> 2] = 32'h06200513; // addi  x10, x0, 98   # SQUASHED
        imem['h02C >> 2] = 32'h00100593; // addi  x11, x0, 1    # x11 = 1
        imem['h030 >> 2] = 32'h00000617; // auipc x12, 0        # x12 = BASE+0x30
        imem['h034 >> 2] = 32'h040606E7; // jalr  x13, x12, 0x40 # x13 = BASE+0x38, jump to BASE+0x70
        imem['h038 >> 2] = 32'h06100713; // addi  x14, x0, 97   # SQUASHED
        imem['h03C >> 2] = 32'h06000793; // addi  x15, x0, 96   # SQUASHED
        imem['h070 >> 2] = 32'h00500713; // addi  x14, x0, 5    # x14 = 5
        imem['h074 >> 2] = 32'h00E70663; // beq   x14, x14, +12 # taken, jump to 0x80
        imem['h078 >> 2] = 32'h05F00793; // addi  x15, x0, 95   # SQUASHED
        imem['h07C >> 2] = 32'h05E00813; // addi  x16, x0, 94   # SQUASHED
        imem['h080 >> 2] = 32'h00E71463; // bne   x14, x14, +8  # not taken
        imem['h084 >> 2] = 32'h00700813; // addi  x16, x0, 7    # x16 = 7
        imem['h088 >> 2] = 32'hFFF00893; // addi  x17, x0, -1   # x17 = 0xFFFFFFFF
        imem['h08C >> 2] = 32'h01108223; // sb    x17, 4(x1)    # mem[104].b0 = FF
        imem['h090 >> 2] = 32'h00E082A3; // sb    x14, 5(x1)    # mem[104].b1 = 05 -> 0x000005FF
        imem['h094 >> 2] = 32'h0040C903; // lbu   x18, 4(x1)    # x18 = 0x000000FF
        imem['h098 >> 2] = 32'h00408983; // lb    x19, 4(x1)    # x19 = 0xFFFFFFFF
        imem['h09C >> 2] = 32'h00409A03; // lh    x20, 4(x1)    # x20 = 0x000005FF
        imem['h0A0 >> 2] = 32'h01109323; // sh    x17, 6(x1)    # mem[104] = 0xFFFF05FF
        imem['h0A4 >> 2] = 32'h0040AA83; // lw    x21, 4(x1)    # x21 = 0xFFFF05FF
        imem['h0A8 >> 2] = 32'h0060DB03; // lhu   x22, 6(x1)    # x22 = 0x0000FFFF
        imem['h0AC >> 2] = 32'h4048DB93; // srai  x23, x17, 4   # x23 = 0xFFFFFFFF
        imem['h0B0 >> 2] = 32'h01103C33; // sltu  x24, x0, x17  # x24 = 1
        imem['h0B4 >> 2] = 32'h0008ACB3; // slt   x25, x17, x0  # x25 = 1
        imem['h0B8 >> 2] = 32'h00100D13; // addi  x26, x0, 1    # x26 = 1
        imem['h0BC >> 2] = 32'h00BD1D13; // slli  x26, x26, 11  # x26 = 0x800
        imem['h0C0 >> 2] = 32'h01A08E33; // add   x28, x1, x26  # x28 = 0x864
        imem['h0C4 >> 2] = 32'h01AE0EB3; // add   x29, x28, x26 # x29 = 0x1064
        imem['h0C8 >> 2] = 32'h002E2023; // sw    x2, 0(x28)    # mem[0x864] = 42
        imem['h0CC >> 2] = 32'h003EA023; // sw    x3, 0(x29)    # mem[0x1064] = 142, evict dirty 0x060
        imem['h0D0 >> 2] = 32'h0000AF03; // lw    x30, 0(x1)    # x30 = 42 (refill after writeback)
        imem['h0D4 >> 2] = 32'h000EAF83; // lw    x31, 0(x29)   # x31 = 142
        imem['h0D8 >> 2] = 32'h00100073; // ebreak              # halt
        end
    end

    assign imem_rdata1 = (imem_index < IMEM_WORDS) ? imem[imem_index[$clog2(IMEM_WORDS)-1:0]] : 32'h00000013;
    assign imem_rdata2 = (imem_index2 < IMEM_WORDS) ? imem[imem_index2[$clog2(IMEM_WORDS)-1:0]] : 32'h00000013;

    int imem_cnt = 0;
    assign imem_ready = imem_req && (imem_cnt == MEM_LATENCY-1);
    always_ff @(posedge clk) begin
        if (!imem_req)         imem_cnt <= 0;
        else if (imem_ready)   imem_cnt <= 0;
        else                   imem_cnt <= imem_cnt + 1;
    end

    // data memory
    logic [31:0] dmem [0:DMEM_WORDS-1];

    initial begin
        for (int i = 0; i < DMEM_WORDS; i++)
            dmem[i] = 32'h0;
    end

    assign dmem_rdata = dmem[dmem_addr[$clog2(DMEM_WORDS)+1:2]];

    int dmem_cnt = 0;
    logic [31:0] dmem_idx;
    assign dmem_idx   = dmem_addr[$clog2(DMEM_WORDS)+1:2];
    assign dmem_ready = (dmem_rd_en || dmem_wr_en) && (dmem_cnt == MEM_LATENCY-1);
    always_ff @(posedge clk) begin
        if (!(dmem_rd_en || dmem_wr_en)) dmem_cnt <= 0;
        else if (dmem_ready)             dmem_cnt <= 0;
        else                             dmem_cnt <= dmem_cnt + 1;
        // byte-lane write on the ready cycle (core drives wstrb; there is no
        // cache to place lanes any more)
        if (dmem_wr_en && dmem_ready) begin
            if (dmem_wstrb[0]) dmem[dmem_idx][7:0]   <= dmem_wdata[7:0];
            if (dmem_wstrb[1]) dmem[dmem_idx][15:8]  <= dmem_wdata[15:8];
            if (dmem_wstrb[2]) dmem[dmem_idx][23:16] <= dmem_wdata[23:16];
            if (dmem_wstrb[3]) dmem[dmem_idx][31:24] <= dmem_wdata[31:24];
        end
    end

    function automatic [31:0] read_reg(input int unsigned n);
        read_reg = dut.registers.registers[n];
    endfunction

    int pass_count;
    int fail_count;

    // IPC instrumentation
    longint cycle_count, retire_count;
    longint branch_count, mispredict_count;
    logic halted_seen;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cycle_count      <= 0;
            retire_count     <= 0;
            branch_count     <= 0;
            mispredict_count <= 0;
            halted_seen      <= 1'b0;
        end else if (cpu_enable && !halted_seen) begin
            cycle_count <= cycle_count + 1;
            retire_count <= retire_count
                          + ((dut.wb1_valid && !dut.wb1_ebreak) ? 1 : 0)
                          + ((dut.wb2_valid && !dut.wb2_ebreak) ? 1 : 0);

            if (dut.branch_update_valid)
                branch_count <= branch_count + 1;

            if (dut.mispredict)
                mispredict_count <= mispredict_count + 1;

            if (debug_halted)
                halted_seen <= 1'b1;
        end
    end

    task automatic check_reg (
        input int unsigned reg_num,
        input logic [31:0] expected,
        input string       label
    );
        logic [31:0] got;
        got = read_reg(reg_num);
        if (got === expected) begin
            $display("  PASS  %-22s x%-2d                   = 0x%08h", label, reg_num, got);
            pass_count++;
        end else begin
            $display("  FAIL  %-22s x%-2d  expected=0x%08h  got=0x%08h", label, reg_num, expected, got);
            fail_count++;
        end
    endtask


    task automatic check_dmem (
        input logic [31:0] byte_addr,
        input logic [31:0] expected,
        input string       label
    );
        logic [31:0] got;
        got = dmem[byte_addr[$clog2(DMEM_WORDS)+1:2]];
        if (got === expected) begin
            $display("  PASS  %-22s dmem[0x%08h] = 0x%08h", label, byte_addr, got);
            pass_count++;
        end else begin
            $display("  FAIL  %-22s dmem[0x%08h]  expected=0x%08h  got=0x%08h",
                     label, byte_addr, expected, got);
            fail_count++;
        end
    endtask

    // main stimulus
    initial begin
        rst_n      = 1'b0;
        cpu_enable = 1'b0;
        pass_count = 0;
        fail_count = 0;

        #1;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        cpu_enable = 1'b1;

        $display("\n[TB] CPU running...");
        fork
            begin : wait_halt
                wait (halted_seen);
                $display("[TB] EBREAK retired, core halted at T=%0t", $time);
            end
            begin : hard_cap
                repeat (60000) @(posedge clk);
            end
        join_any
        disable fork;
        repeat (4) @(posedge clk);

        if (!halted_seen)
            $display("[TB] WARNING: core never halted -- checking state anyway");

        if (prog == 2) begin
            check_reg( 2, BASE + 32'h0C, "fwd-jalr link x2");
            check_reg( 3, 32'd0,         "x3 squashed");
            check_reg( 4, 32'd90,        "addi x4=90");
            check_reg( 5, 32'd90,        "st->ld b2b x5");
            check_reg( 6, 32'd90,        "ld-use st-data x6");
            check_reg( 7, 32'd0,         "x7 squashed");
            check_reg( 8, 32'd0,         "loop exit x8=0");
            check_reg( 9, 32'h1C00,      "stride ptr x9");
            check_reg(10, 32'hA3,        "loop val x10");
            check_reg(11, 32'hA0,        "wb+refill x11");
            check_reg(12, 32'hA1,        "thrash rd x12");
            check_reg(15, 32'hA2,        "thrash rd x15");
            // evicted dirty lines must have landed in backing memory
            check_dmem(32'h00000408, 32'hA0, "writeback 0x408");
            check_dmem(32'h00000C08, 32'hA1, "writeback 0xC08");
            check_dmem(32'h00001408, 32'hA2, "writeback 0x1408");
        end else if (prog == 3) begin
            check_reg(1, 32'd350, "hot-loop sum x1=350");
        end else begin
        // arithmetic + forwarding + load-use
        check_reg( 1, 32'd100,        "addi x1=100");
        check_reg( 2, 32'd42,         "addi x2=42");
        check_reg( 3, 32'd142,        "add fwd x3=142");
        check_reg( 4, 32'd42,         "lw x4=42");
        check_reg( 5, 32'd84,         "load-use x5=84");

        // U-type
        check_reg( 6, 32'h12345000,   "lui x6");
        check_reg( 7, BASE + 32'h1C,  "auipc x7");

        // JAL
        check_reg( 8, BASE + 32'h24,  "jal link x8");
        check_reg( 9, 32'd0,          "x9 squashed");
        check_reg(10, 32'd0,          "x10 squashed");
        check_reg(11, 32'd1,          "post-jal x11=1");

        // JALR
        check_reg(12, BASE + 32'h30,  "auipc x12");
        check_reg(13, BASE + 32'h38,  "jalr link x13");
        check_reg(14, 32'd5,          "jalr target x14=5");
        check_reg(15, 32'd0,          "x15 squashed");

        // branches
        check_reg(16, 32'd7,          "bne not-taken x16=7");

        // sub-word memory
        check_reg(17, 32'hFFFFFFFF,   "addi x17=-1");
        check_reg(18, 32'h000000FF,   "lbu x18");
        check_reg(19, 32'hFFFFFFFF,   "lb x19");
        check_reg(20, 32'h000005FF,   "lh x20");
        check_reg(21, 32'hFFFF05FF,   "lw x21");
        check_reg(22, 32'h0000FFFF,   "lhu x22");

        // shifts / compares
        check_reg(23, 32'hFFFFFFFF,   "srai x23");
        check_reg(24, 32'd1,          "sltu x24");
        check_reg(25, 32'd1,          "slt x25");

        // memory state
        check_dmem  (32'h00000064, 32'd42,        "sw -> mem[100]");
        check_dmem  (32'h00000068, 32'hFFFF05FF,  "sb/sh -> mem[104]");

        // eviction / writeback path
        check_reg(30, 32'd42,         "evicted rd-back x30");
        check_reg(31, 32'd142,        "lw x31=142");
        check_dmem(32'h00000064, 32'd42,          "writeback mem[0x064]");
        check_dmem(32'h00000068, 32'hFFFF05FF,    "writeback mem[0x068]");
        check_dmem(32'h00000864, 32'd42,          "writeback mem[0x864]");
        end

        $display("\n========== IPC ==========");
        $display("prog=%0d  mem_latency=%0d  cycles=%0d  retired=%0d  IPC=%0.4f",
                 prog, MEM_LATENCY, cycle_count, retire_count,
                 real'(retire_count) / real'(cycle_count));
        $display("predictor=%0d  branches=%0d  mispredicts=%0d  accuracy=%0.2f%%",
                 PREDICTOR, branch_count, mispredict_count,
                 branch_count ? 100.0 * real'(branch_count - mispredict_count) / real'(branch_count) : 0.0);

        $display("\n========== SUMMARY ==========");
        $display("PASS: %0d   FAIL: %0d   TOTAL: %0d", pass_count, fail_count, pass_count + fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED -- check pipeline/forwarding/memory");
        $finish;
    end

    // timeout watchdog
    initial begin
        #5000000;
        $display("[TIMEOUT] Simulation exceeded 5ms -- possible hang");
        $fatal;
    end

    // pipeline monitor (run with +verbose to enable)
    initial begin
        if ($test$plusargs("verbose")) begin
            @(posedge rst_n);
            forever begin
                @(posedge clk);
                $display("[T=%0t] PC=%08h | ID1=%08h v=%b ID2=%08h v=%b | EX1=%08h v=%b EX2=%08h v=%b | WB1 v=%b WB2 v=%b | issue=%b%b stall=%b mem_stall=%b flush=%b",
                    $time,
                    dut.pc_curr,
                    dut.id1_instr, dut.id1_valid,
                    dut.id2_instr, dut.id2_valid,
                    dut.ex1_instr, dut.ex1_valid,
                    dut.ex2_instr, dut.ex2_valid,
                    dut.wb1_valid, dut.wb2_valid,
                    dut.issue_0, dut.issue_1,
                    dut.stall_pipeline, dut.mem_stall, dut.flush
                );
            end
        end
    end

endmodule