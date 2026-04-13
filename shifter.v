module shifter (
    input  wire [31:0] din,
    input  wire [1:0]  sh,
    input  wire [4:0]  shamt,
    output reg  [31:0] dout
);
    always @(*) begin
        case (sh)
            2'b00: dout = din << shamt;                                    // LSL
            2'b01: dout = din >> shamt;                                    // LSR
            2'b10: dout = $signed(din) >>> shamt;                          // ASR
            2'b11: dout = (shamt == 5'b0) ? din :
                          (din >> shamt) | (din << (32 - shamt));          // ROR
        endcase
    end
endmodule