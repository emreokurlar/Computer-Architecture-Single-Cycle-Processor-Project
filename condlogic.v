module condlogic (
    input  wire        clk,
    input  wire        reset,
    input  wire [3:0]  cond,
    input  wire [3:0]  aluflagsIn,  // live ALU flags {N,Z,C,V}
    input  wire [1:0]  flagw,       // flag write enables from decoder
    input  wire        pcs,         // pre-gated signals from decoder
    input  wire        regw,
    input  wire        memw,
    output wire        pcsrc,       // gated outputs to datapath
    output wire        regwrite,
    output wire        memwrite
);
    reg [1:0] flags_NZ;             // stored N, Z
    reg [1:0] flags_CV;             // stored C, V

    wire [3:0] flags;
    wire       condex;

    assign flags = {flags_NZ, flags_CV};

    condcheck cc (
        .cond(cond),
        .flags(flags),
        .condex(condex)
    );

    // Synchronous flag registers
    always @(posedge clk) begin
        if (reset) begin
            flags_NZ <= 2'b00;
            flags_CV <= 2'b00;
        end else begin
            if (flagw[1] & condex) flags_NZ <= aluflagsIn[3:2]; // N, Z
            if (flagw[0] & condex) flags_CV <= aluflagsIn[1:0]; // C, V
        end
    end

    // Gate control outputs with condition
    assign pcsrc    = pcs  & condex;
    assign regwrite = regw & condex;
    assign memwrite = memw & condex;
endmodule
