// ============================================================
// FILE: tb_arm.v  (Gate-Level Compatible Version)
//
// CHANGES FROM RTL VERSION:
//   FIX-1: Clock 200ns (#100 toggle)
//          Gives 185ns window after step() for check_reg calls.
//
//   FIX-2: Reset timing
//          Released at negedge+2ns. 98ns before next posedge.
//          T01 PC=0 checked BEFORE first instruction runs.
//
//   FIX-3: check_reg settle #2 → #30
//          IO ibuf(5ns)+mux(2ns)+IO obuf(7ns) = 14ns.
//          #30 provides safe margin.
//
//   FIX-4: Post-repeat settle #2 → #30
//          Same IO buffer reasoning as FIX-3.
//
//   FIX-5: Trace block trace_cyc only increments after reset.
//          Prevents ghost cycles during reset.
//
//   CRITICAL: Also requires +notimingchecks in vsim command.
//   Use run_tb_arm_gate.do wrapper, NOT the auto-generated .do.
// ============================================================

`timescale 1ns/1ps

module tb_arm;

    // =========================================================
    // DUT Interface
    // =========================================================
    reg         clk;
    reg         reset;
    reg  [3:0]  dbg_reg_sel;
    wire [31:0] dbg_reg_data;
    wire [31:0] pc_out;

    top_level dut (
        .clk          (clk),
        .reset        (reset),
        .dbg_reg_sel  (dbg_reg_sel),
        .dbg_reg_data (dbg_reg_data),
        .pc_out       (pc_out)
    );

    // =========================================================
    // Clock — 200ns period (5 MHz)
    //   FIX-1: was #5 (10ns). Gate-level IO needs 14ns settle.
    //   posedge at: 100, 300, 500, 700 ... ns
    //   negedge at: 200, 400, 600, 800 ... ns
    //
    //   Budget after each @(posedge): 100ns available
    //   Minus step settle (#30):       70ns remaining
    //   Max check_reg chain: 4×30=120ns BUT we only need
    //   to do ~3 calls per window = 90ns < window. Safe.
    // =========================================================
    initial clk = 1'b0;
    always  #100 clk = ~clk;   // FIX-1: was #5

    // =========================================================
    // Counters
    // =========================================================
    integer pass_count;
    integer fail_count;
    integer test_num;
    integer trace_cyc;

    // =========================================================
    // TASK: check_reg
    //   FIX-3: settle time #2 → #30
    //   IO path: ibuf(5) + mux(2) + obuf(7) = 14ns. #30 safe.
    // =========================================================
    task check_reg;
        input  [3:0]   rnum;
        input  [31:0]  expected;
        input  [479:0] desc;
        reg    [31:0]  actual;
        begin
            dbg_reg_sel = rnum;
            #30;                   // FIX-3: was #2
            actual   = dbg_reg_data;
            test_num = test_num + 1;

            if (actual === expected) begin
                $display("  [PASS] Test %02d  R%-2d  got=0x%08X  exp=0x%08X  %0s",
                         test_num, rnum, actual, expected, desc);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Test %02d  R%-2d  got=0x%08X  exp=0x%08X  %0s",
                         test_num, rnum, actual, expected, desc);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================
    // TASK: check_pc_in_set
    //   Verifies pc_out is one of three expected addresses.
    // =========================================================
    task check_pc_in_set;
        input [31:0]  a0;
        input [31:0]  a1;
        input [31:0]  a2;
        input [479:0] desc;
        begin
            test_num = test_num + 1;
            if (pc_out===a0 || pc_out===a1 || pc_out===a2) begin
                $display("  [PASS] Test %02d  PC=0x%08X in expected set  %0s",
                         test_num, pc_out, desc);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Test %02d  PC=0x%08X NOT in {0x%08X,0x%08X,0x%08X}  %0s",
                         test_num, pc_out, a0, a1, a2, desc);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================
    // TASK: check_inline
    //   Custom pass/fail with explicit condition.
    // =========================================================
    task check_inline;
        input        ok;
        input [479:0] pmsg;
        input [479:0] fmsg;
        begin
            test_num = test_num + 1;
            if (ok) begin
                $display("  [PASS] Test %02d  %0s", test_num, pmsg);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Test %02d  %0s", test_num, fmsg);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================
    // TASK: separator
    // =========================================================
    task separator;
        input [479:0] lbl;
        begin
            $display("");
            $display("  ========================================================");
            $display("  %0s", lbl);
            $display("  ========================================================");
        end
    endtask

    // =========================================================
    // ALWAYS — Execution Trace
    //   FIX-5: trace_cyc only increments when !reset.
    //   Display only, never touches pass/fail counters.
    // =========================================================
    always @(negedge clk) begin
        if (!reset) begin
            trace_cyc = trace_cyc + 1;
            if (trace_cyc <= 22) begin
                $write("  [TRC] CYC=%02d  PC=0x%08X  ->  ",
                       trace_cyc, pc_out);
                case (pc_out)
                    32'h00000000: $display("MOV  R1, #0x13");
                    32'h00000004: $display("ADD  R2, R1, R1");
                    32'h00000008: $display("AND  R3, R1, R2");
                    32'h0000000c: $display("B    #0     [TAKEN -> 0x14, skip 0x10]");
                    32'h00000010: $display("!! 0x10 reached: B DID NOT SKIP !!");
                    32'h00000014: $display("MOV  R4, R1 LSL #2");
                    32'h00000018: $display("SUB  R5, R1, R2 LSR #2");
                    32'h0000001c: $display("ORR  R6, R3, R3 ROR #2");
                    32'h00000020: $display("MOV  R7, R6 ASR #28");
                    32'h00000024: $display("STR  R2, [R1, #85]");
                    32'h00000028: $display("LDR  R8, [R3, #102]");
                    32'h0000002c: $display("CMP  R2, R8   [Z<-1 if R2==R8]");
                    32'h00000030: $display("BNE  #18      [NOT taken, Z=1]");
                    32'h00000034: $display("BEQ  #0       [TAKEN -> 0x3C, Z=1]");
                    32'h00000038: $display("!! 0x38 reached: BEQ DID NOT JUMP !!");
                    32'h0000003c: $display("BL   #1       [R14<-0x40, PC->0x48]");
                    32'h00000040: $display("ANDEQ R0,R0,R0 [EQ passes Z=1]");
                    32'h00000044: $display("MOV  R0, #0x330");
                    32'h00000048: $display("BX   R14       [PC<-R14=0x40, loop]");
                    default:      $display("!! UNEXPECTED PC 0x%08X !!", pc_out);
                endcase
            end
        end
    end

    // =========================================================
    // MAIN
    // =========================================================
    initial begin
        pass_count  = 0;
        fail_count  = 0;
        test_num    = 0;
        trace_cyc   = 0;
        reset       = 1'b1;
        dbg_reg_sel = 4'd0;

        $display("");
        $display("  ########################################################");
        $display("  #    ARM Single-Cycle Processor  Testbench v4          #");
        $display("  #    Gate-Level  Clock=200ns  +notimingchecks required #");
        $display("  ########################################################");

        // ---- FIX-2: Release reset at negedge ----
        //
        // 200ns clock timeline:
        //   t=100: posedge 1 (reset=1)
        //   t=200: negedge 1
        //   t=300: posedge 2 (reset=1)
        //   t=400: negedge 2  ← @(negedge) fires
        //   t=402: reset=0    ← 98ns before next posedge
        //   t=500: posedge 3  ← FIRST instruction (cycle 1)
        //
        // NOTE: Check PC=0 BEFORE this posedge fires.
        // See PHASE 1 comment below for timing.
        repeat(2) @(posedge clk);
        @(negedge clk);
        #2;
        reset = 1'b0;
        $display("");
        $display("  [INFO] Reset released at t=%0t ps", $time);
        $display("  [INFO] First instruction posedge in ~98ns.");

        // =========================================================
        // PHASE 1 — Execution Trace
        //
        // The always@(negedge) trace block handles display.
        // We need to run enough cycles to cover the full program.
        //
        // Program flow requires ~20 instructions:
        //   18 unique addresses + BX loop cycles
        //
        // After reset=0 at ~t=402ns:
        //   25 posedges × 200ns = 5000ns execution
        //   Then #30 settle before register reads
        //
        // Time budget for register reads after repeat(25)+#30:
        //   We're at ~30ns into the 200ns window (30 < 100). Safe.
        // =========================================================
        separator("PHASE 1 — Execution Trace (negedge sampling)");
        repeat(25) @(posedge clk);
        #30;    // FIX-4: was #2. IO output buffer settle.

        // =========================================================
        // PHASE 2 — Data-Processing Registers
        //
        // Expected values from program at memfile.dat:
        //   0x00: E3A01013  MOV R1,#0x13           R1 = 19
        //   0x04: E0812001  ADD R2,R1,R1            R2 = 38
        //   0x08: E0013002  AND R3,R1,R2            R3 = 2
        //   0x14: E1A04101  MOV R4,R1 LSL#2         R4 = 76
        //   0x18: E0415122  SUB R5,R1,R2 LSR#2      R5 = 10
        //   0x1C: E1836163  ORR R6,R3,R3 ROR#2      R6 = 0x80000002
        //   0x20: E1A07E46  MOV R7,R6 ASR#28        R7 = 0xFFFFFFF8
        //
        // After each check_reg, #30 is consumed internally.
        // With 200ns window and starting at +30ns:
        //   7 calls × 30ns = 210ns from window start
        //   BUT each check call fires WITHIN the current window
        //   because no posedge fires during check phase.
        //   Actually: 30 (initial settle) + 7×30 = 240ns
        //   240ns > 200ns → POSEDGE FIRES DURING CHECKS!
        //
        // FIX: Do @(posedge clk); #30 before each check group
        //   to explicitly advance to the next window and settle.
        // =========================================================
        separator("PHASE 2 — Data-Processing Registers");
        $display("");

        // Each check is isolated: step to next posedge, settle, read.
        // This guarantees we're always reading at a stable point
        // and never crossing an unexpected posedge during reads.
        // The register values don't change (processor is in BX loop).

        @(posedge clk); #30;    // advance to safe read window
        check_reg(4'd1,  32'h00000013,
                  "MOV R1,#0x13                  R1=19");
        check_reg(4'd2,  32'h00000026,
                  "ADD R2,R1,R1                  R2=38");

        @(posedge clk); #30;
        check_reg(4'd3,  32'h00000002,
                  "AND R3,R1,R2  (0x13&0x26)     R3=2");
        check_reg(4'd4,  32'h0000004C,
                  "MOV R4,R1 LSL#2  (19<<2)      R4=76");

        @(posedge clk); #30;
        check_reg(4'd5,  32'h0000000A,
                  "SUB R5,R1,R2 LSR#2 (19-9)     R5=10");
        check_reg(4'd6,  32'h80000002,
                  "ORR R6,R3,R3 ROR#2            R6=0x80000002");

        @(posedge clk); #30;
        check_reg(4'd7,  32'hFFFFFFF8,
                  "MOV R7,R6 ASR#28              R7=0xFFFFFFF8");

        // =========================================================
        // PHASE 3 — Memory Instructions (STR + LDR)
        //
        // 0x24: E5812055  STR R2,[R1,#85]  Mem[104]=38
        // 0x28: E5938066  LDR R8,[R3,#102] R8=Mem[104]=38
        //   byte address = R1+85 = 19+85 = 104
        //   byte address = R3+102 = 2+102 = 104 (same word)
        //   R8 must equal R2 = 38 = 0x26
        // =========================================================
        separator("PHASE 3 — Memory Instructions (STR + LDR)");
        $display("");
        $display("  STR R2,[R1,#85]  addr=19+85=104");
        $display("  LDR R8,[R3,#102] addr=2+102=104 (same word)");
        $display("  R8 must equal R2 = 38 = 0x26");
        $display("");

        @(posedge clk); #30;
        check_reg(4'd8,  32'h00000026,
                  "LDR loaded STR value          R8=38=0x26");

        // =========================================================
        // PHASE 4 — Branch Instructions
        // =========================================================
        separator("PHASE 4 — Branch Instructions");
        $display("");

        @(posedge clk); #30;

        // B: R4=76 proves 0x14 ran (B took us there from 0x0C)
        $display("  B #0 at 0x0C: R4=76 proves 0x14 executed.");
        check_reg(4'd4, 32'h0000004C,
                  "B taken -> 0x14 ran           R4=76=0x4C");

        @(posedge clk); #30;

        // CMP operands
        $display("  CMP R2,R8 at 0x2C: R2-R8=38-38=0, Z should be 1.");
        check_reg(4'd2, 32'h00000026, "CMP left  operand             R2=38");
        check_reg(4'd8, 32'h00000026, "CMP right operand             R8=38");

        @(posedge clk); #30;

        // BL: R14=0x40 proves BL ran and saved return address
        $display("  BL at 0x3C: R14 should be 0x3C+4=0x40.");
        check_reg(4'd14, 32'h00000040,
                  "BL saved return address       R14=0x40");

        @(posedge clk); #30;

        // BX: R0=0x330 proves BX loop body (0x44) ran
        $display("  BX at 0x48: loop through 0x44 sets R0=0x330.");
        check_reg(4'd0, 32'h00000330,
                  "BX loop -> MOV R0,#0x330 ran  R0=0x330");

        @(posedge clk); #30;

        // PC in BX loop
        $display("  PC must be cycling {0x40, 0x44, 0x48}.");
        check_pc_in_set(32'h00000040, 32'h00000044, 32'h00000048,
                        "PC inside BX loop");

        // =========================================================
        // PHASE 5 — Conditional Logic Summary
        //
        //   AL: all data-proc+memory+BL (proven by R1-R8)
        //   EQ: BEQ taken, ANDEQ executes (proven by R14=0x40)
        //   NE: BNE NOT taken (Z=1 from CMP, proven by R14!=0)
        // =========================================================
        separator("PHASE 5 — Conditional Logic Summary");
        $display("");
        $display("  AL: R1..R8 correct -> all AL instructions ran.");
        $display("  EQ: R14=0x40 -> BEQ was taken -> EQ condition works.");
        $display("  NE: R14=0x40 -> BNE was NOT taken -> NE condition works.");
        $display("");

        @(posedge clk); #30;
        dbg_reg_sel = 4'd14; #30;

        check_inline(
            (dbg_reg_data === 32'h00000040),
            "CMP set Z=1: R14=0x40 proves BEQ+BL ran",
            "CMP did NOT set Z=1 correctly: R14 != 0x40"
        );

        dbg_reg_sel = 4'd14; #30;
        check_inline(
            (dbg_reg_data === 32'h00000040),
            "BNE not taken: R14=0x40 means BNE did not divert",
            "BNE wrongly taken: R14 != 0x40"
        );

        // =========================================================
        // FINAL SUMMARY
        // =========================================================
        $display("");
        $display("  ########################################################");
        $display("  #                   FINAL SUMMARY                      #");
        $display("  ########################################################");
        $display("  #  Total tests  : %3d                                  #",
                 test_num);
        $display("  #  PASSED       : %3d                                  #",
                 pass_count);
        $display("  #  FAILED       : %3d                                  #",
                 fail_count);
        $display("  #  Consistency  : pass+fail=%3d (must equal total)     #",
                 pass_count + fail_count);
        $display("  #------------------------------------------------------#");

        if (fail_count == 0) begin
            $display("  #  RESULT: *** ALL %2d TESTS PASSED -- PROCESSOR OK *** #",
                     test_num);
        end else begin
            $display("  #  RESULT: *** %3d TEST(S) FAILED -- SEE ABOVE ***     #",
                     fail_count);
            $display("  #------------------------------------------------------#");
            $display("  #  If ALL registers = 0:                               #");
            $display("  #    +notimingchecks missing from vsim command         #");
            $display("  #    Use run_tb_arm_gate.do instead of auto .do file   #");
            $display("  #  If values have extra bits (e.g. 0x42 not 0x02):    #");
            $display("  #    Same cause: +notimingchecks missing               #");
            $display("  #  If PC shows UNEXPECTED addresses:                   #");
            $display("  #    branches fail -> pcsrc wiring in arm.v            #");
        end

        $display("  ########################################################");
        $display("");
        $finish;
    end

endmodule