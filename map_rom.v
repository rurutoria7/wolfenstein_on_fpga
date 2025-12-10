`timescale 1ns / 1ps

// map_rom.v - Synthesizable map ROM using combinational logic
// 8x8 map for Wolfenstein raycaster
// 0 = empty, 1 = wall type 1, 2 = wall type 2, 3 = wall type 3

module map_rom (
    input wire [5:0] addr,         // 6-bit address for 8x8 = 64 tiles
    output reg [1:0] data
);

    // Combinational logic ROM (0 cycle read latency)
    // Y axis: y=0 is bottom, y=7 is top (anti-gravity direction)
    // Address format: {y[2:0], x[2:0]} where y=addr[5:3], x=addr[2:0]

    always @(*) begin
        case (addr)
            // y=7 (top border) - Row 0 in map.mem
            6'b111_000: data = 2'd1;  // (x=0, y=7)
            6'b111_001: data = 2'd1;  // (x=1, y=7)
            6'b111_010: data = 2'd1;  // (x=2, y=7)
            6'b111_011: data = 2'd1;  // (x=3, y=7)
            6'b111_100: data = 2'd1;  // (x=4, y=7)
            6'b111_101: data = 2'd1;  // (x=5, y=7)
            6'b111_110: data = 2'd1;  // (x=6, y=7)
            6'b111_111: data = 2'd1;  // (x=7, y=7)

            // y=6 - Row 1 in map.mem
            6'b110_000: data = 2'd1;  // (x=0, y=6)
            6'b110_001: data = 2'd0;  // (x=1, y=6)
            6'b110_010: data = 2'd0;  // (x=2, y=6)
            6'b110_011: data = 2'd0;  // (x=3, y=6)
            6'b110_100: data = 2'd0;  // (x=4, y=6)
            6'b110_101: data = 2'd0;  // (x=5, y=6)
            6'b110_110: data = 2'd0;  // (x=6, y=6)
            6'b110_111: data = 2'd1;  // (x=7, y=6)

            // y=5 - Row 2 in map.mem
            6'b101_000: data = 2'd1;  // (x=0, y=5)
            6'b101_001: data = 2'd0;  // (x=1, y=5)
            6'b101_010: data = 2'd0;  // (x=2, y=5)
            6'b101_011: data = 2'd1;  // (x=3, y=5) - internal wall
            6'b101_100: data = 2'd0;  // (x=4, y=5)
            6'b101_101: data = 2'd0;  // (x=5, y=5)
            6'b101_110: data = 2'd0;  // (x=6, y=5)
            6'b101_111: data = 2'd1;  // (x=7, y=5)

            // y=4 - Row 3 in map.mem
            6'b100_000: data = 2'd1;  // (x=0, y=4)
            6'b100_001: data = 2'd0;  // (x=1, y=4)
            6'b100_010: data = 2'd0;  // (x=2, y=4)
            6'b100_011: data = 2'd0;  // (x=3, y=4)
            6'b100_100: data = 2'd0;  // (x=4, y=4)
            6'b100_101: data = 2'd0;  // (x=5, y=4)
            6'b100_110: data = 2'd0;  // (x=6, y=4)
            6'b100_111: data = 2'd1;  // (x=7, y=4)

            // y=3 - Row 4 in map.mem
            6'b011_000: data = 2'd1;  // (x=0, y=3)
            6'b011_001: data = 2'd0;  // (x=1, y=3)
            6'b011_010: data = 2'd0;  // (x=2, y=3)
            6'b011_011: data = 2'd0;  // (x=3, y=3)
            6'b011_100: data = 2'd0;  // (x=4, y=3)
            6'b011_101: data = 2'd0;  // (x=5, y=3)
            6'b011_110: data = 2'd0;  // (x=6, y=3)
            6'b011_111: data = 2'd1;  // (x=7, y=3)

            // y=2 - Row 5 in map.mem
            6'b010_000: data = 2'd1;  // (x=0, y=2)
            6'b010_001: data = 2'd0;  // (x=1, y=2)
            6'b010_010: data = 2'd0;  // (x=2, y=2)
            6'b010_011: data = 2'd1;  // (x=3, y=2) - internal wall
            6'b010_100: data = 2'd0;  // (x=4, y=2)
            6'b010_101: data = 2'd0;  // (x=5, y=2)
            6'b010_110: data = 2'd0;  // (x=6, y=2)
            6'b010_111: data = 2'd1;  // (x=7, y=2)

            // y=1 - Row 6 in map.mem
            6'b001_000: data = 2'd1;  // (x=0, y=1)
            6'b001_001: data = 2'd0;  // (x=1, y=1)
            6'b001_010: data = 2'd0;  // (x=2, y=1)
            6'b001_011: data = 2'd0;  // (x=3, y=1)
            6'b001_100: data = 2'd0;  // (x=4, y=1)
            6'b001_101: data = 2'd0;  // (x=5, y=1)
            6'b001_110: data = 2'd0;  // (x=6, y=1)
            6'b001_111: data = 2'd1;  // (x=7, y=1)

            // y=0 (bottom border) - Row 7 in map.mem
            6'b000_000: data = 2'd1;  // (x=0, y=0)
            6'b000_001: data = 2'd1;  // (x=1, y=0)
            6'b000_010: data = 2'd1;  // (x=2, y=0)
            6'b000_011: data = 2'd1;  // (x=3, y=0)
            6'b000_100: data = 2'd1;  // (x=4, y=0)
            6'b000_101: data = 2'd1;  // (x=5, y=0)
            6'b000_110: data = 2'd1;  // (x=6, y=0)
            6'b000_111: data = 2'd1;  // (x=7, y=0)

            default: data = 2'd0;     // Empty space (safety default)
        endcase
    end

endmodule
