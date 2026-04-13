module controller (
    input  wire        clk,
    input  wire        reset,
    // Instruction fields
    input  wire [1:0]  op,
    input  wire [5:0]  funct,
    input  wire [3:0]  rd,
    input  wire [3:0]  cond,
    // Live ALU flags from datapath
    input  wire [3:0]  aluflags,
    // Gated control outputs
    output wire        pcsrc,
    output wire        regwrite,
    output wire        memwrite,
    // Un-gated datapath controls
    output wire        memtoreg,
    output wire        alusrc,
    output wire [1:0]  immsrc,
    output wire [1:0]  regsrc,
    output wire [2:0]  alucontrol,
    output wire        link
);
    wire [1:0] flagw;
    wire       pcs, regw, memw;

    decoder dec (
        .op(op),           .funct(funct),     .rd(rd),
        .flagw(flagw),     .pcs(pcs),
        .regw(regw),       .memw(memw),
        .memtoreg(memtoreg), .alusrc(alusrc),
        .immsrc(immsrc),   .regsrc(regsrc),
        .alucontrol(alucontrol), .link(link)
    );

    condlogic cl (
        .clk(clk),         .reset(reset),
        .cond(cond),       .aluflagsIn(aluflags),
        .flagw(flagw),     .pcs(pcs),
        .regw(regw),       .memw(memw),
        .pcsrc(pcsrc),     .regwrite(regwrite),
        .memwrite(memwrite)
    );
endmodule