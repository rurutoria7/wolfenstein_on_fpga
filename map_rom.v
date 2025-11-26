`timescale 1ns / 1ps

module map_rom (
    input wire [5:0] addr,         // 6-bit address for 8x8 = 64 tiles
    output reg[1:0] data
);

    reg [1:0] mem [0:63];          // 64 entries for 8x8 map

    initial begin
        $readmemh("map.mem", mem);
    end

    always @(*) begin
        data = mem[addr];
    end

endmodule
