module d_ff #(parameter WIDTH = 32) (
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