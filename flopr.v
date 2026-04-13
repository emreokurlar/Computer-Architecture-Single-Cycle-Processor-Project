// =============================================================
// MODULE: flopr.v
// Parametric D Flip-Flop with Synchronous Active-High Reset
// Used as the Program Counter (PC) register in the datapath.
// =============================================================
module flopr #(parameter WIDTH = 32) (
    input  wire             clk,
    input  wire             reset,
    input  wire [WIDTH-1:0] d,      // next value
    output reg  [WIDTH-1:0] q       // current value
);
    always @(posedge clk) begin
        if (reset)
            q <= {WIDTH{1'b0}};
        else
            q <= d;
    end
endmodule