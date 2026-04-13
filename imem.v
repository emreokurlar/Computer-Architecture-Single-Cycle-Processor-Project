module imem (
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] mem [0:255];

    initial
        $readmemh("Instructions.hex", mem);

    assign instr = mem[addr[31:2]];
endmodule