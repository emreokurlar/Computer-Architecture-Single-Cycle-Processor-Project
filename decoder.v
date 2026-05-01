module decoder (
    input  wire [1:0] op,
    input  wire [5:0] funct,
    input  wire [3:0] rd,
    output reg  [1:0] flagw,
    output wire       pcs,
    output reg        regw,
    output reg        memw,
    output reg        memtoreg,
    output reg        alusrc,
    output reg  [1:0] immsrc,
    output reg  [1:0] regsrc,
    output reg  [2:0] alucontrol,
    output reg        bl_en,        // Replaces link
    output reg        bx_en         // Explicit BX enable
);
    reg branch;

    assign pcs   = branch | ((rd == 4'b1111) & regw);

    always @(*) begin
        flagw      = 2'b00;
        regw       = 1'b0;
        memw       = 1'b0;
        memtoreg   = 1'b0;
        alusrc     = 1'b0;
        immsrc     = 2'b00;
        regsrc     = 2'b00;
        alucontrol = 3'b000;
        branch     = 1'b0;
        bx_en      = 1'b0;
		  bl_en      = 1'b0;		

        case (op)
            2'b00: begin
                regw   = 1'b1;
                alusrc = funct[5];

                if (funct[5]) immsrc = 2'b00;

                case (funct[4:1])
                    4'b0100: alucontrol = 3'b000; 
                    4'b0010: alucontrol = 3'b001; 
                    4'b0000: alucontrol = 3'b010; 
                    4'b1100: alucontrol = 3'b011; 
                    4'b1101: alucontrol = 3'b101; 
                    4'b1010: begin                
                        alucontrol = 3'b001;
                        regw       = 1'b0;
                    end
                    4'b1001: begin                // BX Trap
                        bx_en      = 1'b1;        // Assert explicit enable
                        alucontrol = 3'b101;      // Force ALU to pass B
                        regw       = 1'b0;        // BX does not write to Register File directly
                    end
                    default: alucontrol = 3'b000;
                endcase

                if (funct[0]) begin
                    flagw[1] = 1'b1;
                    if (funct[4:1] == 4'b0100 || funct[4:1] == 4'b0010 || funct[4:1] == 4'b1010)
                        flagw[0] = 1'b1;
                end
            end

            2'b01: begin
                alusrc     = 1'b1;
                immsrc     = 2'b01;
                alucontrol = 3'b000;
                if (funct[0]) begin
                    regw     = 1'b1;
                    memtoreg = 1'b1;
                end else begin
                    memw   = 1'b1;
                    regsrc = 2'b10;
                end
            end

            2'b10: begin
                branch     = 1'b1;
                alusrc     = 1'b1;
                immsrc     = 2'b10;
                regsrc     = 2'b01;
                alucontrol = 3'b000;
                if (funct[4]) begin
					 regw = 1'b1; // BL
					 bl_en = 1'b1;
					 end
            end
            default: begin end
        endcase
    end
endmodule
