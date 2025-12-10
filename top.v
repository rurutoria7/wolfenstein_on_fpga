`timescale 1ns / 1ps

// top.v
// Wolfenstein FPGA Top Module
// Integrates RaycasterModule, Framebuffer (Block RAM) and VGA Controller

module top (
    // ========== System Clock and Reset ==========
    input wire clk,              // 100MHz main clock (from XDC: W5)
    input wire rst,              // Active-high reset (button U18)

    // ========== User Input ==========
    input wire start,            // Start rendering (button T17)
    input wire [2:0] sw,         // Switch control: sw[0]=forward, sw[1]=left, sw[2]=right

    // ========== VGA Output ==========
    output wire hsync,           // Horizontal sync
    output wire vsync,           // Vertical sync
    output wire [3:0] vgaRed,    // Red channel
    output wire [3:0] vgaGreen,  // Green channel
    output wire [3:0] vgaBlue,   // Blue channel

    // ========== Debug LEDs ==========
    output wire [15:0] led
);

    //=========================================================================
    // 1. Reset and Clock Generation
    //=========================================================================
    wire rst_n = ~rst;

    // 25MHz clock divider (100MHz -> 25MHz)
    // Divide by 4: toggle every 2 cycles
    reg [1:0] clk_div_counter;
    reg clk_25MHz;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_div_counter <= 2'd0;
            clk_25MHz <= 1'b0;
        end else begin
            if (clk_div_counter == 2'd1) begin
                clk_div_counter <= 2'd0;
                clk_25MHz <= ~clk_25MHz;
            end else begin
                clk_div_counter <= clk_div_counter + 2'd1;
            end
        end
    end

    //=========================================================================
    // 2. Frame Rate Generator (~60 FPS)
    //=========================================================================
    // 20-bit counter: 100MHz / 2^20 ≈ 95.4 Hz (close to 60 FPS)
    reg [19:0] frame_counter;
    reg frame_start_pulse;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            frame_counter <= 20'd0;
            frame_start_pulse <= 1'b0;
        end else begin
            if (frame_counter == 20'hFFFFF) begin  // All 1's (1048575)
                frame_counter <= 20'd0;
                frame_start_pulse <= 1'b1;
            end else begin
                frame_counter <= frame_counter + 20'd1;
                frame_start_pulse <= 1'b0;
            end
        end
    end

    //=========================================================================
    // 3. Button Debouncing and Pulse Generation
    //=========================================================================
    wire start_db, start_pulse;
    wire forward_db, left_db, right_db;

    // Start button (single pulse trigger)
    debounce db_start (
        .clk(clk),
        .pb(start),
        .pb_debounced(start_db)
    );

    one_pulse op_start (
        .clk(clk),
        .pb_in(start_db),
        .pb_out(start_pulse)
    );

    // Direction control (level trigger, continuous)
    debounce db_forward (.clk(clk), .pb(sw[0]), .pb_debounced(forward_db));
    debounce db_left    (.clk(clk), .pb(sw[1]), .pb_debounced(left_db));
    debounce db_right   (.clk(clk), .pb(sw[2]), .pb_debounced(right_db));

    //=========================================================================
    // 3. Player Controller Instantiation
    //=========================================================================
    wire [15:0] player_x;
    wire [15:0] player_y;
    wire [9:0] player_angle;

    player_ctrl player (
        .rst(rst),
        .clk(clk),
        .forward(forward_db),
        .backward(1'b0),           // Not connected
        .left(left_db),
        .right(right_db),
        .x(player_x),
        .y(player_y),
        .angle(player_angle)
    );

    //=========================================================================
    // 4. RaycasterModule Instantiation
    //=========================================================================
    wire [7:0] rc_px_x;            // 0-159
    wire [6:0] rc_px_y;            // 0-119
    wire [11:0] rc_color;          // RGB444
    wire rc_px_valid;
    wire rc_frame_done;

    RaycasterModule raycaster (
        .clk(clk),
        .rst_n(rst_n),
        .frame_start(frame_start_pulse),
        .inx(player_x),
        .iny(player_y),
        .ina(player_angle),
        .px_x(rc_px_x),
        .px_y(rc_px_y),
        .color(rc_color),
        .px_valid(rc_px_valid),
        .frame_done(rc_frame_done)
    );

    //=========================================================================
    // 5. Framebuffer Address Calculation
    //=========================================================================

    // Write address (RaycasterModule -> Framebuffer Port A)
    wire [16:0] fb_wr_addr;
    assign fb_wr_addr = {10'b0, rc_px_y} * 17'd160 + {9'b0, rc_px_x};

    // Read address (VGA -> Framebuffer Port B)
    wire [9:0] vga_h_cnt;
    wire [9:0] vga_v_cnt;
    wire vga_valid;

    wire [7:0] fb_rd_x = vga_h_cnt[9:2];  // vga_h_cnt / 4
    wire [6:0] fb_rd_y = vga_v_cnt[9:2];  // vga_v_cnt / 4
    wire [16:0] fb_rd_addr = {10'b0, fb_rd_y} * 17'd160 + {9'b0, fb_rd_x};

    //=========================================================================
    // 6. Block Memory (Framebuffer) Instantiation
    //=========================================================================
    wire [11:0] fb_rd_data;

    blk_mem_gen_0 framebuffer (
        // Port A: Write port (RaycasterModule @ 100MHz)
        .clka(clk),
        .ena(1'b1),
        .wea(rc_px_valid),         // Write enable = px_valid
        .addra(fb_wr_addr),
        .dina(rc_color),

        // Port B: Read port (VGA @ 25MHz)
        .clkb(clk),
        .enb(1'b1),
        .addrb(fb_rd_addr),
        .doutb(fb_rd_data)
    );

    //=========================================================================
    // 7. VGA Controller Instantiation
    //=========================================================================
    vga_controller vga (
        .pclk(clk_25MHz),
        .reset(rst),               // Active-high reset
        .hsync(hsync),
        .vsync(vsync),
        .valid(vga_valid),
        .h_cnt(vga_h_cnt),
        .v_cnt(vga_v_cnt)
    );

    //=========================================================================
    // 8. VGA RGB Output Logic
    //=========================================================================
    // Pipeline stage 2: output color
    reg [11:0] pixel_color;


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pixel_color <= 12'h000;
        end else begin
            if (vga_valid) begin
                pixel_color <= fb_rd_data;
            end else begin
                pixel_color <= 12'h000;    // Black (outside boundary)
            end
        end
    end

    assign vgaRed   = pixel_color[11:8];
    assign vgaGreen = pixel_color[7:4];
    assign vgaBlue  = pixel_color[3:0];

    //=========================================================================
    // 9. Debug LED Assignment
    //=========================================================================
    assign led[0]  = rc_frame_done;       // Frame done indicator
    assign led[1]  = rc_px_valid;         // Pixel write indicator
    assign led[2]  = start_pulse;         // Start button pulse
    assign led[3]  = clk_25MHz;           // 25MHz clock heartbeat
    assign led[4]  = forward_db;          // Forward button state
    assign led[5]  = left_db;             // Left turn state
    assign led[6]  = right_db;            // Right turn state
    assign led[7]  = vga_valid;           // VGA valid area
    assign led[15:8] = player_angle[9:2]; // Player angle high 8 bits

endmodule
