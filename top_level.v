module top_level (
    input  wire        clk,
    input  wire        reset,
    input  wire [3:0]  dbg_reg_sel,
	 input toggle_switch,
    output wire [31:0] dbg_reg_data,
    output wire [31:0] pc_out,
	 
	 output [6:0] hex0,
	 output [6:0] hex1,
	 output [6:0] hex2,
	 output [6:0] hex3
);
    wire [31:0] instr;
    wire [31:0] aluout, writedata, readdata;
    wire        pcsrc, regwrite, memwrite;
    wire        memtoreg, alusrc, bl_en, bx_en;
    wire [1:0]  immsrc, regsrc;
    wire [2:0]  alucontrol;
    wire [3:0]  aluflags;
	 
	 wire [31:0] internal_dbg_out;

    controller ctrl (
        .clk(clk),              .reset(reset),
        .op(instr[27:26]),      .funct(instr[25:20]),
        .rd(instr[15:12]),      .cond(instr[31:28]),
        .aluflags(aluflags),
        .pcsrc(pcsrc),          .regwrite(regwrite),
        .memwrite(memwrite),    .memtoreg(memtoreg),
        .alusrc(alusrc),        .immsrc(immsrc),
        .regsrc(regsrc),        .alucontrol(alucontrol),
        .bl_en(bl_en),          .bx_en(bx_en)
    );

    datapath dp (
        .clk(clk),              .reset(reset),
        .pcsrc(pcsrc),          .regwrite(regwrite),
        .memtoreg(memtoreg),    .alusrc(alusrc),
        .immsrc(immsrc),        .regsrc(regsrc),
        .alucontrol(alucontrol),.bl_en(bl_en),
        .bx_en(bx_en),
        .readdata(readdata),    .aluout(aluout),        
        .writedata(writedata),  .instr(instr),          
        .aluflags(aluflags),    .pc(pc_out),
        .dbg_addr(dbg_reg_sel), .dbg_data(dbg_reg_data)
    );

    dmem d_mem (
        .clk(clk),  .we(memwrite),
        .addr(aluout), .wd(writedata), .rd(readdata)
    );
	 wire [15:0] display_data;
	 
	 assign display_data = toggle_switch ? internal_dbg_out[31:16] : internal_dbg_out[15:0];
	 
	 hex_to_7seg asd1 (
			.hex_in(display_data[3:0]),						.seg_out(hex0)
			);
	 hex_to_7seg asd2 (
			.hex_in(display_data[7:4]),						.seg_out(hex1)
			);
	 hex_to_7seg asd3 (
			.hex_in(display_data[11:8]),						.seg_out(hex2)
			);
	 hex_to_7seg asd4 (
			.hex_in(display_data[15:12]),						.seg_out(hex3)
			);
endmodule
