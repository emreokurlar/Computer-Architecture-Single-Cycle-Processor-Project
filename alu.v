module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  alucontrol,
    output reg  [31:0] result,
    output wire [3:0]  flags       // {N, Z, C, V}
);
    // 33-bit extended sum for carry detection
    wire [32:0] sum_ext;
    assign sum_ext = (alucontrol == 3'b001)
                     ? ({1'b0, a} + {1'b0, ~b} + 33'd1)   // a - b (two's complement)
                     : ({1'b0, a} + {1'b0,  b});           // a + b

    always @(*) begin
        case (alucontrol)
            3'b000: result = a + b;         // ADD
            3'b001: result = a - b;         // SUB
            3'b010: result = a & b;         // AND
            3'b011: result = a | b;         // ORR
            3'b101: result = b;             // Pass B  (MOV)
            default: result = 32'b0;
        endcase
    end

    // N: sign bit of result
    assign flags[3] = result[31];
    // Z: result is zero
    assign flags[2] = (result == 32'b0) ? 1'b1 : 1'b0;
    // C: carry out (valid for ADD and SUB)
    assign flags[1] = ((alucontrol == 3'b000) || (alucontrol == 3'b001))
                      ? sum_ext[32] : 1'b0;
    // V: signed overflow (valid for ADD and SUB)
    assign flags[0] =
        ((alucontrol == 3'b000) &&  (a[31] ==  b[31]) && (result[31] != a[31])) ? 1'b1 :
        ((alucontrol == 3'b001) &&  (a[31] != b[31])  && (result[31] != a[31])) ? 1'b1 :
        1'b0;
endmodule
