`timescale 1ns / 1ps

module RaycasterModule (
    input wire clk,
    input wire rst_n,
    input wire frame_start,

    // Player position and direction
    input wire [9:0] inx,          // Player X position (0-1023)
    input wire [9:0] iny,          // Player Y position (0-1023)
    input wire [9:0] ina,          // Player angle (0-1023, maps to 0-2�)

    // Map interface
    output reg [9:0] map_x,        // Map query X
    output reg [9:0] map_y,        // Map query Y
    input wire map_hit,            // Map returns hit (1 = wall)

    // Pixel output
    output reg [7:0] px_x,         // Pixel X coordinate (0-159)
    output reg [6:0] px_y,         // Pixel Y coordinate (0-119)
    output reg [7:0] color,        // Pixel color
    output reg px_valid,           // Pixel output valid


    // Status
    output reg frame_done
);

    // Parameters
    parameter SCREEN_WIDTH = 160;
    parameter SCREEN_HEIGHT = 120;
    parameter CELL_SIZE = 64;      // Map cell size in position units
    parameter MAX_DEPTH = 8;       // Maximum ray depth (number of cells)

    // FSM States
    localparam IDLE         = 3'd0;
    localparam PRECALC      = 3'd1;
    localparam VER_DDA      = 3'd2;
    localparam HOR_DDA      = 3'd3;
    localparam CALC_HEIGHT  = 3'd4;
    localparam DRAW_COL     = 3'd5;
    localparam NEXT_COL     = 3'd6;

    reg [2:0] state, next_state;

    // Internal registers for current ray
    reg [9:0] x, y, a;             // Current player position and angle
    reg signed [15:0] rx, ry;      // Ray position (signed for calculations)
    reg signed [15:0] xo, yo;      // Ray offset per step
    reg [7:0] col_count;           // Current column being rendered (0-159)
    reg [6:0] row_count;           // Current row in column (0-119)

    // Distance and height calculation
    reg signed [31:0] vdis;        // Vertical wall distance
    reg signed [31:0] hdis;        // Horizontal wall distance
    reg signed [31:0] final_dis;   // Final distance (minimum of vdis, hdis)
    reg [15:0] wall_height;        // Calculated wall height
    reg [6:0] line_off;            // Line offset from center
    reg [6:0] line_height;         // Line height to draw

    // Vertical DDA state
    reg signed [15:0] ver_rx, ver_ry;
    reg signed [15:0] ver_xo, ver_yo;
    reg [3:0] ver_depth;
    reg ver_skip;

    // Horizontal DDA state
    reg signed [15:0] hor_rx, hor_ry;
    reg signed [15:0] hor_xo, hor_yo;
    reg [3:0] hor_depth;
    reg hor_skip;

    // PRECALC done flag
    reg precalc_done;
    reg [3:0] precalc_stage;

    // Ray angle for current column
    reg signed [10:0] ray_angle;   // Signed 11-bit for angle calculation

    // Color determination
    reg is_horizontal_wall;

    //=======================================================================
    // State Register
    //=======================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    //=======================================================================
    // Next State Logic
    //=======================================================================
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (frame_start)
                    next_state = PRECALC;
            end

            PRECALC: begin
                if (precalc_done)
                    next_state = VER_DDA;
            end

            VER_DDA: begin
                if (map_hit || ver_depth >= MAX_DEPTH || ver_skip)
                    next_state = HOR_DDA;
            end

            HOR_DDA: begin
                if (map_hit || hor_depth >= MAX_DEPTH || hor_skip)
                    next_state = CALC_HEIGHT;
            end

            CALC_HEIGHT: begin
                next_state = DRAW_COL;
            end

            DRAW_COL: begin
                if (row_count >= SCREEN_HEIGHT - 1)
                    next_state = NEXT_COL;
            end

            NEXT_COL: begin
                if (col_count >= SCREEN_WIDTH - 1)
                    next_state = IDLE;
                else
                    next_state = PRECALC;
            end

            default: next_state = IDLE;
        endcase
    end

    //=======================================================================
    // Datapath Logic
    //=======================================================================

    // IDLE state: Wait for frame start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 0;
            y <= 0;
            a <= 0;
            col_count <= 0;
            frame_done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    frame_done <= 0;
                    if (frame_start) begin
                        x <= inx;
                        y <= iny;
                        a <= ina;
                        col_count <= 0;
                    end
                end

                NEXT_COL: begin
                    if (col_count >= SCREEN_WIDTH - 1) begin
                        frame_done <= 1;
                        col_count <= 0;
                    end else begin
                        col_count <= col_count + 1;
                        // Update ray angle for next column
                        // FOV is typically 60 degrees, so we adjust angle based on column
                        // This is a simplified version; actual implementation needs FOV calculation
                    end
                end
            endcase
        end
    end

    // PRECALC state: Pre-calculate ray parameters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            precalc_done <= 0;
            precalc_stage <= 0;
            ray_angle <= 0;
            ver_skip <= 0;
            hor_skip <= 0;
        end else begin
            if (state == PRECALC) begin
                // Simplified precalculation
                // TODO: Implement proper trigonometric calculations using LUT
                // For now, use placeholder logic

                // Calculate ray angle based on column
                // ray_angle = a + (col - SCREEN_WIDTH/2) * FOV / SCREEN_WIDTH
                ray_angle <= $signed({1'b0, a}) + $signed(col_count) - $signed(SCREEN_WIDTH/2);

                // Initialize vertical ray parameters
                // TODO: Implement proper aTan calculation from LUT
                ver_rx <= x;
                ver_ry <= y;
                ver_xo <= 16'sd64;   // Placeholder
                ver_yo <= 16'sd64;   // Placeholder
                ver_depth <= 0;
                ver_skip <= 0;       // TODO: Check if ray_angle makes vertical check unnecessary

                // Initialize horizontal ray parameters
                // TODO: Implement proper nTan calculation from LUT
                hor_rx <= x;
                hor_ry <= y;
                hor_xo <= 16'sd64;   // Placeholder
                hor_yo <= 16'sd64;   // Placeholder
                hor_depth <= 0;
                hor_skip <= 0;       // TODO: Check if ray_angle makes horizontal check unnecessary

                precalc_done <= 1;
            end else begin
                precalc_done <= 0;
            end
        end
    end

    // VER_DDA state: Vertical line DDA
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vdis <= 0;
        end else begin
            if (state == VER_DDA && !ver_skip) begin
                if (!map_hit && ver_depth < MAX_DEPTH) begin
                    // Step ray
                    ver_rx <= ver_rx + ver_xo;
                    ver_ry <= ver_ry + ver_yo;
                    ver_depth <= ver_depth + 1;

                    // Query map
                    map_x <= ver_rx[15:6];  // Divide by 64 to get cell coordinate
                    map_y <= ver_ry[15:6];
                end else begin
                    // Calculate distance
                    // vdis = sqrt((ver_rx - x)^2 + (ver_ry - y)^2)
                    // Simplified: use Manhattan distance or approximate
                    vdis <= (ver_rx - $signed({6'd0, x})) * (ver_rx - $signed({6'd0, x})) +
                            (ver_ry - $signed({6'd0, y})) * (ver_ry - $signed({6'd0, y}));
                end
            end
        end
    end

    // HOR_DDA state: Horizontal line DDA
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hdis <= 0;
            is_horizontal_wall <= 0;
        end else begin
            if (state == HOR_DDA && !hor_skip) begin
                if (!map_hit && hor_depth < MAX_DEPTH) begin
                    // Step ray
                    hor_rx <= hor_rx + hor_xo;
                    hor_ry <= hor_ry + hor_yo;
                    hor_depth <= hor_depth + 1;

                    // Query map
                    map_x <= hor_rx[15:6];  // Divide by 64 to get cell coordinate
                    map_y <= hor_ry[15:6];
                end else begin
                    // Calculate distance
                    hdis <= (hor_rx - $signed({6'd0, x})) * (hor_rx - $signed({6'd0, x})) +
                            (hor_ry - $signed({6'd0, y})) * (hor_ry - $signed({6'd0, y}));
                end
            end

            if (state == CALC_HEIGHT) begin
                // Choose minimum distance
                if (vdis < hdis || hor_skip) begin
                    final_dis <= vdis;
                    is_horizontal_wall <= 0;
                end else begin
                    final_dis <= hdis;
                    is_horizontal_wall <= 1;
                end
            end
        end
    end

    // CALC_HEIGHT state: Calculate wall height
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line_height <= 0;
            line_off <= 0;
        end else begin
            if (state == CALC_HEIGHT) begin
                // height = SCREEN_HEIGHT / (distance / constant)
                // Simplified calculation
                if (final_dis > 0) begin
                    // Prevent division by zero and calculate wall height
                    // This is a placeholder - needs proper implementation
                    // wall_height should be inversely proportional to distance
                    if (final_dis < 32'd10000)
                        line_height <= 7'd120;  // Very close
                    else if (final_dis < 32'd40000)
                        line_height <= 7'd60;
                    else if (final_dis < 32'd90000)
                        line_height <= 7'd30;
                    else
                        line_height <= 7'd10;

                    // Center the line
                    line_off <= (SCREEN_HEIGHT - line_height) >> 1;
                end else begin
                    line_height <= 0;
                    line_off <= 0;
                end

                row_count <= 0;
            end
        end
    end

    // DRAW_COL state: Output pixels for current column
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            px_x <= 0;
            px_y <= 0;
            color <= 0;
            px_valid <= 0;
        end else begin
            if (state == DRAW_COL) begin
                px_x <= col_count;
                px_y <= row_count;
                px_valid <= 1;

                // Determine color based on position
                if (row_count < line_off) begin
                    // Ceiling
                    color <= 8'h40;  // Dark gray
                end else if (row_count < line_off + line_height) begin
                    // Wall
                    if (is_horizontal_wall)
                        color <= 8'hFF;  // White for horizontal walls
                    else
                        color <= 8'hC0;  // Light gray for vertical walls
                end else begin
                    // Floor
                    color <= 8'h80;  // Medium gray
                end

                row_count <= row_count + 1;
            end else begin
                px_valid <= 0;
            end
        end
    end

endmodule
