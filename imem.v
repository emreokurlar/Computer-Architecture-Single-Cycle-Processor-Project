module imem (
    input  wire        clk,
    input  wire [31:0] addr,
    output reg  [31:0] instr
);

    // 256 x 32-bit instruction ROM
    // Address range: 0x00000000 to 0x000003FC
    (* ram_init_file = "instructions.mif" *)
    reg [31:0] mem [0:255];

    wire [7:0] word_addr;
    assign word_addr = addr[9:2];   // divide byte address by 4

    always @(posedge clk) begin
        instr <= mem[word_addr];
    end

endmodule
