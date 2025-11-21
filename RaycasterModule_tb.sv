`timescale 1ns / 1ps

module RaycasterModule_tb;

    // Clock and reset
    logic clk;
    logic rst_n;
    logic frame_start;

    // Player inputs
    logic [15:0] inx, iny;
    logic [9:0] ina;

    // Map interface
    wire [9:0] map_x, map_y;
    logic map_hit;

    // Pixel output
    wire [7:0] px_x;
    wire [6:0] px_y;
    wire [7:0] color;
    wire px_valid;

    // Status
    wire frame_done;

    // DUT instantiation
    RaycasterModule dut (
        .clk(clk),
        .rst_n(rst_n),
        .frame_start(frame_start),
        .inx(inx),
        .iny(iny),
        .ina(ina),
        .map_x(map_x),
        .map_y(map_y),
        .map_hit(map_hit),
        .px_x(px_x),
        .px_y(px_y),
        .color(color),
        .px_valid(px_valid),
        .frame_done(frame_done)
    );

    // Clock generation: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    // State names for debugging
    localparam IDLE        = 3'd0;
    localparam PRECALC     = 3'd1;
    localparam VER_DDA     = 3'd2;
    localparam HOR_DDA     = 3'd3;
    localparam CALC_HEIGHT = 3'd4;
    localparam DRAW_COL    = 3'd5;
    localparam NEXT_COL    = 3'd6;

    function string state_name(input [2:0] s);
        case (s)
            IDLE:        return "IDLE";
            PRECALC:     return "PRECALC";
            VER_DDA:     return "VER_DDA";
            HOR_DDA:     return "HOR_DDA";
            CALC_HEIGHT: return "CALC_HEIGHT";
            DRAW_COL:    return "DRAW_COL";
            NEXT_COL:    return "NEXT_COL";
            default:     return "UNKNOWN";
        endcase
    endfunction

    // Test sequence
    initial begin
        $display("========================================");
        $display("RaycasterModule Testbench");
        $display("========================================");

        // Initialize
        rst_n = 0;
        frame_start = 0;
        inx = 0;
        iny = 0;
        ina = 0;
        map_hit = 0;

        // Reset sequence
        #20;
        rst_n = 1;
        #10;

        $display("\n--- Test 1: Looking Right (angle = 0) ---");
        test_precalc(16'd200, 16'd200, 10'd0);

        $display("\n--- Test 2: Looking Up (angle = 128, ~45 deg) ---");
        test_precalc(16'd300, 16'd300, 10'd128);

        $display("\n--- Test 3: Looking Left (angle = 512, 180 deg) ---");
        test_precalc(16'd400, 16'd400, 10'd512);

        $display("\n--- Test 4: Vertical Skip (angle = 256, 90 deg) ---");
        test_precalc(16'd500, 16'd500, 10'd256);

        $display("\n--- Test 5: Horizontal Skip (angle = 0, 0 deg) ---");
        test_precalc(16'd600, 16'd600, 10'd0);

        $display("\n========================================");
        $display("All tests completed!");
        $display("========================================");

        #100;
        $finish;
    end

    // Task: Test precalculation and state transition
    task test_precalc(input [15:0] px, input [15:0] py, input [9:0] pa);
        begin
            // Set inputs
            inx = px;
            iny = py;
            ina = pa;

            $display("Input: px=%0d, py=%0d, angle=%0d", px, py, pa);
            $display("  Initial state: %s", state_name(dut.state));

            // Trigger frame_start
            @(posedge clk);
            frame_start = 1;
            @(posedge clk);
            frame_start = 0;

            // Wait for PRECALC state
            wait(dut.state == PRECALC);
            $display("  State: %s", state_name(dut.state));

            // Wait one clock for precalc to complete
            @(posedge clk);
            @(posedge clk);

            // Check sampled values
            $display("  Sampled: x=%0d, y=%0d, a=%0d", dut.x, dut.y, dut.a);

            // Display Precalc outputs (directly from combinational logic)
            $display("  Precalc outputs:");
            $display("    current_ray_angle = %0d", dut.current_ray_angle);
            $display("    pc_vrx=%0d, pc_vry=%0d, pc_vxo=%0d, pc_vyo=%0d, pc_vskip=%0d",
                     $signed(dut.pc_vrx), $signed(dut.pc_vry),
                     $signed(dut.pc_vxo), $signed(dut.pc_vyo), dut.pc_vskip);
            $display("    pc_hrx=%0d, pc_hry=%0d, pc_hxo=%0d, pc_hyo=%0d, pc_hskip=%0d",
                     $signed(dut.pc_hrx), $signed(dut.pc_hry),
                     $signed(dut.pc_hxo), $signed(dut.pc_hyo), dut.pc_hskip);

            // Wait for VER_DDA state
            wait(dut.state == VER_DDA);
            $display("  State: %s", state_name(dut.state));

            // Display latched values
            $display("  Latched DDA values:");
            $display("    ver_rx=%0d, ver_ry=%0d, ver_xo=%0d, ver_yo=%0d, ver_skip=%0d",
                     $signed(dut.ver_rx), $signed(dut.ver_ry),
                     $signed(dut.ver_xo), $signed(dut.ver_yo), dut.ver_skip);
            $display("    hor_rx=%0d, hor_ry=%0d, hor_xo=%0d, hor_yo=%0d, hor_skip=%0d",
                     $signed(dut.hor_rx), $signed(dut.hor_ry),
                     $signed(dut.hor_xo), $signed(dut.hor_yo), dut.hor_skip);

            // Wait a few cycles
            repeat(5) @(posedge clk);

            // Reset for next test (manual reset)
            rst_n = 0;
            @(posedge clk);
            rst_n = 1;
            @(posedge clk);
        end
    endtask

    // Monitor state changes
    always @(posedge clk) begin
        if (rst_n && (dut.state !== dut.next_state)) begin
            // $display("  [%0t] State change: %s -> %s", $time, state_name(dut.state), state_name(dut.next_state));
        end
    end

endmodule
