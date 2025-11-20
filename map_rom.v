module map_rom (
    input wire[5:0] addr,
    output reg[1:0] data
);

    reg[1:0] mem [0:63];

    initial begin
        $readmemh("map.mem", mem);
    end

    always @(*) begin
        data = mem[addr];
    end

endmodule
