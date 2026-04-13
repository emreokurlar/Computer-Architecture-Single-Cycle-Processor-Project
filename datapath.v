module datapath (
    input  wire        clk,
    input  wire        reset,
    // Control signals
    input  wire        pcsrc,
    input  wire        regwrite,
    input  wire        memtoreg,
    input  wire        alusrc,
    input  wire [1:0]  immsrc,
    input  wire [1:0]  regsrc,
    input  wire [2:0]  alucontrol,
    input  wire        link,
    // Data memory interface
    input  wire [31:0] readdata,    // data read from dmem
    output wire [31:0] aluout,      // memory address / ALU result
    output wire [31:0] writedata,   // data to write to dmem
    // To controller
    output wire [31:0] instr,       // current instruction word
    output wire [3:0]  aluflags,    // {N,Z,C,V} → condlogic
    // Observation ports
    output wire [31:0] pc,
    input  wire [3:0]  dbg_addr,
    output wire [31:0] dbg_data
);
    //----------------------------------------------------------
    // Wires
    //----------------------------------------------------------
    wire [31:0] pcnext, pcplus4, pcplus8;
    wire [31:0] rd1, rd2;
    wire [31:0] srcb_shifted, srcb;
    wire [31:0] extimm;
    wire [31:0] aluresult;
    wire [31:0] result;
    wire [3:0]  ra1_addr, ra2_addr;
    wire [3:0]  wa3_mux;
    wire [31:0] wd3_mux;

    //----------------------------------------------------------
    // PC register and PC arithmetic
    //----------------------------------------------------------
    flopr #(32) pc_reg (
        .clk(clk), .reset(reset), .d(pcnext), .q(pc)
    );
    adder add4 (.a(pc), .b(32'd4), .y(pcplus4));
    adder add8 (.a(pc), .b(32'd8), .y(pcplus8));

    //----------------------------------------------------------
    // Instruction memory
    //----------------------------------------------------------
    imem i_mem (.addr(pc), .instr(instr));

    //----------------------------------------------------------
    // Register file address muxes
    //   regsrc[0]=0: RA1 = Rn (instr[19:16])
    //   regsrc[0]=1: RA1 = R15          (branch: ALU = PC+8 + offset)
    //   regsrc[1]=0: RA2 = Rm (instr[3:0])
    //   regsrc[1]=1: RA2 = Rd (instr[15:12])  (STR: need data to store)
    //----------------------------------------------------------
    assign ra1_addr = regsrc[0] ? 4'd15        : instr[19:16];
    assign ra2_addr = regsrc[1] ? instr[15:12] : instr[3:0];

    // BL: write PC+4 to R14 instead of result to Rd
    assign wa3_mux = link ? 4'd14    : instr[15:12];
    assign wd3_mux = link ? pcplus4  : result;

    //----------------------------------------------------------
    // Register file
    //----------------------------------------------------------
    regfile rf (
        .clk(clk),       .we3(regwrite),
        .ra1(ra1_addr),  .ra2(ra2_addr),
        .wa3(wa3_mux),   .wd3(wd3_mux),
        .r15(pcplus8),
        .rd1(rd1),       .rd2(rd2),
        .dbg_addr(dbg_addr), .dbg_data(dbg_data)
    );

    // For STR, rd2 = Rd (the value to store, via regsrc[1]=1)
    assign writedata = rd2;

    //----------------------------------------------------------
    // Combinational barrel shifter (data-processing register mode)
    // sh    = instr[6:5]   (shift type)
    // shamt = instr[11:7]  (5-bit shift amount)
    //----------------------------------------------------------
    shifter shift_u (
        .din(rd2), .sh(instr[6:5]), .shamt(instr[11:7]),
        .dout(srcb_shifted)
    );

    //----------------------------------------------------------
    // Immediate extender
    //----------------------------------------------------------
    extend ext_u (
        .instr(instr[23:0]), .immsrc(immsrc), .extimm(extimm)
    );

    //----------------------------------------------------------
    // ALU source-B mux
    //   alusrc=0 → shifted register operand
    //   alusrc=1 → extended immediate
    //----------------------------------------------------------
    assign srcb = alusrc ? extimm : srcb_shifted;

    //----------------------------------------------------------
    // ALU
    //----------------------------------------------------------
    alu alu_u (
        .a(rd1), .b(srcb),
        .alucontrol(alucontrol),
        .result(aluresult), .flags(aluflags)
    );
    assign aluout = aluresult;

    //----------------------------------------------------------
    // Result mux: memory read or ALU result
    //----------------------------------------------------------
    assign result = memtoreg ? readdata : aluresult;

    //----------------------------------------------------------
    // Next-PC mux
    //   pcsrc=0: sequential (PC+4)
    //   pcsrc=1: ALU result (branch target or Rm for BX)
    //----------------------------------------------------------
    assign pcnext = pcsrc ? aluresult : pcplus4;
endmodule