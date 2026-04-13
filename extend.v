module extend (
    input  wire [23:0] instr,
    input  wire [1:0]  immsrc,
    output reg  [31:0] extimm
);
    // For rotate-immediate mode
    wire [31:0] imm8_32;
    wire [4:0]  rot;
    assign imm8_32 = {24'b0, instr[7:0]};
    assign rot     = {instr[11:8], 1'b0};   // rotation = rot_field × 2

    always @(*) begin
        case (immsrc)
            // --- Rotate-right imm8 (data-processing, I=1) ---
            2'b00: begin
                if (rot == 5'b0)
                    extimm = imm8_32;
                else
                    extimm = (imm8_32 >> rot) | (imm8_32 << (32 - rot));
            end
            // --- Zero-extend imm12 (memory) -----------------
            2'b01: extimm = {20'b0, instr[11:0]};
            // --- Sign-extend imm24 and shift left 2 (branch) ---
            2'b10: extimm = {{6{instr[23]}}, instr[23:0], 2'b00};
            default: extimm = 32'b0;
        endcase
    end
endmodule