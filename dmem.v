module dmem (
    input  wire        clk,
    input  wire        we,          // write enable (from MemWrite)
    input  wire [31:0] addr,
    input  wire [31:0] wd,          // write data
    output wire [31:0] rd           // read data
);
    reg [31:0] mem [0:255];

    integer k;
    initial
        for (k = 0; k < 256; k = k + 1) mem[k] = 32'b0;

    always @(posedge clk)
        if (we) mem[addr[31:2]] <= wd;

    assign rd = mem[addr[31:2]];
endmodule