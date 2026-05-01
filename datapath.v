module datapath (
    input  wire        clk,
    input  wire        reset,
    input  wire        pcsrc,
    input  wire        regwrite,
    input  wire        memtoreg,
    input  wire        alusrc,
    input  wire [1:0]  immsrc,
    input  wire [1:0]  regsrc,
    input  wire [2:0]  alucontrol,
    input  wire        bl_en,       // Ingested BL explicit enable
    input  wire        bx_en,       // Ingested BX explicit enable
    input  wire [31:0] readdata,
    output wire [31:0] aluout,
    output wire [31:0] writedata,
    output wire [31:0] instr,
    output wire [3:0]  aluflags,
    output wire [31:0] pc,
    input  wire [3:0]  dbg_addr,
    output wire [31:0] dbg_data
);
    wire [31:0] pcnext, pcplus4, pcplus8;
    wire [31:0] rd1, rd2;
    wire [31:0] srcb_shifted, srcb;
    wire [31:0] extimm;
    wire [31:0] aluresult;
    wire [31:0] result;
    wire [3:0]  ra1_addr, ra2_addr;
    wire [3:0]  wa3_mux;
    wire [31:0] wd3_mux;

    flopr #(32) pc_reg (.clk(clk), .reset(reset), .d(pcnext), .q(pc));
    adder add4 (.a(pc), .b(32'd4), .y(pcplus4));
    adder add8 (.a(pc), .b(32'd8), .y(pcplus8));

    imem i_mem (.clk(clk),.addr(pc), .instr(instr));

    assign ra1_addr = regsrc[0] ? 4'd15        : instr[19:16];
    assign ra2_addr = regsrc[1] ? instr[15:12] : instr[3:0];

    // BL explicit override routing
    assign wa3_mux = bl_en ? 4'd14    : instr[15:12];
    assign wd3_mux = bl_en ? pcplus4  : result;

    regfile rf (
        .clk(clk),       .we3(regwrite),
        .ra1(ra1_addr),  .ra2(ra2_addr),
        .wa3(wa3_mux),   .wd3(wd3_mux),
        .r15(pcplus8),
        .rd1(rd1),       .rd2(rd2),
        .dbg_addr(dbg_addr), .dbg_data(dbg_data)
    );

    assign writedata = rd2;

    shifter shift_u (.din(rd2), .sh(instr[6:5]), .shamt(instr[11:7]), .dout(srcb_shifted));
    extend ext_u (.instr(instr[23:0]), .immsrc(immsrc), .extimm(extimm));

    assign srcb = bx_en ? rd2 : (alusrc ? extimm : srcb_shifted);

    alu alu_u (.a(rd1), .b(srcb), .alucontrol(alucontrol), .result(aluresult), .flags(aluflags));
    assign aluout = aluresult;

    assign result = memtoreg ? readdata : aluresult;

    // BX explicit override routing
    // If conditional branch passes (pcsrc=1) OR explicit BX triggers (bx_en=1), jump.
    assign pcnext = (pcsrc | bx_en) ? aluresult : pcplus4;
endmodule
