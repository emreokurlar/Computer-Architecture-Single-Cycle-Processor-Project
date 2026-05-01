module controller (
    input  wire        clk,
    input  wire        reset,
    input  wire [1:0]  op,
    input  wire [5:0]  funct,
    input  wire [3:0]  rd,
    input  wire [3:0]  cond,
    input  wire [3:0]  aluflags,
    output wire        pcsrc,
    output wire        regwrite,
    output wire        memwrite,
    output wire        memtoreg,
    output wire        alusrc,
    output wire [1:0]  immsrc,
    output wire [1:0]  regsrc,
    output wire [2:0]  alucontrol,
    output wire        bl_en,
    output wire        bx_en
);
    wire [1:0] flagw;
    wire       pcs, regw, memw;

    decoder dec (
        .op(op),           .funct(funct),     .rd(rd),
        .flagw(flagw),     .pcs(pcs),
        .regw(regw),       .memw(memw),
        .memtoreg(memtoreg), .alusrc(alusrc),
        .immsrc(immsrc),   .regsrc(regsrc),
        .alucontrol(alucontrol), .bl_en(bl_en), .bx_en(bx_en)
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
