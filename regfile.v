module regfile (
    input  wire        clk,
    input  wire        we3,
    input  wire [3:0]  ra1,
    input  wire [3:0]  ra2,
    input  wire [3:0]  wa3,
    input  wire [31:0] wd3,
    input  wire [31:0] r15,       // PC+8, written to rf[15] each cycle
    output wire [31:0] rd1,
    output wire [31:0] rd2,
    input  wire [3:0]  dbg_addr,
    output wire [31:0] dbg_data
);
    reg [31:0] rf [0:15];

    integer k;
    initial
        for (k = 0; k < 16; k = k + 1)
            rf[k] = 32'b0;

    always @(posedge clk) begin
        rf[15] <= r15;

        if (we3 && (wa3 != 4'd15))
            rf[wa3] <= wd3;
    end

    assign rd1      = rf[ra1];
    assign rd2      = rf[ra2];
    assign dbg_data = rf[dbg_addr];
endmodule