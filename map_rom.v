module map_rom (
    input wire [7:0] addr,         // 8-bit address for 16x16 = 256 tiles
    output reg[1:0] data
);

    reg [1:0] mem [0:255];         // 256 entries for 16x16 map

    initial begin
        $readmemh("map.mem", mem);
    end

    always @(*) begin
        data = mem[addr];
    end

endmodule
