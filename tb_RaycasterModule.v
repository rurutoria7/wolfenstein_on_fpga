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

    // Variables for rotation test
    integer frame_num;
    integer angle_step;
    reg [15:0] current_angle;

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
        // Test Case: Player rotates 360 degrees at fixed position
        // Generate 10 frames covering full rotation
        // =====================================================================
        $display("\n-----------------------------------------------------------------");
        $display("Test Case: Player rotating 360 degrees at (100, 100)");
        $display("Generating 10 frames, angle increment = 102.4 degrees per frame");
        $display("-----------------------------------------------------------------");

        // Fixed player position
        inx = 16'd100;  // Player X = 100
        iny = 16'd100;  // Player Y = 100

        // Generate 10 frames with rotation
        // Full rotation = 1024 (360 degrees), so each frame rotates by 1024/10 = 102.4
        // Using integer division: 1024/10 = 102
        angle_step = 102;  // Approximately 36 degrees per frame

        for (frame_num = 0; frame_num < 10; frame_num = frame_num + 1) begin
            current_angle = frame_num * angle_step;
            ina = current_angle[9:0];  // Set angle (10-bit)

            $display("\n--- Frame %d: angle = %d (%.1f degrees) ---",
                     frame_num, ina, (ina * 360.0) / 1024.0);

            // Start frame
            frame_start = 1;
            #(CLK_PERIOD);
            frame_start = 0;

            // Wait for frame to complete
            $display("Waiting for frame_done signal...");
            wait (frame_done == 1'b1);
            $display("Frame %d rendering completed at time %t", frame_num, $time);

            // Wait a few cycles for framebuffer to process
            #(CLK_PERIOD * 10);

            // Verify pixel count
            $display("Frame %d - Total pixels output: %d (expected %d)",
                     frame_num, pixel_count, SCREEN_WIDTH * SCREEN_HEIGHT);

            if (pixel_count != SCREEN_WIDTH * SCREEN_HEIGHT) begin
                $display("ERROR: Frame %d - Expected %d pixels, got %d",
                         frame_num, SCREEN_WIDTH * SCREEN_HEIGHT, pixel_count);
                error_count = error_count + 1;
            end

            // Export frame to PPM image with frame number
            case (frame_num)
                0: framebuffer.export_ppm("output_frame_00.ppm");
                1: framebuffer.export_ppm("output_frame_01.ppm");
                2: framebuffer.export_ppm("output_frame_02.ppm");
                3: framebuffer.export_ppm("output_frame_03.ppm");
                4: framebuffer.export_ppm("output_frame_04.ppm");
                5: framebuffer.export_ppm("output_frame_05.ppm");
                6: framebuffer.export_ppm("output_frame_06.ppm");
                7: framebuffer.export_ppm("output_frame_07.ppm");
                8: framebuffer.export_ppm("output_frame_08.ppm");
                9: framebuffer.export_ppm("output_frame_09.ppm");
            endcase
            $display("Exporting frame %d", frame_num);

            // Reset counters for next frame
            pixel_count = 0;
            wall_pixel_count = 0;
            ceiling_pixel_count = 0;
            floor_pixel_count = 0;

            // Brief delay between frames
            #(CLK_PERIOD * 5);
        end

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
    reg [7:0] last_col_x;
    reg [6:0] expected_row_y;

    initial begin
        last_col_x = 8'd0;
        expected_row_y = 7'd0;
    end

    always @(posedge clk) begin
        if (px_valid) begin
            pixel_count = pixel_count + 1;

            // Check if we moved to a new column
            if (px_x != last_col_x) begin
                if (expected_row_y != 7'd0) begin
                    $display("Column %d completed with %d rows", last_col_x, expected_row_y);
                end
                expected_row_y = 7'd0;
                last_col_x = px_x;
            end

            // Verify that rows increment sequentially within a column
            if (px_y != expected_row_y) begin
                $display("ERROR: px_y = %d (expected %d) in column %d",
                         px_y, expected_row_y, px_x);
                error_count = error_count + 1;
            end
            expected_row_y = px_y + 1;

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
                $display("WARNING: Unknown color at (x=%d, y=%d): 0x%03h",
                         px_x, px_y, color);
            end

            // Display pixel info every 1000 pixels to track progress
            if (pixel_count % 1000 == 0) begin
                $display("Progress: %d pixels rendered (col=%d, row=%d)",
                         pixel_count, px_x, px_y);
            end
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
    // Task: Wait for N columns to complete
    // =========================================================================
    task wait_for_n_columns;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                $display("\n--- Waiting for column %d ---", i);

                // Wait for PRECALC state
                wait (dut.state == 3'd1);  // PRECALC state
                $display("[Col %d] Time %t: Entered PRECALC state", i, $time);
                $display("[Col %d] col_count = %d, current_ray_angle = %d",
                         i, dut.col_count, dut.current_ray_angle);

                // Wait for VER_DDA state
                wait (dut.state == 3'd2);  // VER_DDA state
                $display("[Col %d] Time %t: Entered VER_DDA state", i, $time);

                // Wait for HOR_DDA state
                wait (dut.state == 3'd3);  // HOR_DDA state
                $display("[Col %d] Time %t: Entered HOR_DDA state", i, $time);

                // Wait for CALC_HEIGHT state
                wait (dut.state == 3'd4);  // CALC_HEIGHT state
                $display("[Col %d] Time %t: Entered CALC_HEIGHT state", i, $time);

                // Wait for DRAW_COL state
                wait (dut.state == 3'd5);  // DRAW_COL state
                $display("[Col %d] Time %t: Entered DRAW_COL state", i, $time);

                // Wait for Draw_col to finish
                wait (dut.draw_col_inst.done == 1'b1);
                $display("[Col %d] Time %t: Draw_col completed", i, $time);

                // Wait for NEXT_COL state
                wait (dut.state == 3'd6);  // NEXT_COL state
                $display("[Col %d] Time %t: Entered NEXT_COL state", i, $time);

                // Wait one more cycle
                #(CLK_PERIOD);
            end
            $display("\n--- All %d columns completed ---\n", n);
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
        #(CLK_PERIOD * 10000000);  // 100ms timeout (enough for full frame)
        $display("ERROR: Simulation timeout!");
        $display("Last state: %d", dut.state);
        $display("Pixel count: %d", pixel_count);
        $display("Column count: %d", dut.col_count);
        $finish;
    end

endmodule
