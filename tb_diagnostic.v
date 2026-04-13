// ============================================================
// FILE: tb_diagnostic.v  (Final Gate-Level Version)
//
// ROOT CAUSES AND FIXES:
//
// FIX-1: Clock period 200ns (#100 toggle)
//   The cascaded check_reg calls after the last step of S1
//   total 138ns (15settle + 3chk_pc + 3×15 + 5×15 + 3+15).
//   With 100ns clock this crossed a posedge, injecting an
//   extra instruction cycle.
//   200ns > 138ns ensures NO posedge fires during read chains.
//
//   Clock budget after each step():
//     Tc+15: step settle (IO buffer settled)
//     Tc+15+N×15: N check_reg calls (max N=11 = 165ns < 200ns)
//     Tc+200: next posedge (safe!)
//
// FIX-2: T01 check_pc(0) happens BEFORE first posedge
//   Old code waited @(negedge) AFTER reset=0.
//   That crossed a posedge, running cycle 1 before T01.
//   New code:  reset=0 at negedge, then #10, then check_pc(0).
//   Next posedge is 90+ns away. PC is still 0. Safe.
//
// FIX-3: +notimingchecks in .do file (see above)
//   Prevents $hold violations from propagating X→1 into
//   register file FFs.
// ============================================================

`timescale 1ns / 1ps

module tb_diagnostic;

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
    //
    // FIX-1: 200ns prevents check_reg chains from crossing
    //        posedge boundaries.
    //
    //   posedge at: 100, 300, 500, 700, 900 ... ns
    //   negedge at: 200, 400, 600, 800, 1000 ... ns
    //
    // Budget after each step():
    //   step settle (+15ns): 15ns used, 185ns remain
    //   11 check_reg calls (11×15=165ns): total 180ns used
    //   Next posedge at 200ns: 20ns guard  ← safe
    // =========================================================
    initial clk = 1'b0;
    always  #100 clk = ~clk;      // FIX-1: 200ns period

    // =========================================================
    // Counters
    // =========================================================
    integer pass_count;
    integer fail_count;
    integer test_num;
    integer sec_pass;
    integer sec_fail;
    integer saved_pass;
    integer saved_fail;

    // =========================================================
    // TASK: step
    //   Waits for posedge (executes one instruction) then
    //   15ns for all Cyclone III gate outputs to settle.
    //
    //   After step(), time budget for reads = 185ns.
    //   Max safe consecutive check_reg calls = 11 (165ns).
    // =========================================================
    task step;
        begin
            @(posedge clk);
            #15;
        end
    endtask

    // =========================================================
    // TASK: check_reg
    //   Changes dbg_reg_sel, waits 15ns for
    //   IO ibuf(5ns) + mux(2ns) + IO obuf(7ns) = 14ns
    //   to settle, then reads dbg_reg_data.
    // =========================================================
    task check_reg;
        input  [3:0]   rnum;
        input  [31:0]  expected;
        input  [479:0] desc;
        reg    [31:0]  got;
        begin
            dbg_reg_sel = rnum;
            #15;
            got      = dbg_reg_data;
            test_num = test_num + 1;

            if (got === expected) begin
                $display("    [PASS] T%02d  R%-2d = 0x%08X          %0s",
                         test_num, rnum, got, desc);
                pass_count = pass_count + 1;
            end else begin
                $display("    [FAIL] T%02d  R%-2d  got=0x%08X  exp=0x%08X  %0s",
                         test_num, rnum, got, expected, desc);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================
    // TASK: check_pc
    //   pc_out is already stable after step()+15ns.
    //   #3 is a guard margin only.
    // =========================================================
    task check_pc;
        input  [31:0]  expected;
        input  [479:0] desc;
        begin
            #3;
            test_num = test_num + 1;
            if (pc_out === expected) begin
                $display("    [PASS] T%02d  PC  = 0x%08X          %0s",
                         test_num, pc_out, desc);
                pass_count = pass_count + 1;
            end else begin
                $display("    [FAIL] T%02d  PC   got=0x%08X  exp=0x%08X  %0s",
                         test_num, pc_out, expected, desc);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================
    // TASK: check_not_equal
    // =========================================================
    task check_not_equal;
        input  [3:0]   rnum;
        input  [31:0]  forbidden;
        input  [479:0] desc;
        reg    [31:0]  got;
        begin
            dbg_reg_sel = rnum;
            #15;
            got      = dbg_reg_data;
            test_num = test_num + 1;
            if (got !== forbidden) begin
                $display("    [PASS] T%02d  R%-2d = 0x%08X (not 0x%08X)  %0s",
                         test_num, rnum, got, forbidden, desc);
                pass_count = pass_count + 1;
            end else begin
                $display("    [FAIL] T%02d  R%-2d MATCHES FORBIDDEN 0x%08X  %0s",
                         test_num, rnum, got, desc);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================
    // TASK: section_start / section_end
    // =========================================================
    task section_start;
        input [479:0] title;
        begin
            $display("");
            $display("  +------------------------------------------------------+");
            $display("  | %-52s |", title);
            $display("  +------------------------------------------------------+");
            saved_pass = pass_count;
            saved_fail = fail_count;
        end
    endtask

    task section_end;
        begin
            sec_pass = pass_count - saved_pass;
            sec_fail = fail_count - saved_fail;
            if (sec_fail == 0)
                $display("  | Result: ALL %0d PASSED                                  |",
                         sec_pass);
            else
                $display("  | Result: %0d passed,  %0d FAILED                         |",
                         sec_pass, sec_fail);
            $display("  +------------------------------------------------------+");
        end
    endtask

    // =========================================================
    // MAIN
    // =========================================================
    initial begin
        pass_count  = 0;
        fail_count  = 0;
        test_num    = 0;
        reset       = 1'b1;
        dbg_reg_sel = 4'd0;

        $display("");
        $display("  #####################################################");
        $display("  #  ARM DIAGNOSTIC TB  Gate-Level  Clock=200ns       #");
        $display("  #####################################################");
        $display("  #  FIX-1: 200ns clock (138ns max read chain < 200) #");
        $display("  #  FIX-2: PC=0 checked before first posedge        #");
        $display("  #  FIX-3: +notimingchecks MUST be in .do file      #");
        $display("  #####################################################");

        // ---- FIX-2: Release reset at negedge, check PC=0 before ----
        // next posedge fires.
        //
        // 200ns clock timeline:
        //   t=100:  posedge 1 (reset=1)
        //   t=200:  negedge 1
        //   t=300:  posedge 2 (reset=1)
        //   t=400:  negedge 2
        //   t=500:  posedge 3 (reset=1)
        //   t=600:  negedge 3  <-- @(negedge) fires here
        //   t=602:  reset=0   <-- released 98ns before next posedge
        //   t=612:  check_pc(0) -- PC still 0, posedge not until t=700
        //   t=700:  posedge 4  <-- FIRST instruction runs here (cycle 1)
        //
        repeat(3) @(posedge clk);   // posedges at t=100, 300, 500
        @(negedge clk);             // negedge at t=600
        #2;
        reset = 1'b0;               // t=602 (98ns before next posedge)
        $display("");
        $display("  [INFO] Reset released at t=%0t ps", $time);
        $display("  [INFO] Next posedge fires in ~98ns.");
        $display("  [INFO] Checking PC=0 before any instruction runs.");

        // =========================================================
        // SECTION 1: flopr.v — PC Register
        //
        // T01: checked 10ns after reset release, BEFORE first posedge.
        //   PC = 0 because no posedge has fired with reset=0 yet.
        //
        // T02-T04: each step() fires one posedge.
        //   PC advances by 4 per step.
        //
        // With FIX-2, T01 reads PC=0 before cycle 1 runs.
        // No more "one cycle ahead" problem.
        // =========================================================
        section_start("Section 1 - flopr.v  (PC Register)");

        // FIX-2: Read PC BEFORE first posedge (t=602 → 612ns)
        // Next posedge is at t=700ns, 88ns away. Fully safe.
        #10;
        check_pc(32'h00000000,
                 "flopr: PC=0 after reset (before cycle 1)");

        step;    // cycle 1: posedge t=700. MOV R0,#0xAA. PC→0x04.
        check_pc(32'h00000004,
                 "flopr: PC=0x04 after cycle 1");

        step;    // cycle 2: posedge t=900. MOV R1,#0x55. PC→0x08.
        check_pc(32'h00000008,
                 "flopr: PC=0x08 after cycle 2");

        step;    // cycle 3: posedge t=1100. MOV R2,R15. PC→0x0C.
        check_pc(32'h0000000C,
                 "flopr: PC=0x0C after cycle 3");

        section_end;
        // After S1: PC=0x0C. 3 cycles ran. t≈1118ns.
        // Next posedge at t=1300ns. Remaining window: 182ns.
        // S2+S3+S4 reads = 138ns < 182ns ← NO extra cycle fires.

        // =========================================================
        // SECTION 2: imem.v — Instruction Memory
        //
        // R0=0xAA proves 0x00 was fetched (cycle 1)
        // R1=0x55 proves 0x04 was fetched (cycle 2)
        // R2=0x10 proves 0x08 was fetched (cycle 3)
        //   R2=0x10 requires BOTH imem (right instruction) AND
        //   adder (PC+8=0x10) to work correctly.
        //
        // Time from last posedge (t=1100):
        //   +15 (step), +3 (check_pc), +15, +15, +15 = 63ns
        //   Next posedge at t=1300 (200ns later). 63 < 200. Safe.
        // =========================================================
        section_start("Section 2 - imem.v   (Instruction Memory)");

        check_reg(4'd0, 32'h000000AA,
                  "imem: 0x00 MOV R0,#0xAA -> R0=0xAA");
        check_reg(4'd1, 32'h00000055,
                  "imem: 0x04 MOV R1,#0x55 -> R1=0x55");
        check_reg(4'd2, 32'h00000010,
                  "imem: 0x08 MOV R2,R15   -> R2=0x10");

        section_end;
        // Time used from t=1100: 63ns. Next posedge at t=1300. Safe.

        // =========================================================
        // SECTION 3: regfile.v — Register File
        //
        // 5 check_reg calls = 75ns more.
        // Total from t=1100: 63+75 = 138ns < 200ns. Safe.
        // =========================================================
        section_start("Section 3 - regfile.v (Register File)");

        check_reg(4'd0, 32'h000000AA,
                  "regfile: R0 write+read");
        check_reg(4'd1, 32'h00000055,
                  "regfile: R1 write+read");
        check_reg(4'd2, 32'h00000010,
                  "regfile: R15 bypass: R2=PC+8=0x10");
        check_reg(4'd0, 32'h000000AA,
                  "regfile: R0 re-read unchanged");
        check_reg(4'd1, 32'h00000055,
                  "regfile: R1 re-read unchanged");

        section_end;
        // Total from t=1100: 138ns < 200ns. Safe.

        // =========================================================
        // SECTION 4: adder.v — PC+4 and PC+8
        //
        // 2 more reads = 30ns. Total from t=1100: 168ns < 200ns.
        // =========================================================
        section_start("Section 4 - adder.v  (PC+4 and PC+8)");

        check_pc(32'h0000000C,
                 "adder(+4): PC=0x0C after 3 cycles");
        check_reg(4'd2, 32'h00000010,
                  "adder(+8): R15 at fetch 0x08 = 0x08+8 = 0x10");

        section_end;
        // Total from t=1100: 168ns < 200ns. Safe.
        // Section 4 ends at t≈1268ns. Next posedge at t=1300ns.
        // 32ns guard. Safe.

        // =========================================================
        // SECTION 5: alu.v — ALU Operations
        //
        // Each step+check_reg = 30ns per pair, well within 200ns.
        //
        // cycle 4 (0x0C): MOV R3,#10    R3=0x0A
        // cycle 5 (0x10): MOV R4,#3     R4=0x03
        // cycle 6 (0x14): ADD R5,R3,R4  R5=0x0D
        // cycle 7 (0x18): SUB R6,R3,R4  R6=0x07
        // cycle 8 (0x1C): AND R7,R3,R4  R7=0x02
        // cycle 9 (0x20): ORR R8,R3,R4  R8=0x0B
        // =========================================================
        section_start("Section 5 - alu.v    (ALU Operations)");

        step;    // cycle 4: MOV R3,#10
        check_reg(4'd3, 32'h0000000A, "alu: setup R3=10");

        step;    // cycle 5: MOV R4,#3
        check_reg(4'd4, 32'h00000003, "alu: setup R4=3");

        step;    // cycle 6: ADD R5,R3,R4
        check_reg(4'd5, 32'h0000000D, "alu: ADD R5=R3+R4  10+3=13");

        step;    // cycle 7: SUB R6,R3,R4
        check_reg(4'd6, 32'h00000007, "alu: SUB R6=R3-R4  10-3=7");

        step;    // cycle 8: AND R7,R3,R4
        check_reg(4'd7, 32'h00000002, "alu: AND R7=R3&R4  0xA&0x3=0x2");

        step;    // cycle 9: ORR R8,R3,R4
        check_reg(4'd8, 32'h0000000B, "alu: ORR R8=R3|R4  0xA|0x3=0xB");

        section_end;

        // =========================================================
        // SECTION 6: shifter.v — Barrel Shifter
        //
        // cycle 10: MOV R9,  R3 LSL#2  → 10<<2=40=0x28
        // cycle 11: MOV R10, R3 LSR#1  → 10>>1=5
        // cycle 12: MOV R11, #0
        // cycle 13: SUB R11, R11, R3   → 0-10=-10=0xFFFFFFF6
        // cycle 14: MOV R12, R11 ASR#1 → -10>>>1=0xFFFFFFFB
        // cycle 15: MOV R1,  #0xFF     → R1=0xFF
        // cycle 16: MOV R2,  R1 ROR#4  → 0xFF ROR 4=0xF000000F
        // =========================================================
        section_start("Section 6 - shifter.v (Barrel Shifter)");

        step;    // cycle 10: MOV R9, R3 LSL#2
        check_reg(4'd9, 32'h00000028,
                  "shifter: LSL R9=R3 LSL#2   10<<2=40=0x28");

        step;    // cycle 11: MOV R10, R3 LSR#1
        check_reg(4'd10, 32'h00000005,
                  "shifter: LSR R10=R3 LSR#1  10>>1=5");

        step;    // cycle 12: MOV R11, #0
        step;    // cycle 13: SUB R11,R11,R3  (0-10=-10)
        check_reg(4'd11, 32'hFFFFFFF6,
                  "shifter: ASR setup: R11=0-10=0xFFFFFFF6");

        step;    // cycle 14: MOV R12, R11 ASR#1
        check_reg(4'd12, 32'hFFFFFFFB,
                  "shifter: ASR R12=R11 ASR#1  -10>>>1=0xFFFFFFFB");

        step;    // cycle 15: MOV R1, #0xFF
        check_reg(4'd1, 32'h000000FF,
                  "shifter: ROR setup R1=0xFF");

        step;    // cycle 16: MOV R2, R1 ROR#4
        check_reg(4'd2, 32'hF000000F,
                  "shifter: ROR R2=R1 ROR#4  0xFF ROR 4=0xF000000F");

        section_end;

        // =========================================================
        // SECTION 7: extend.v — Immediate Extender
        //
        // cycle 17: MOV R3,#0x01000000  (E3A03401)
        //   imm8=0x01, rot_field=bits[11:8]=4
        //   rotation = 4*2 = 8
        //   0x01 ROR 8 = 0x01000000
        // =========================================================
        section_start("Section 7 - extend.v (Immediate Extender)");

        step;    // cycle 17: MOV R3,#0x01000000  (E3A03401)
        check_reg(4'd3, 32'h01000000,
                  "extend: imm8=0x01 rot_field=4 -> 0x01 ROR 8 = 0x01000000");

        section_end;

        // =========================================================
        // SECTION 8: dmem.v — Data Memory (STR + LDR)
        //
        // cycle 18: MOV R4,#0x77   R4=0x77
        // cycle 19: MOV R5,#64     R5=64=0x40
        // cycle 20: STR R4,[R5,#4] Mem[68]=0x77
        // cycle 21: MOV R4,#0      R4=0 (clears R4)
        // cycle 22: LDR R4,[R5,#4] R4=Mem[68]=0x77
        //
        // byte address = 64+4 = 68. word address = 68/4 = 17.
        // =========================================================
        section_start("Section 8 - dmem.v   (Data Memory STR + LDR)");

        step;    // cycle 18: MOV R4, #0x77
        check_reg(4'd4, 32'h00000077, "dmem: setup R4=0x77");

        step;    // cycle 19: MOV R5, #64
        check_reg(4'd5, 32'h00000040, "dmem: setup R5=64=0x40");

        step;    // cycle 20: STR R4,[R5,#4]  Mem[68]=0x77
        step;    // cycle 21: MOV R4,#0       clear R4
        check_reg(4'd4, 32'h00000000,
                  "dmem: R4=0 (clears before LDR)");

        step;    // cycle 22: LDR R4,[R5,#4]
        check_reg(4'd4, 32'h00000077,
                  "dmem: LDR R4=[R5+4] addr=68 -> R4=0x77");

        section_end;

        // =========================================================
        // SECTION 9: condlogic.v — Flag Storage
        //
        // cycle 23: MOV R7,#7
        // cycle 24: MOV R8,#7
        // cycle 25: CMP R7,R8  (7-7=0, Z←1)
        //
        // Z storage proven indirectly by Section 10.
        // =========================================================
        section_start("Section 9 - condlogic.v  (Flag Storage via CMP)");

        step;    // cycle 23: MOV R7, #7
        check_reg(4'd7, 32'h00000007, "condlogic: setup R7=7");

        step;    // cycle 24: MOV R8, #7
        check_reg(4'd8, 32'h00000007, "condlogic: setup R8=7");

        step;    // cycle 25: CMP R7,R8  (7-7=0, Z←1)
        $display("    [INFO] CMP R7,R8: 7-7=0, Z should now be 1.");
        $display("    [INFO] Section 10 proves Z was stored.");

        section_end;

        // =========================================================
        // SECTION 10: condcheck.v — BNE NOT taken (Z=1)
        //
        // cycle 26: BNE at 0x64
        //   NE needs Z=0. Since Z=1, NOT taken. PC→0x68.
        //
        // cycle 27: MOV R9,#0x11 at 0x68
        //   Only executes if BNE was NOT taken. R9=0x11 proves it.
        // =========================================================
        section_start("Section 10 - condcheck.v (BNE NOT taken, Z=1)");

        step;    // cycle 26: BNE at 0x64  (Z=1 → NE fails → sequential)
        check_pc(32'h00000068,
                 "condcheck: BNE Z=1 -> PC=0x68 (NOT taken)");

        step;    // cycle 27: MOV R9,#0x11 at 0x68
        check_reg(4'd9, 32'h00000011,
                  "condcheck: 0x68 executed -> R9=0x11");

        section_end;

        // =========================================================
        // SECTION 11: condcheck.v — BEQ NOT taken (Z=0)
        //
        // cycle 28: MOV R10,#5
        // cycle 29: MOV R11,#9
        // cycle 30: CMP R10,R11  (5-9=-4, Z←0)
        // cycle 31: BEQ at 0x78  (EQ needs Z=1. Z=0 → NOT taken → 0x7C)
        // cycle 32: MOV R12,#0x22 at 0x7C
        // =========================================================
        section_start("Section 11 - condcheck.v (BEQ NOT taken, Z=0)");

        step;    // cycle 28: MOV R10,#5
        check_reg(4'd10, 32'h00000005, "condcheck: setup R10=5");

        step;    // cycle 29: MOV R11,#9
        check_reg(4'd11, 32'h00000009, "condcheck: setup R11=9");

        step;    // cycle 30: CMP R10,R11  (5-9=-4, Z←0)
        $display("    [INFO] CMP R10,R11: 5-9=-4, Z should be 0.");

        step;    // cycle 31: BEQ at 0x78  (Z=0 → NOT taken → 0x7C)
        check_pc(32'h0000007C,
                 "condcheck: BEQ Z=0 -> PC=0x7C (NOT taken)");

        step;    // cycle 32: MOV R12,#0x22 at 0x7C
        check_reg(4'd12, 32'h00000022,
                  "condcheck: 0x7C executed -> R12=0x22");

        section_end;

        // =========================================================
        // SECTION 12: condcheck.v — BEQ TAKEN (Z=1)
        //
        // Navigate to CMP R5,R6 (both=3) via:
        //   33: B  0x80 → 0x88 (skips 0x84)
        //   34: MOV R13,#0x44
        //   35: BL 0x8C → R14=0x90, PC=0x98
        //   36: MOV R0,#0x55  (subroutine)
        //   37: BX R14 → PC=0x90
        //   38: B  0x90 → 0xA0
        //   39: MOV R1,#0x66
        //   40: MOV R5,#3
        //   41: MOV R6,#3
        //   42: CMP R5,R6 (3-3=0, Z←1)
        //   43: BEQ 0xB0 → TAKEN → 0xB8
        //   44: MOV R7,#0xBB at 0xB8
        // =========================================================
        section_start("Section 12 - condcheck.v (BEQ TAKEN, Z=1)");

        step;    // cycle 33: B  at 0x80 → 0x88
        step;    // cycle 34: MOV R13,#0x44 at 0x88
        step;    // cycle 35: BL at 0x8C
        step;    // cycle 36: MOV R0,#0x55 at 0x98
        step;    // cycle 37: BX R14 at 0x9C → PC=0x90
        step;    // cycle 38: B  at 0x90 → 0xA0
        step;    // cycle 39: MOV R1,#0x66 at 0xA0
        step;    // cycle 40: MOV R5,#3 at 0xA4
        check_reg(4'd5, 32'h00000003, "condcheck: setup R5=3");

        step;    // cycle 41: MOV R6,#3 at 0xA8
        check_reg(4'd6, 32'h00000003, "condcheck: setup R6=3");

        step;    // cycle 42: CMP R5,R6 at 0xAC  (3-3=0, Z←1)
        $display("    [INFO] CMP R5,R6: 3-3=0, Z should be 1.");

        step;    // cycle 43: BEQ at 0xB0  (Z=1 → EQ passes → 0xB8)
        check_pc(32'h000000B8,
                 "condcheck: BEQ Z=1 -> PC=0xB8 (TAKEN, skip 0xB4)");

        step;    // cycle 44: MOV R7,#0xBB at 0xB8
        check_reg(4'd7, 32'h000000BB,
                  "condcheck: 0xB8 executed -> R7=0xBB");
        check_not_equal(4'd7, 32'h000000FF,
                        "condcheck: dead 0xB4 NOT run: R7 != 0xFF");

        section_end;

        // =========================================================
        // SECTION 13: condcheck.v — BNE TAKEN (Z=0)
        //
        // cycle 45: MOV R5,#1
        // cycle 46: MOV R6,#2
        // cycle 47: CMP R5,R6  (1-2=-1, Z←0)
        // cycle 48: BNE at 0xC8 → TAKEN → 0xD0
        // cycle 49: MOV R8,#0x99 at 0xD0
        // =========================================================
        section_start("Section 13 - condcheck.v (BNE TAKEN, Z=0)");

        step;    // cycle 45: MOV R5,#1 at 0xBC
        check_reg(4'd5, 32'h00000001, "condcheck: setup R5=1");

        step;    // cycle 46: MOV R6,#2 at 0xC0
        check_reg(4'd6, 32'h00000002, "condcheck: setup R6=2");

        step;    // cycle 47: CMP R5,R6 at 0xC4  (1-2=-1, Z←0)
        $display("    [INFO] CMP R5,R6: 1-2=-1, Z should be 0.");

        step;    // cycle 48: BNE at 0xC8  (Z=0 → NE passes → 0xD0)
        check_pc(32'h000000D0,
                 "condcheck: BNE Z=0 -> PC=0xD0 (TAKEN, skip 0xCC)");

        step;    // cycle 49: MOV R8,#0x99 at 0xD0
        check_reg(4'd8, 32'h00000099,
                  "condcheck: 0xD0 executed -> R8=0x99");
        check_not_equal(4'd8, 32'h000000FF,
                        "condcheck: dead 0xCC NOT run: R8 != 0xFF");

        section_end;

        // =========================================================
        // SECTION 14: decoder.v — B unconditional
        //
        // B #0 at 0x80 (cycle 33):
        //   target = 0x80+8+(0<<2) = 0x88
        //   0x84 = dead code (MOV R13,#0x33 skipped)
        //   0x88: MOV R13,#0x44 ran → R13=0x44
        // =========================================================
        section_start("Section 14 - decoder.v  (B unconditional)");

        check_reg(4'd13, 32'h00000044,
                  "decoder: B taken -> 0x88 ran: R13=0x44");
        check_not_equal(4'd13, 32'h00000033,
                        "decoder: dead 0x84 NOT run: R13 != 0x33");

        section_end;

        // =========================================================
        // SECTION 15: decoder.v — BL Branch with Link
        //
        // BL #1 at 0x8C (cycle 35):
        //   R14 = 0x8C+4 = 0x90
        //   PC  = 0x8C+8+(1<<2) = 0x98
        //   Subroutine: MOV R0,#0x55 → R0=0x55 (cycle 36)
        // =========================================================
        section_start("Section 15 - decoder.v  (BL Branch with Link)");

        check_reg(4'd14, 32'h00000090,
                  "decoder: BL R14=PC+4=0x8C+4=0x90");
        check_reg(4'd0, 32'h00000055,
                  "decoder: BL jumped to 0x98: subroutine R0=0x55");
        check_not_equal(4'd0, 32'h00000033,
                        "decoder: dead 0x94 NOT run: R0 != 0x33");

        section_end;

        // =========================================================
        // SECTION 16: decoder.v — BX Branch Exchange
        //
        // BX R14 at 0x9C (cycle 37):
        //   E12FFF1E has shamt=31,sh=LSR baked in
        //   Without noshift: R14 LSR 31 = 0 → wrong jump
        //   With noshift=1:  R14 passes unchanged → PC=0x90
        //
        // After BX→0x90: B #2 at 0x90 → 0xA0 (cycle 38)
        //   MOV R1,#0x66 at 0xA0 (cycle 39) → R1=0x66
        // =========================================================
        section_start("Section 16 - decoder.v  (BX Branch Exchange)");

        check_reg(4'd1, 32'h00000066,
                  "decoder: BX->0x90->B#2->0xA0: R1=0x66");
        check_reg(4'd0, 32'h00000055,
                  "decoder: BX return correct: R0=0x55");

        section_end;

        // =========================================================
        // FINAL SUMMARY
        // =========================================================
        $display("");
        $display("  #####################################################");
        $display("  #               DIAGNOSTIC SUMMARY                  #");
        $display("  #####################################################");
        $display("  #  Total tests  : %3d                               #",
                 test_num);
        $display("  #  PASSED       : %3d                               #",
                 pass_count);
        $display("  #  FAILED       : %3d                               #",
                 fail_count);
        $display("  #  Consistency  : pass+fail=%3d (must = total)      #",
                 pass_count + fail_count);
        $display("  #---------------------------------------------------#");

        if (fail_count == 0) begin
            $display("  #  ALL %2d TESTS PASSED -- PROCESSOR OK             #",
                     test_num);
        end else begin
            $display("  #  %3d FAILURE(S) REMAIN                           #",
                     fail_count);
            $display("  #---------------------------------------------------#");
            $display("  #  If values wrong by 1 bit:                        #");
            $display("  #    +notimingchecks NOT in .do -> add it           #");
            $display("  #  If PC consistently N cycles ahead:               #");
            $display("  #    extra cycle injection -> increase clock period  #");
            $display("  #  Sec  1 -> flopr.v    PC not advancing            #");
            $display("  #  Sec  2 -> imem.v     wrong instruction           #");
            $display("  #  Sec  3 -> regfile.v  write/read broken           #");
            $display("  #  Sec  4 -> adder.v    PC+4 or PC+8               #");
            $display("  #  Sec  5 -> alu.v      wrong operation             #");
            $display("  #  Sec  6 -> shifter.v  wrong shift                 #");
            $display("  #  Sec  7 -> extend.v   wrong immediate             #");
            $display("  #  Sec  8 -> dmem.v     STR/LDR error               #");
            $display("  #  Sec  9 -> condlogic  Z not stored                #");
            $display("  #  Sec 10 -> condcheck  NE wrong Z=1                #");
            $display("  #  Sec 11 -> condcheck  EQ wrong Z=0                #");
            $display("  #  Sec 12 -> condcheck  EQ not jumping Z=1          #");
            $display("  #  Sec 13 -> condcheck  NE not jumping Z=0          #");
            $display("  #  Sec 14 -> decoder    B not taken                 #");
            $display("  #  Sec 15 -> decoder    BL link broken              #");
            $display("  #  Sec 16 -> decoder    BX noshift missing          #");
        end

        $display("  #####################################################");
        $display("");
        $finish;
    end

endmodule