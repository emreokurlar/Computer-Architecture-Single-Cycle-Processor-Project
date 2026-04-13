module top_level (
    input  wire        clk,
    input  wire        reset,
    // Debug / FPGA display interface
    input  wire [3:0]  dbg_reg_sel,
    output wire [31:0] dbg_reg_data,
    output wire [31:0] pc_out
);
    //----------------------------------------------------------
    // Internal interconnect
    //----------------------------------------------------------
    wire [31:0] instr;
    wire [31:0] aluout, writedata, readdata;
    wire        pcsrc, regwrite, memwrite;
    wire        memtoreg, alusrc, link;
    wire [1:0]  immsrc, regsrc;
    wire [2:0]  alucontrol;
    wire [3:0]  aluflags;

    //----------------------------------------------------------
    // Controller
    //----------------------------------------------------------
    controller ctrl (
        .clk(clk),              .reset(reset),
        .op(instr[27:26]),      .funct(instr[25:20]),
        .rd(instr[15:12]),      .cond(instr[31:28]),
        .aluflags(aluflags),
        .pcsrc(pcsrc),          .regwrite(regwrite),
        .memwrite(memwrite),    .memtoreg(memtoreg),
        .alusrc(alusrc),        .immsrc(immsrc),
        .regsrc(regsrc),        .alucontrol(alucontrol),
        .link(link)
    );

    //----------------------------------------------------------
    // Datapath
    //----------------------------------------------------------
    datapath dp (
        .clk(clk),              .reset(reset),
        .pcsrc(pcsrc),          .regwrite(regwrite),
        .memtoreg(memtoreg),    .alusrc(alusrc),
        .immsrc(immsrc),        .regsrc(regsrc),
        .alucontrol(alucontrol), .link(link),
        .readdata(readdata),
        .aluout(aluout),        .writedata(writedata),
        .instr(instr),          .aluflags(aluflags),
        .pc(pc_out),
        .dbg_addr(dbg_reg_sel), .dbg_data(dbg_reg_data)
    );

    //----------------------------------------------------------
    // Data Memory
    //----------------------------------------------------------
    dmem d_mem (
        .clk(clk),  .we(memwrite),
        .addr(aluout), .wd(writedata), .rd(readdata)
    );
endmodule