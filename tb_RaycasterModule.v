`timescale 1ns / 1ps

module tb_RaycasterModule;

    // =========================================================================
    // Test Parameters
    // =========================================================================
    parameter CLK_PERIOD = 10;  // 100MHz clock
    parameter SCREEN_HEIGHT = 120;
    parameter SCREEN_WIDTH = 160;
    parameter TILE_WIDTH = 64;

    // =========================================================================
    // DUT Signals
    // =========================================================================
    reg clk;
    reg rst_n;
    reg frame_start;

    // Player position and direction
    reg [15:0] inx;
    reg [15:0] iny;
    reg [9:0] ina;

    // Pixel output
    wire [7:0] px_x;
    wire [6:0] px_y;
    wire [11:0] color;
    wire px_valid;
    wire frame_done;

    // =========================================================================
    // Test Variables
    // =========================================================================
    integer pixel_count;
    integer error_count;
    integer wall_pixel_count;
    integer ceiling_pixel_count;
    integer floor_pixel_count;

    // Expected values for verification
    reg [6:0] expected_line_height;
    reg [6:0] expected_draw_begin;
    reg [6:0] expected_draw_end;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    RaycasterModule dut (
        .clk(clk),
        .rst_n(rst_n),
        .frame_start(frame_start),
        .inx(inx),
        .iny(iny),
        .ina(ina),
        .px_x(px_x),
        .px_y(px_y),
        .color(color),
        .px_valid(px_valid),
        .frame_done(frame_done)
    );

    // =========================================================================
    // Framebuffer Instantiation (for verification)
    // =========================================================================
    wire [31:0] fb_pixel_count;
    wire [31:0] fb_frame_count;

    framebuffer_sim #(
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .COLOR_BITS(12)
    ) framebuffer (
        .clk(clk),
        .rst_n(rst_n),
        .px_x(px_x),
        .px_y(px_y),
        .color(color),
        .px_valid(px_valid),
        .frame_start(frame_start),
        .frame_done(frame_done),
        .pixel_count(fb_pixel_count),
        .frame_count(fb_frame_count)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // =========================================================================
    // Test Stimulus
    // =========================================================================
    initial begin
        $display("=================================================================");
        $display("Starting RaycasterModule Testbench");
        $display("=================================================================");

        // Initialize
        rst_n = 0;
        frame_start = 0;
        inx = 0;
        iny = 0;
        ina = 0;
        pixel_count = 0;
        error_count = 0;
        wall_pixel_count = 0;
        ceiling_pixel_count = 0;
        floor_pixel_count = 0;

        // Reset
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        // =====================================================================
        // Test Case 1: Player at position (100, 100), looking right (angle = 0)
        // =====================================================================
        $display("\n-----------------------------------------------------------------");
        $display("Test Case 1: Player at (100, 100), looking right (angle = 0)");
        $display("-----------------------------------------------------------------");

        inx = 16'd100;  // Player X = 100
        iny = 16'd100;  // Player Y = 100
        ina = 10'd0;    // Angle = 0 (looking right)

        // Start frame
        frame_start = 1;
        #(CLK_PERIOD);
        frame_start = 0;

        // Wait for the first column to complete
        wait_for_column_done();

        // Verify pixel output for the first column
        $display("Test Case 1 completed");
        $display("Total pixels output: %d (expected 120)", pixel_count);
        $display("Wall pixels: %d", wall_pixel_count);
        $display("Ceiling pixels: %d", ceiling_pixel_count);
        $display("Floor pixels: %d", floor_pixel_count);

        if (pixel_count != 120) begin
            $display("ERROR: Expected 120 pixels, got %d", pixel_count);
            error_count = error_count + 1;
        end

        // Display framebuffer column
        framebuffer.display_column(8'd0);

        // Verify column completeness
        if (!framebuffer.verify_column(8'd0)) begin
            $display("ERROR: Column 0 is incomplete");
            error_count = error_count + 1;
        end

        // Reset counters for next test
        pixel_count = 0;
        wall_pixel_count = 0;
        ceiling_pixel_count = 0;
        floor_pixel_count = 0;

        // Reset DUT between tests
        #(CLK_PERIOD * 5);
        rst_n = 0;
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD * 5);

        // =====================================================================
        // Test Case 2: Player closer to wall
        // =====================================================================
        $display("\n-----------------------------------------------------------------");
        $display("Test Case 2: Player at (96, 100), looking right (closer to wall)");
        $display("-----------------------------------------------------------------");

        inx = 16'd96;   // Player X = 96 (4 units from tile boundary at 100)
        iny = 16'd100;  // Player Y = 100
        ina = 10'd0;    // Angle = 0 (looking right)

        // Start frame
        frame_start = 1;
        #(CLK_PERIOD);
        frame_start = 0;

        // Wait for the first column to complete
        wait_for_column_done();

        $display("Test Case 2 completed");
        $display("Total pixels output: %d (expected 120)", pixel_count);
        $display("Wall pixels: %d", wall_pixel_count);
        $display("Ceiling pixels: %d", ceiling_pixel_count);
        $display("Floor pixels: %d", floor_pixel_count);

        if (pixel_count != 120) begin
            $display("ERROR: Expected 120 pixels, got %d", pixel_count);
            error_count = error_count + 1;
        end

        // Reset counters for next test
        pixel_count = 0;
        wall_pixel_count = 0;
        ceiling_pixel_count = 0;
        floor_pixel_count = 0;

        // Reset DUT between tests
        #(CLK_PERIOD * 5);
        rst_n = 0;
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD * 5);

        // =====================================================================
        // Test Case 3: Player looking up (angle = 256)
        // =====================================================================
        $display("\n-----------------------------------------------------------------");
        $display("Test Case 3: Player at (100, 100), looking up (angle = 256)");
        $display("-----------------------------------------------------------------");

        inx = 16'd100;  // Player X = 100
        iny = 16'd100;  // Player Y = 100
        ina = 10'd256;  // Angle = 256 (90 degrees, looking up)

        // Start frame
        frame_start = 1;
        #(CLK_PERIOD);
        frame_start = 0;

        // Wait for the first column to complete
        wait_for_column_done();

        $display("Test Case 3 completed");
        $display("Total pixels output: %d (expected 120)", pixel_count);
        $display("Wall pixels: %d", wall_pixel_count);
        $display("Ceiling pixels: %d", ceiling_pixel_count);
        $display("Floor pixels: %d", floor_pixel_count);

        if (pixel_count != 120) begin
            $display("ERROR: Expected 120 pixels, got %d", pixel_count);
            error_count = error_count + 1;
        end

        // Reset counters for next test
        pixel_count = 0;
        wall_pixel_count = 0;
        ceiling_pixel_count = 0;
        floor_pixel_count = 0;

        // Reset DUT between tests
        #(CLK_PERIOD * 5);
        rst_n = 0;
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD * 5);

        // =====================================================================
        // Test Case 4: Player at corner looking diagonally (test for overflow)
        // =====================================================================
        $display("\n-----------------------------------------------------------------");
        $display("Test Case 4: Player at (80, 80), looking NE (angle = 192)");
        $display("Testing diagonal ray with large distance (overflow check)");
        $display("-----------------------------------------------------------------");

        inx = 16'd80;   // Player X = 80 (left side, tile 1)
        iny = 16'd80;   // Player Y = 80 (bottom side, tile 1)
        ina = 10'd192;  // Angle = 192 (between 90 and 180, looking NE direction)

        // Start frame
        frame_start = 1;
        #(CLK_PERIOD);
        frame_start = 0;

        // Wait for the first column to complete
        wait_for_column_done();

        $display("Test Case 4 completed");
        $display("Total pixels output: %d (expected 120)", pixel_count);
        $display("Wall pixels: %d", wall_pixel_count);
        $display("Ceiling pixels: %d", ceiling_pixel_count);
        $display("Floor pixels: %d", floor_pixel_count);

        if (pixel_count != 120) begin
            $display("ERROR: Expected 120 pixels, got %d", pixel_count);
            error_count = error_count + 1;
        end

        #(CLK_PERIOD * 10);

        // =====================================================================
        // Test Summary
        // =====================================================================
        $display("\n=================================================================");
        $display("Test Summary");
        $display("=================================================================");
        if (error_count == 0) begin
            $display("All tests PASSED!");
        end else begin
            $display("Tests FAILED with %d errors", error_count);
        end
        $display("=================================================================");

        // Print framebuffer statistics
        framebuffer.print_statistics();

        // Export first frame to PPM image (optional)
        // framebuffer.export_ppm("output_frame.ppm");

        #(CLK_PERIOD * 20);
        $finish;
    end

    // =========================================================================
    // Pixel Monitor - Count and verify pixels as they are output
    // =========================================================================
    always @(posedge clk) begin
        if (px_valid) begin
            pixel_count = pixel_count + 1;

            // Verify pixel coordinates
            if (px_x != 8'd0) begin
                $display("WARNING: px_x = %d (expected 0 for first column)", px_x);
            end

            if (px_y != pixel_count - 1) begin
                $display("ERROR: px_y = %d (expected %d)", px_y, pixel_count - 1);
                error_count = error_count + 1;
            end

            // Count pixel types based on color
            // COLOR_CEILING   = 12'h468 (Dark blue-gray)
            // COLOR_WALL_H    = 12'hFFF (White for horizontal wall)
            // COLOR_WALL_V    = 12'hCCC (Light gray for vertical wall)
            // COLOR_FLOOR     = 12'h888 (Medium gray)

            if (color == 12'h468) begin
                ceiling_pixel_count = ceiling_pixel_count + 1;
            end else if (color == 12'hFFF || color == 12'hCCC) begin
                wall_pixel_count = wall_pixel_count + 1;
            end else if (color == 12'h888) begin
                floor_pixel_count = floor_pixel_count + 1;
            end else begin
                $display("WARNING: Unknown color at px_y=%d: 0x%03h", px_y, color);
            end

            // Display pixel info (commented out to reduce clutter)
            // $display("Pixel %3d: px_x=%3d, px_y=%3d, color=0x%03h",
            //          pixel_count, px_x, px_y, color);
        end
    end

    // =========================================================================
    // Task: Wait for one column to complete
    // =========================================================================
    task wait_for_column_done;
        begin
            // Wait for Draw_col state to start
            wait (dut.state == 3'd5);  // DRAW_COL state
            $display("Entered DRAW_COL state at time %t", $time);

            // Wait for Draw_col to finish
            wait (dut.draw_col_inst.done == 1'b1);
            $display("Draw_col completed at time %t", $time);

            // Wait one more cycle
            #(CLK_PERIOD);
        end
    endtask

    // =========================================================================
    // Height Calculation Verification Monitor
    // =========================================================================
    always @(posedge clk) begin
        if (dut.state == 3'd4) begin  // CALC_HEIGHT state
            // Capture the Expression module outputs
            $display("\n--- Height Calculation (CALC_HEIGHT state) ---");
            $display("Time: %t", $time);
            $display("Vertical DDA:   vdis = %d, v_hit = %b", dut.vdis, dut.ver_dda_hit);
            $display("Horizontal DDA: hdis = %d, h_hit = %b", dut.hdis, dut.hor_dda_hit);
            $display("Expression outputs:");
            $display("  line_height = %d", dut.expr_line_height);
            $display("  draw_begin  = %d", dut.expr_draw_begin);
            $display("  draw_end    = %d", dut.expr_draw_end);
            $display("  is_horizontal_wall = %b", dut.expr_is_horizontal);

            // Verify that draw_begin < draw_end
            if (dut.expr_draw_begin >= dut.expr_draw_end) begin
                $display("ERROR: draw_begin (%d) >= draw_end (%d)",
                         dut.expr_draw_begin, dut.expr_draw_end);
                error_count = error_count + 1;
            end

            // Verify that line_height is reasonable (1 to 120)
            if (dut.expr_line_height < 1 || dut.expr_line_height > 120) begin
                $display("WARNING: line_height (%d) is out of reasonable range [1, 120]",
                         dut.expr_line_height);
            end

            // Verify draw_begin and draw_end are within screen bounds
            if (dut.expr_draw_begin >= 120) begin
                $display("ERROR: draw_begin (%d) >= screen height (120)", dut.expr_draw_begin);
                error_count = error_count + 1;
            end

            if (dut.expr_draw_end > 120) begin
                $display("ERROR: draw_end (%d) > screen height (120)", dut.expr_draw_end);
                error_count = error_count + 1;
            end

            // Verify centering: draw_begin should be approximately 60 - line_height/2
            expected_draw_begin = 7'd60 - (dut.expr_line_height >> 1);
            expected_draw_end = 7'd60 + (dut.expr_line_height >> 1);

            if (dut.expr_draw_begin != expected_draw_begin) begin
                $display("ERROR: draw_begin = %d, expected %d",
                         dut.expr_draw_begin, expected_draw_begin);
                error_count = error_count + 1;
            end

            if (dut.expr_draw_end != expected_draw_end) begin
                $display("ERROR: draw_end = %d, expected %d",
                         dut.expr_draw_end, expected_draw_end);
                error_count = error_count + 1;
            end

            $display("-----------------------------------------------\n");
        end
    end

    // =========================================================================
    // Draw_col Signal Sequence Verification Monitor
    // =========================================================================
    reg [6:0] last_px_y;
    reg first_pixel;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_px_y = 0;
            first_pixel = 1;
        end else begin
            if (dut.draw_col_inst.state == 2'b00) begin  // IDLE
                first_pixel = 1;
            end else if (px_valid) begin
                // Verify that px_y increments sequentially
                if (!first_pixel) begin
                    if (px_y != last_px_y + 1) begin
                        $display("ERROR: px_y sequence broken: last=%d, current=%d (time=%t)",
                                 last_px_y, px_y, $time);
                        error_count = error_count + 1;
                    end
                end else begin
                    // First pixel should start at row 0
                    if (px_y != 0) begin
                        $display("ERROR: First pixel px_y = %d (expected 0) (time=%t)",
                                 px_y, $time);
                        error_count = error_count + 1;
                    end
                    first_pixel = 0;
                end
                last_px_y = px_y;
            end
        end
    end

    // =========================================================================
    // State Transition Monitor (for debugging)
    // =========================================================================
    reg [2:0] last_state;

    initial begin
        last_state = 3'd0;
    end

    always @(posedge clk) begin
        if (dut.state != last_state) begin
            case (dut.state)
                3'd0: $display("[%t] State: IDLE", $time);
                3'd1: $display("[%t] State: PRECALC", $time);
                3'd2: $display("[%t] State: VER_DDA", $time);
                3'd3: $display("[%t] State: HOR_DDA", $time);
                3'd4: $display("[%t] State: CALC_HEIGHT", $time);
                3'd5: $display("[%t] State: DRAW_COL", $time);
                3'd6: $display("[%t] State: NEXT_COL", $time);
                default: $display("[%t] State: UNKNOWN (%d)", $time, dut.state);
            endcase
            last_state = dut.state;
        end
    end

    // =========================================================================
    // Timeout Watchdog
    // =========================================================================
    initial begin
        #(CLK_PERIOD * 100000);  // 1ms timeout
        $display("ERROR: Simulation timeout!");
        $display("Last state: %d", dut.state);
        $display("Pixel count: %d", pixel_count);
        $finish;
    end

endmodule
