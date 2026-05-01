module dmem (
    input  wire        clk,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wd,
    output reg  [31:0] rd
);

    // 256 x 32-bit data RAM
    reg [31:0] mem [0:255];

    wire [7:0] word_addr;
    assign word_addr = addr[9:2];   // word-aligned address

    integer k;
    initial begin
        for (k = 0; k < 256; k = k + 1)
            mem[k] = 32'h00000000;
    end

    always @(posedge clk) begin
        if (we) begin
            mem[word_addr] <= wd;
        end

        rd <= mem[word_addr];
    end

endmodule
