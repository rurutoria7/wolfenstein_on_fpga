`timescale 1ns / 1ps

module RaycasterModule (
    input wire clk,
    input wire rst_n,
    input wire frame_start,

    // Player position and direction
    input wire [15:0] inx,         // Player X position (16-bit world coords)
    input wire [15:0] iny,         // Player Y position (16-bit world coords)
    input wire [9:0] ina,          // Player angle (0-1023, maps to 0-2π)

    // Pixel output
    output wire [7:0] px_x,        // Pixel X coordinate (0-159)
    output wire [6:0] px_y,        // Pixel Y coordinate (0-119)
    output wire [11:0] color,      // Pixel color (RGB444 format)
    output wire px_valid,          // Pixel output valid


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
    reg [15:0] x, y;               // Current player position (16-bit world coords)
    reg [9:0] a;                   // Current player angle
    reg [7:0] col_count;           // Current column being rendered (0-159)

    // PRECALC done flag
    reg precalc_done;

    // Ray angle for current column (computed from player angle + FOV offset)
    wire [9:0] current_ray_angle;
    assign current_ray_angle = a + (col_count - (SCREEN_WIDTH / 2)) * 2;
    // assign current_ray_angle = a; // Simplified for now

    // Precalc module outputs
    wire signed [15:0] pc_vrx, pc_vry, pc_vxo, pc_vyo;
    wire signed [15:0] pc_hrx, pc_hry, pc_hxo, pc_hyo;
    wire pc_vskip, pc_hskip;

    // Wire connections for Expression module inputs
    wire signed [31:0] vdis = ver_dda_dis;
    wire signed [31:0] hdis = hor_dda_dis;

    // Instantiate Precalc module
    Precalc #(
        .TILE_WIDTH(CELL_SIZE),
        .FRAC_BITS(7)
    ) precalc_inst (
        .px(x),
        .py(y),
        .ra(current_ray_angle),
        .vrx(pc_vrx),
        .vry(pc_vry),
        .vxo(pc_vxo),
        .vyo(pc_vyo),
        .vskip(pc_vskip),
        .hrx(pc_hrx),
        .hry(pc_hry),
        .hxo(pc_hxo),
        .hyo(pc_hyo),
        .hskip(pc_hskip)
    );

    // VerticalDDA module outputs
    wire ver_dda_done, ver_dda_hit;
    wire [31:0] ver_dda_dis;

    // HorizontalDDA module outputs
    wire hor_dda_done, hor_dda_hit;
    wire [31:0] hor_dda_dis;

    // Instantiate RayDDA for vertical grid lines
    RayDDA #(
        .TILE_WIDTH(CELL_SIZE),
        .MAX_DEPTH(MAX_DEPTH)
    ) ver_dda_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(state == PRECALC && precalc_done),
        .init_rx(pc_vrx),
        .init_ry(pc_vry),
        .step_x(pc_vxo),
        .step_y(pc_vyo),
        .skip(pc_vskip),
        .px(x),
        .py(y),
        .dis(ver_dda_dis),
        .done(ver_dda_done),
        .hit(ver_dda_hit)
    );

    // Instantiate RayDDA for horizontal grid lines
    RayDDA #(
        .TILE_WIDTH(CELL_SIZE),
        .MAX_DEPTH(MAX_DEPTH)
    ) hor_dda_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(state == VER_DDA && ver_dda_done),
        .init_rx(pc_hrx),
        .init_ry(pc_hry),
        .step_x(pc_hxo),
        .step_y(pc_hyo),
        .skip(pc_hskip),
        .px(x),
        .py(y),
        .dis(hor_dda_dis),
        .done(hor_dda_done),
        .hit(hor_dda_hit)
    );

    // Expression module outputs
    wire [6:0] expr_line_height;
    wire [6:0] expr_draw_begin;
    wire [6:0] expr_draw_end;
    wire expr_is_horizontal;

    // Instantiate Expression module (combinational logic)
    Expression #(
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .TILE_WIDTH(CELL_SIZE)
    ) expr_inst (
        .ray_angle(current_ray_angle),
        .player_angle(a),
        .vdis(vdis),
        .hdis(hdis),
        .v_hit(ver_dda_hit),
        .h_hit(hor_dda_hit),
        .line_height(expr_line_height),
        .draw_begin(expr_draw_begin),
        .draw_end(expr_draw_end),
        .is_horizontal_wall(expr_is_horizontal)
    );

    // Draw_col module outputs
    wire draw_col_done;

    // Instantiate Draw_col module (sequential logic)
    Draw_col #(
        .SCREEN_HEIGHT(SCREEN_HEIGHT)
    ) draw_col_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(state == CALC_HEIGHT),
        .draw_begin(expr_draw_begin),
        .draw_end(expr_draw_end),
        .col_x(col_count),
        .is_horizontal_wall(expr_is_horizontal),
        .px_x(px_x),
        .px_y(px_y),
        .color(color),
        .px_valid(px_valid),
        .done(draw_col_done)
    );

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
                if (ver_dda_done)
                    next_state = HOR_DDA;
            end

            HOR_DDA: begin
                if (hor_dda_done)
                    next_state = CALC_HEIGHT;
            end

            CALC_HEIGHT: begin
                // Single cycle, directly go to DRAW_COL
                next_state = DRAW_COL;
            end

            DRAW_COL: begin
                if (draw_col_done)
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
        end else begin
            if (state == PRECALC) begin
                precalc_done <= 1;
            end else begin
                precalc_done <= 0;
            end
        end
    end

endmodule


module Precalc #(
    parameter TILE_WIDTH = 64,
    parameter FRAC_BITS = 7
) (
    input  wire [15:0] px,              // Player X position (world coords)
    input  wire [15:0] py,              // Player Y position (world coords)
    input  wire [9:0]  ra,              // Ray angle [0, 1024)

    // Vertical DDA outputs
    output wire signed [15:0] vrx,      // Initial ray X for vertical check
    output wire signed [15:0] vry,      // Initial ray Y for vertical check
    output wire signed [15:0] vxo,      // X step for vertical DDA
    output wire signed [15:0] vyo,      // Y step for vertical DDA
    output wire vskip,                  // Skip vertical check

    // Horizontal DDA outputs
    output wire signed [15:0] hrx,      // Initial ray X for horizontal check
    output wire signed [15:0] hry,      // Initial ray Y for horizontal check
    output wire signed [15:0] hxo,      // X step for horizontal DDA
    output wire signed [15:0] hyo,      // Y step for horizontal DDA
    output wire hskip                   // Skip horizontal check
);

    // Angle constants (10-bit: 1024 = 360°)
    localparam [9:0] ANGLE_0   = 10'd0;
    localparam [9:0] ANGLE_90  = 10'd256;
    localparam [9:0] ANGLE_180 = 10'd512;
    localparam [9:0] ANGLE_270 = 10'd768;

    // Trig LUT outputs (Q9.7 format)
    wire signed [15:0] tan_val;
    wire signed [15:0] cot_val;
    wire signed [15:0] sin_val;
    wire signed [15:0] cos_val;

    // Instantiate TrigLUT
    TrigLUT_sim_only #(
        .WIDTH_TRIG(16),
        .FRAC_BITS(FRAC_BITS)
    ) trig_lut (
        .in_angle(ra),
        .out_sin(sin_val),
        .out_cos(cos_val),
        .out_tan(tan_val),
        .out_cot(cot_val)
    );

    // Direction flags
    wire looking_right = (ra < ANGLE_90) || (ra > ANGLE_270);
    wire looking_left  = !looking_right;
    wire looking_up    = (ra > ANGLE_0) && (ra < ANGLE_180);
    wire looking_down  = !looking_up;

    // Skip conditions
    assign vskip = (ra == ANGLE_90) || (ra == ANGLE_270);
    assign hskip = (ra == ANGLE_0) || (ra == ANGLE_180);

    // Tile alignment calculations
    // floor_to_tile: (pos / TILE_WIDTH) * TILE_WIDTH = (pos >> 6) << 6
    // ceil_to_tile:  ((pos / TILE_WIDTH) + 1) * TILE_WIDTH
    wire [15:0] floor_tile_x = {px[15:6], 6'b0};
    wire [15:0] ceil_tile_x  = {px[15:6] + 1'b1, 6'b0};
    wire [15:0] floor_tile_y = {py[15:6], 6'b0};
    wire [15:0] ceil_tile_y  = {py[15:6] + 1'b1, 6'b0};

    // =========================================================================
    // Vertical DDA initialization
    // =========================================================================
    // vrx = looking_right ? ceil_to_tile(px) : floor_to_tile(px)
    // if looking left --> vrx -= 1
    wire [15:0] vrx_unsigned = looking_right ? ceil_tile_x : floor_tile_x;
    assign vrx = looking_left ? ($signed({1'b0, vrx_unsigned[14:0]}) - 1)
                              : $signed({1'b0, vrx_unsigned[14:0]});

    // vry = py + tan * (vrx - px)
    // dx = vrx - px (signed)
    wire signed [15:0] vdx = $signed({1'b0, vrx_unsigned[14:0]}) - $signed({1'b0, px[14:0]});
    // dy = tan * dx, then shift right by FRAC_BITS
    wire signed [31:0] vdy_full = tan_val * vdx;
    wire signed [15:0] vdy = vdy_full >>> FRAC_BITS;
    assign vry = $signed({1'b0, py[14:0]}) + vdy;

    // vxo = +TILE_WIDTH or -TILE_WIDTH based on direction
    assign vxo = looking_right ? $signed(16'd64) : $signed(-16'd64);

    // vyo = tan * vxo (signed multiplication)
    wire signed [31:0] vyo_full = tan_val * vxo;
    assign vyo = vyo_full >>> FRAC_BITS;

    // =========================================================================
    // Horizontal DDA initialization
    // =========================================================================
    // hry = looking_up ? ceil_to_tile(py) : floor_to_tile(py)
    // if looking down --> hry -= 1
    wire [15:0] hry_unsigned = looking_up ? ceil_tile_y : floor_tile_y;
    assign hry = looking_down ? ($signed({1'b0, hry_unsigned[14:0]}) - 1)
                              : $signed({1'b0, hry_unsigned[14:0]});

    // hrx = px + cot * (hry - py)
    // dy = hry - py (signed)
    wire signed [15:0] hdy = $signed({1'b0, hry_unsigned[14:0]}) - $signed({1'b0, py[14:0]});
    // dx = cot * dy, then shift right by FRAC_BITS
    wire signed [31:0] hdx_full = cot_val * hdy;
    wire signed [15:0] hdx = hdx_full >>> FRAC_BITS;
    assign hrx = $signed({1'b0, px[14:0]}) + hdx;

    // hyo = +TILE_WIDTH or -TILE_WIDTH based on direction
    assign hyo = looking_up ? $signed(16'd64) : $signed(-16'd64);

    // hxo = cot * hyo (signed multiplication)
    wire signed [31:0] hxo_full = cot_val * hyo;
    assign hxo = hxo_full >>> FRAC_BITS;

endmodule


//=============================================================================
// RayDDA Module - Performs DDA ray casting (used for both vertical and horizontal)
//=============================================================================
module RayDDA #(
    parameter TILE_WIDTH = 64,
    parameter MAX_DEPTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,                      // Start DDA iteration

    // Initial ray parameters from Precalc
    input wire signed [15:0] init_rx,      // Initial ray X
    input wire signed [15:0] init_ry,      // Initial ray Y
    input wire signed [15:0] step_x,       // X step per iteration
    input wire signed [15:0] step_y,       // Y step per iteration
    input wire skip,                       // Skip flag

    // Player position for distance calculation
    input wire [15:0] px,
    input wire [15:0] py,

    // Outputs
    output reg [31:0] dis,                 // Distance squared to hit point
    output reg done,                       // DDA complete flag
    output reg hit                         // Wall hit flag
);

    // DDA FSM states
    localparam DDA_IDLE  = 2'd0;
    localparam DDA_CHECK = 2'd1;
    localparam DDA_STEP  = 2'd2;
    localparam DDA_DONE  = 2'd3;

    reg [1:0] dda_state;

    // Internal ray position
    reg signed [15:0] rx, ry;
    reg [3:0] depth;

    // Latched skip flag
    reg skip_latched;

    // Internal map ROM instance
    wire [5:0] map_addr;
    wire [1:0] map_data;

    map_rom map_inst (
        .addr(map_addr),
        .data(map_data)
    );

    // Map address: convert world coords to tile index (8x8 map)
    // rx/ry are in world coords, divide by TILE_WIDTH (64) to get tile index
    // Y axis is flipped: y=0 is bottom, y=7 is top (anti-gravity direction)
    // addr = {(7 - y_tile), x_tile}
    wire [2:0] y_tile = ry[8:6];
    wire [2:0] x_tile = rx[8:6];
    assign map_addr = {(3'd7 - y_tile), x_tile};

    // DDA State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dda_state <= DDA_IDLE;
            rx <= 0;
            ry <= 0;
            depth <= 0;
            dis <= 0;
            done <= 0;
            hit <= 0;
            skip_latched <= 0;
        end else begin
            case (dda_state)
                DDA_IDLE: begin
                    done <= 0;
                    if (start) begin
                        rx <= init_rx;
                        ry <= init_ry;
                        depth <= 0;
                        skip_latched <= skip;
                        if (skip) begin
                            // Skip DDA, go directly to done
                            dda_state <= DDA_DONE;
                        end else begin
                            dda_state <= DDA_CHECK;
                        end
                    end
                end

                DDA_CHECK: begin
                    // Check if current position hits a wall or exceeds depth
                    // map_data != 0 means wall hit
                    if (map_data != 2'b00) begin
                        hit <= 1;
                        dda_state <= DDA_DONE;
                    end else if (depth >= MAX_DEPTH) begin
                        hit <= 0;
                        dda_state <= DDA_DONE;
                    end else begin
                        dda_state <= DDA_STEP;
                    end
                end

                DDA_STEP: begin
                    // Step to next grid line
                    rx <= rx + step_x;
                    ry <= ry + step_y;
                    depth <= depth + 1;
                    dda_state <= DDA_CHECK;
                end

                DDA_DONE: begin
                    // Calculate distance squared: (rx - px)^2 + (ry - py)^2
                    if (skip_latched) begin
                        // No hit possible, set max distance
                        dis <= 32'hFFFFFFFF;
                        hit <= 0;
                    end else begin
                        dis <= ($signed(rx) - $signed({1'b0, px[14:0]})) *
                               ($signed(rx) - $signed({1'b0, px[14:0]})) +
                               ($signed(ry) - $signed({1'b0, py[14:0]})) *
                               ($signed(ry) - $signed({1'b0, py[14:0]}));
                    end
                    done <= 1;
                    dda_state <= DDA_IDLE;
                end

                default: dda_state <= DDA_IDLE;
            endcase
        end
    end

endmodule


//=============================================================================
// Expression Module - Calculate wall height from distance (Combinational Logic)
//=============================================================================
module Expression #(
    parameter SCREEN_HEIGHT = 120,
    parameter TILE_WIDTH = 64
) (
    // Input: ray angles for fisheye correction
    input wire [9:0] ray_angle,             // Current ray angle
    input wire [9:0] player_angle,          // Player facing angle

    // Input: distances squared from DDA modules
    input wire signed [31:0] vdis,          // Vertical wall distance squared
    input wire signed [31:0] hdis,          // Horizontal wall distance squared
    input wire v_hit,                       // Vertical wall hit flag
    input wire h_hit,                       // Horizontal wall hit flag

    // Output: drawing parameters
    output wire [6:0] line_height,          // Wall line height (0-120)
    output wire [6:0] draw_begin,           // Wall start y coordinate
    output wire [6:0] draw_end,             // Wall end y coordinate
    output wire is_horizontal_wall          // Wall orientation (for color)
);

    // =========================================================================
    // Wall selection logic - choose the nearest wall
    // =========================================================================
    wire use_vertical = (!v_hit) ? 1'b0 :
                        (!h_hit) ? 1'b1 :
                        (vdis <= hdis);

    wire signed [31:0] final_dis = use_vertical ? vdis : hdis;
    assign is_horizontal_wall = !use_vertical;

    // =========================================================================
    // Fisheye correction - apply cos^2(theta) to distance
    // =========================================================================
    wire signed [15:0] cos_theta;  // Q9.7 format from TrigLUT
    wire [9:0] angle_diff;

    // Calculate angle difference (wraps around automatically with 10-bit arithmetic)
    assign angle_diff = ray_angle - player_angle;

    // Instantiate TrigLUT to get cos(angle_diff)
    TrigLUT_sim_only #(
        .WIDTH_TRIG(16),
        .FRAC_BITS(7)
    ) fisheye_correction_lut (
        .in_angle(angle_diff),
        .out_sin(),              // Unused
        .out_cos(cos_theta),
        .out_tan(),              // Unused
        .out_cot()               // Unused
    );

    // Calculate cos^2(theta) - Q9.7 format
    // cos_theta is Q9.7, multiply gives Q9.14, shift right 7 to get Q9.7
    wire signed [31:0] cos_theta_sq_full = cos_theta * cos_theta;
    wire signed [15:0] cos_theta_sq = cos_theta_sq_full >>> 7;

    // Apply correction: corrected_dis = final_dis * cos^2(theta)
    // final_dis is 32-bit, cos_theta_sq is Q9.7 16-bit
    // Result needs to be shifted right by 7 bits
    wire signed [47:0] corrected_dis_full = final_dis * cos_theta_sq;
    wire signed [31:0] corrected_dis = corrected_dis_full >>> 7;

    // =========================================================================
    // Function to calculate distance threshold squared
    // Formula: threshold[H] = (7680 / H)^2 where 7680 = 120 * 64
    // =========================================================================
    function automatic signed [31:0] calc_dis_sq;
        input integer height;
        begin
            if (height == 0)
                calc_dis_sq = 32'h7FFFFFFF;  // Maximum value
            else
                calc_dis_sq = (7680 * 7680) / (height * height);
        end
    endfunction

    // =========================================================================
    // Height calculation using priority encoder (for loop in always @(*))
    // Use corrected_dis instead of final_dis for fisheye correction
    // =========================================================================
    reg [6:0] lineH;
    integer j;

    always @(*) begin
        if (!v_hit && !h_hit) begin
            lineH = 7'd0;  // No wall hit
        end else begin
            lineH = 7'd1;  // Default: farthest distance

            // Loop from 120 down to 1 to find the first matching threshold
            // This synthesizes to a priority encoder (combinational logic)
            for (j = 120; j >= 1; j = j - 1) begin
                if ($signed(corrected_dis) <= $signed(calc_dis_sq(j))) begin
                    lineH = j[6:0];
                end
            end
        end
    end

    // =========================================================================
    // Calculate drawing coordinates (vertical centering)
    // =========================================================================
    assign line_height = lineH;
    assign draw_begin = 7'd60 - (lineH >> 1);  // 60 - lineH/2
    assign draw_end = 7'd60 + (lineH >> 1);    // 60 + lineH/2

endmodule


//=============================================================================
// Draw_col Module - Draw one column of pixels (Sequential Logic)
//=============================================================================
module Draw_col #(
    parameter SCREEN_HEIGHT = 120
) (
    input wire clk,
    input wire rst_n,
    input wire start,                       // Start drawing signal

    // Drawing parameters from Expression module
    input wire [6:0] draw_begin,            // Wall start y
    input wire [6:0] draw_end,              // Wall end y
    input wire [7:0] col_x,                 // Column x coordinate
    input wire is_horizontal_wall,          // Wall orientation

    // Pixel output (RGB444 format)
    output reg [7:0] px_x,                  // Pixel x
    output reg [6:0] px_y,                  // Pixel y
    output reg [11:0] color,                // RGB444 color {R[3:0], G[3:0], B[3:0]}
    output reg px_valid,                    // Pixel valid flag

    // Control signal
    output reg done                         // Column drawing complete
);

    // =========================================================================
    // FSM States
    // =========================================================================
    localparam IDLE = 2'b00;
    localparam DRAW = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;

    // =========================================================================
    // RGB444 Color definitions
    // =========================================================================
    localparam [11:0] COLOR_CEILING   = 12'h468;  // Dark blue-gray (R=4, G=6, B=8)
    localparam [11:0] COLOR_WALL_H    = 12'hFFF;  // White (horizontal wall)
    localparam [11:0] COLOR_WALL_V    = 12'hCCC;  // Light gray (vertical wall)
    localparam [11:0] COLOR_FLOOR     = 12'h888;  // Medium gray (floor)

    // =========================================================================
    // Internal registers
    // =========================================================================
    reg [6:0] row_counter;                  // Current row being drawn (0-119)

    // Latched input parameters
    reg [6:0] draw_begin_r, draw_end_r;
    reg [7:0] col_x_r;
    reg is_horizontal_wall_r;

    // =========================================================================
    // State register
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // =========================================================================
    // Next state logic
    // =========================================================================
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = DRAW;
            end

            DRAW: begin
                if (row_counter >= SCREEN_HEIGHT - 1)
                    next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // =========================================================================
    // Datapath logic
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_counter <= 0;
            px_x <= 0;
            px_y <= 0;
            color <= 0;
            px_valid <= 0;
            done <= 0;
            draw_begin_r <= 0;
            draw_end_r <= 0;
            col_x_r <= 0;
            is_horizontal_wall_r <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    px_valid <= 0;
                    if (start) begin
                        // Latch input parameters
                        draw_begin_r <= draw_begin;
                        draw_end_r <= draw_end;
                        col_x_r <= col_x;
                        is_horizontal_wall_r <= is_horizontal_wall;
                        row_counter <= 0;
                    end
                end

                DRAW: begin
                    // Output current pixel
                    px_x <= col_x_r;
                    px_y <= row_counter;
                    px_valid <= 1;

                    // Color decision logic (simple three-region method)
                    if (row_counter < draw_begin_r) begin
                        // Ceiling region
                        color <= COLOR_CEILING;
                    end else if (row_counter < draw_end_r) begin
                        // Wall region
                        color <= is_horizontal_wall_r ? COLOR_WALL_H : COLOR_WALL_V;
                    end else begin
                        // Floor region
                        color <= COLOR_FLOOR;
                    end

                    // Increment row counter
                    row_counter <= row_counter + 1;
                end

                DONE: begin
                    px_valid <= 0;
                    done <= 1;
                end

                default: begin
                    px_valid <= 0;
                    done <= 0;
                end
            endcase
        end
    end

endmodule