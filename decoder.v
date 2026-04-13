module decoder (
    input  wire [1:0] op,
    input  wire [5:0] funct,
    input  wire [3:0] rd,
    // Outputs to condlogic
    output reg  [1:0] flagw,        // [1]=write NZ, [0]=write CV
    output wire       pcs,          // pre-gated PC select
    output reg        regw,         // pre-gated register write
    output reg        memw,         // pre-gated memory write
    // Direct datapath outputs (not gated by condition)
    output reg        memtoreg,
    output reg        alusrc,
    output reg  [1:0] immsrc,
    output reg  [1:0] regsrc,       // [0]=RA1 sel, [1]=RA2 sel
    output reg  [2:0] alucontrol,
    output wire       link          // 1 for BL instruction
);
    reg branch;

    // PCS: set for branch ops OR when any instruction writes R15
    // (BX is encoded as MOV PC, Rm, so rd=1111 & regw catches it)
    assign pcs  = branch | ((rd == 4'b1111) & regw);

    // LINK: true only for BL (Op=10, L-bit=1 at instr[24])
    assign link = (op == 2'b10) & funct[4];

    always @(*) begin
        // ---------- Safe defaults ----------
        flagw      = 2'b00;
        regw       = 1'b0;
        memw       = 1'b0;
        memtoreg   = 1'b0;
        alusrc     = 1'b0;
        immsrc     = 2'b00;
        regsrc     = 2'b00;
        alucontrol = 3'b000;
        branch     = 1'b0;

        case (op)
            // ======================================================
            // DATA PROCESSING  (Op = 00)
            // funct[5]=I  funct[4:1]=cmd  funct[0]=S
            // ======================================================
            2'b00: begin
                regw   = 1'b1;
                alusrc = funct[5];          // I=1 → use immediate

                if (funct[5])               // Immediate mode
                    immsrc = 2'b00;         // rotate-imm8 in extender

                // Map ARM cmd to ALUControl
                case (funct[4:1])
                    4'b0100: alucontrol = 3'b000; // ADD
                    4'b0010: alucontrol = 3'b001; // SUB
                    4'b0000: alucontrol = 3'b010; // AND
                    4'b1100: alucontrol = 3'b011; // ORR
                    4'b1101: alucontrol = 3'b101; // MOV  → pass B
                    4'b1010: begin                // CMP  → SUB, no write
                        alucontrol = 3'b001;
                        regw       = 1'b0;
                    end
                    default: alucontrol = 3'b000;
                endcase

                // Flag write when S=1
                if (funct[0]) begin
                    flagw[1] = 1'b1;        // always write N, Z
                    // Write C, V only for arithmetic instructions
                    if (funct[4:1] == 4'b0100 ||    // ADD
                        funct[4:1] == 4'b0010 ||    // SUB
                        funct[4:1] == 4'b1010)      // CMP
                        flagw[0] = 1'b1;
                end
            end

            // ======================================================
            // MEMORY  (Op = 01)
            // funct[0]=L  (1=LDR, 0=STR)
            // ======================================================
            2'b01: begin
                alusrc     = 1'b1;          // address = Rn + imm12
                immsrc     = 2'b01;         // zero-extend imm12
                alucontrol = 3'b000;        // ADD

                if (funct[0]) begin         // LDR
                    regw     = 1'b1;
                    memtoreg = 1'b1;
                end else begin              // STR
                    memw   = 1'b1;
                    regsrc = 2'b10;         // RA2 = Rd (value to store)
                end
            end

            // ======================================================
            // BRANCH  (Op = 10)
            // funct[4] = L (0=B, 1=BL)
            // ======================================================
            2'b10: begin
                branch     = 1'b1;
                alusrc     = 1'b1;          // use extended imm24
                immsrc     = 2'b10;         // sign-ext imm24 << 2
                regsrc     = 2'b01;         // RA1 = R15 (PC+8)
                alucontrol = 3'b000;        // PC+8 + offset

                if (funct[4])               // BL: also write return address
                    regw = 1'b1;            // → R14 = PC+4 (via datapath link mux)
            end

            default: begin end
        endcase
    end
endmodule