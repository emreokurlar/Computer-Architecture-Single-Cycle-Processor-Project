module mux2 #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] d0,     // select=0 input
    input  wire [WIDTH-1:0] d1,     // select=1 input
    input  wire             sel,
    output wire [WIDTH-1:0] y
);
    assign y = sel ? d1 : d0;
endmodule