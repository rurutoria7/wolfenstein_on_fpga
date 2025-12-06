`timescale 1ns / 1ps

//=============================================================================
// Framebuffer - Simulation Only
// 用于仿真时存储像素输出序列，支持验证和导出
//=============================================================================
module framebuffer_sim #(
    parameter SCREEN_WIDTH = 160,
    parameter SCREEN_HEIGHT = 120,
    parameter COLOR_BITS = 12        // RGB444 format
) (
    input wire clk,
    input wire rst_n,

    // Pixel input interface
    input wire [7:0] px_x,           // Pixel X coordinate
    input wire [6:0] px_y,           // Pixel Y coordinate
    input wire [COLOR_BITS-1:0] color, // Pixel color
    input wire px_valid,             // Pixel valid signal

    // Frame control
    input wire frame_start,          // Start of new frame (clears buffer)
    input wire frame_done,           // Frame rendering complete

    // Statistics output
    output reg [31:0] pixel_count,   // Total pixels written
    output reg [31:0] frame_count    // Total frames completed
);

    // =========================================================================
    // Framebuffer Memory
    // =========================================================================
    // 二维数组存储像素数据: [y][x]
    reg [COLOR_BITS-1:0] framebuffer [0:SCREEN_HEIGHT-1][0:SCREEN_WIDTH-1];

    // 像素写入标记 (用于检测重复写入)
    reg pixel_written [0:SCREEN_HEIGHT-1][0:SCREEN_WIDTH-1];

    // =========================================================================
    // 统计信息
    // =========================================================================
    reg [31:0] current_frame_pixels;  // 当前帧已写入的像素数
    reg [31:0] duplicate_writes;      // 重复写入计数
    reg [31:0] out_of_bounds;         // 越界写入计数

    // =========================================================================
    // 初始化
    // =========================================================================
    integer i, j;

    initial begin
        pixel_count = 0;
        frame_count = 0;
        current_frame_pixels = 0;
        duplicate_writes = 0;
        out_of_bounds = 0;

        // 初始化 framebuffer 为黑色
        for (i = 0; i < SCREEN_HEIGHT; i = i + 1) begin
            for (j = 0; j < SCREEN_WIDTH; j = j + 1) begin
                framebuffer[i][j] = {COLOR_BITS{1'b0}};
                pixel_written[i][j] = 1'b0;
            end
        end
    end

    // =========================================================================
    // 主逻辑 - 像素写入
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count <= 0;
            frame_count <= 0;
            current_frame_pixels <= 0;
            duplicate_writes <= 0;
            out_of_bounds <= 0;

            // 清空 framebuffer
            for (i = 0; i < SCREEN_HEIGHT; i = i + 1) begin
                for (j = 0; j < SCREEN_WIDTH; j = j + 1) begin
                    framebuffer[i][j] <= {COLOR_BITS{1'b0}};
                    pixel_written[i][j] <= 1'b0;
                end
            end
        end else begin
            // 处理帧开始信号
            if (frame_start) begin
                $display("[Framebuffer] Frame %0d started at time %t", frame_count, $time);
                current_frame_pixels <= 0;

                // 清空写入标记
                for (i = 0; i < SCREEN_HEIGHT; i = i + 1) begin
                    for (j = 0; j < SCREEN_WIDTH; j = j + 1) begin
                        pixel_written[i][j] <= 1'b0;
                    end
                end
            end

            // 处理像素写入
            if (px_valid) begin
                // 边界检查
                if (px_x < SCREEN_WIDTH && px_y < SCREEN_HEIGHT) begin
                    // 检测重复写入
                    if (pixel_written[px_y][px_x]) begin
                        $display("[Framebuffer] WARNING: Duplicate write at (%0d, %0d) - color=0x%03h (time=%t)",
                                 px_x, px_y, color, $time);
                        duplicate_writes <= duplicate_writes + 1;
                    end

                    // 写入像素
                    framebuffer[px_y][px_x] <= color;
                    pixel_written[px_y][px_x] <= 1'b1;
                    pixel_count <= pixel_count + 1;
                    current_frame_pixels <= current_frame_pixels + 1;
                end else begin
                    $display("[Framebuffer] ERROR: Out of bounds write at (%0d, %0d) - color=0x%03h (time=%t)",
                             px_x, px_y, color, $time);
                    out_of_bounds <= out_of_bounds + 1;
                end
            end

            // 处理帧完成信号
            if (frame_done) begin
                frame_count <= frame_count + 1;
                $display("[Framebuffer] Frame %0d completed at time %t", frame_count, $time);
                $display("[Framebuffer]   Pixels written: %0d / %0d (%.1f%%)",
                         current_frame_pixels,
                         SCREEN_WIDTH * SCREEN_HEIGHT,
                         (100.0 * current_frame_pixels) / (SCREEN_WIDTH * SCREEN_HEIGHT));

                if (duplicate_writes > 0) begin
                    $display("[Framebuffer]   WARNING: %0d duplicate writes detected", duplicate_writes);
                end

                if (out_of_bounds > 0) begin
                    $display("[Framebuffer]   ERROR: %0d out of bounds writes detected", out_of_bounds);
                end
            end
        end
    end

    // =========================================================================
    // 任务: 读取指定位置的像素
    // =========================================================================
    function automatic [COLOR_BITS-1:0] read_pixel;
        input [7:0] x;
        input [6:0] y;
        begin
            if (x < SCREEN_WIDTH && y < SCREEN_HEIGHT) begin
                read_pixel = framebuffer[y][x];
            end else begin
                $display("[Framebuffer] ERROR: read_pixel out of bounds (%0d, %0d)", x, y);
                read_pixel = {COLOR_BITS{1'b0}};
            end
        end
    endfunction

    // =========================================================================
    // 任务: 检查指定位置是否被写入
    // =========================================================================
    function automatic is_pixel_written;
        input [7:0] x;
        input [6:0] y;
        begin
            if (x < SCREEN_WIDTH && y < SCREEN_HEIGHT) begin
                is_pixel_written = pixel_written[y][x];
            end else begin
                is_pixel_written = 1'b0;
            end
        end
    endfunction

    // =========================================================================
    // 任务: 导出整列到终端 (用于调试)
    // =========================================================================
    task display_column;
        input [7:0] col_x;
        integer row;
        begin
            $display("\n========================================");
            $display("Column %0d contents:", col_x);
            $display("========================================");

            if (col_x < SCREEN_WIDTH) begin
                for (row = 0; row < SCREEN_HEIGHT; row = row + 1) begin
                    if (pixel_written[row][col_x]) begin
                        $display("  Y=%3d: 0x%03h %s",
                                 row,
                                 framebuffer[row][col_x],
                                 get_color_name(framebuffer[row][col_x]));
                    end else begin
                        $display("  Y=%3d: [NOT WRITTEN]", row);
                    end
                end
            end else begin
                $display("ERROR: Column %0d out of bounds", col_x);
            end

            $display("========================================\n");
        end
    endtask

    // =========================================================================
    // 任务: 导出整帧到终端 (简化版，显示列统计)
    // =========================================================================
    task display_frame_summary;
        integer col, row, col_pixels;
        begin
            $display("\n========================================");
            $display("Frame %0d Summary:", frame_count);
            $display("========================================");

            for (col = 0; col < SCREEN_WIDTH; col = col + 1) begin
                col_pixels = 0;
                for (row = 0; row < SCREEN_HEIGHT; row = row + 1) begin
                    if (pixel_written[row][col]) begin
                        col_pixels = col_pixels + 1;
                    end
                end

                if (col_pixels != SCREEN_HEIGHT) begin
                    $display("  Column %3d: %3d / %3d pixels (INCOMPLETE)",
                             col, col_pixels, SCREEN_HEIGHT);
                end
            end

            $display("========================================\n");
        end
    endtask

    // =========================================================================
    // 任务: 导出为 PPM 图像文件 (P3 格式 - ASCII)
    // =========================================================================
    task export_ppm;
        input string filename;
        integer file, row, col;
        reg [3:0] r, g, b;
        begin
            file = $fopen(filename, "w");

            if (file == 0) begin
                $display("[Framebuffer] ERROR: Cannot open file %s", filename);
            end else begin
                // PPM header
                $fwrite(file, "P3\n");
                $fwrite(file, "# Generated by framebuffer_sim\n");
                $fwrite(file, "%0d %0d\n", SCREEN_WIDTH, SCREEN_HEIGHT);
                $fwrite(file, "15\n");  // Max color value (4-bit per channel)

                // Pixel data (row by row, top to bottom)
                for (row = 0; row < SCREEN_HEIGHT; row = row + 1) begin
                    for (col = 0; col < SCREEN_WIDTH; col = col + 1) begin
                        // RGB444 format: {R[3:0], G[3:0], B[3:0]}
                        r = framebuffer[row][col][11:8];
                        g = framebuffer[row][col][7:4];
                        b = framebuffer[row][col][3:0];
                        $fwrite(file, "%0d %0d %0d ", r, g, b);
                    end
                    $fwrite(file, "\n");
                end

                $fclose(file);
                $display("[Framebuffer] Exported frame to %s", filename);
            end
        end
    endtask

    // =========================================================================
    // 函数: 获取颜色名称 (用于调试显示)
    // =========================================================================
    function automatic string get_color_name;
        input [COLOR_BITS-1:0] c;
        begin
            case (c)
                12'h468: get_color_name = "(CEILING)";
                12'hFFF: get_color_name = "(WALL_H)";
                12'hCCC: get_color_name = "(WALL_V)";
                12'h888: get_color_name = "(FLOOR)";
                12'h000: get_color_name = "(BLACK)";
                default: get_color_name = "";
            endcase
        end
    endfunction

    // =========================================================================
    // 任务: 验证列的完整性
    // =========================================================================
    function automatic verify_column;
        input [7:0] col_x;
        integer row, missing;
        begin
            missing = 0;

            if (col_x >= SCREEN_WIDTH) begin
                $display("[Framebuffer] ERROR: verify_column - column %0d out of bounds", col_x);
                verify_column = 0;
            end else begin
                for (row = 0; row < SCREEN_HEIGHT; row = row + 1) begin
                    if (!pixel_written[row][col_x]) begin
                        missing = missing + 1;
                    end
                end

                if (missing > 0) begin
                    $display("[Framebuffer] Column %0d: INCOMPLETE (%0d missing pixels)",
                             col_x, missing);
                    verify_column = 0;
                end else begin
                    verify_column = 1;
                end
            end
        end
    endfunction

    // =========================================================================
    // 任务: 统计报告
    // =========================================================================
    task print_statistics;
        begin
            $display("\n========================================");
            $display("Framebuffer Statistics");
            $display("========================================");
            $display("  Total frames:        %0d", frame_count);
            $display("  Total pixels:        %0d", pixel_count);
            $display("  Duplicate writes:    %0d", duplicate_writes);
            $display("  Out of bounds:       %0d", out_of_bounds);
            $display("========================================\n");
        end
    endtask

endmodule

/*

## 接口信号

### 输入
- `clk`, `rst_n`: 时钟和复位
- `px_x`, `px_y`: 像素坐标
- `color`: 像素颜色 (RGB444 格式)
- `px_valid`: 像素有效信号
- `frame_start`: 帧开始信号（清空缓冲区）
- `frame_done`: 帧完成信号

### 输出
- `pixel_count`: 总像素计数
- `frame_count`: 总帧计数

## 使用方法

### 1. 实例化 Framebuffer

```systemverilog
framebuffer_sim #(
    .SCREEN_WIDTH(160),
    .SCREEN_HEIGHT(120),
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
```

### 2. 读取像素值

```systemverilog
// 在 testbench 中读取指定位置的像素
reg [11:0] pixel_color;
pixel_color = framebuffer.read_pixel(8'd10, 7'd20);  // 读取 (10, 20) 的颜色
```

### 3. 验证列的完整性

```systemverilog
// 验证第 0 列是否完整（所有 120 行都被写入）
if (!framebuffer.verify_column(8'd0)) begin
    $display("ERROR: Column 0 is incomplete");
end
```

### 4. 显示列内容

```systemverilog
// 显示第 0 列的所有像素值到终端
framebuffer.display_column(8'd0);
```

输出示例：
```
========================================
Column 0 contents:
========================================
  Y=  0: 0x468 (CEILING)
  Y=  1: 0x468 (CEILING)
  ...
  Y= 50: 0xFFF (WALL_H)
  Y= 51: 0xFFF (WALL_H)
  ...
  Y=118: 0x888 (FLOOR)
  Y=119: 0x888 (FLOOR)
========================================
```

### 5. 显示帧摘要

```systemverilog
// 显示整帧的统计信息（哪些列不完整）
framebuffer.display_frame_summary();
```

### 6. 导出 PPM 图像

```systemverilog
// 导出当前帧为 PPM 格式图像文件
framebuffer.export_ppm("output_frame.ppm");
```

生成的 PPM 文件可以用图像查看器打开（如 GIMP, ImageMagick, 或在线 PPM 查看器）。

### 7. 打印统计信息

```systemverilog
// 打印总体统计信息
framebuffer.print_statistics();
```

输出示例：
```
========================================
Framebuffer Statistics
========================================
  Total frames:        3
  Total pixels:        360
  Duplicate writes:    0
  Out of bounds:       0
========================================
```

## 颜色定义

模块内置了常用颜色的识别：

| 颜色值   | 名称        | 用途       |
|---------|------------|-----------|
| `0x468` | CEILING    | 天花板     |
| `0xFFF` | WALL_H     | 水平墙壁   |
| `0xCCC` | WALL_V     | 垂直墙壁   |
| `0x888` | FLOOR      | 地板       |
| `0x000` | BLACK      | 黑色       |

## 注意事项

1. **仅用于仿真**: 此模块使用 SystemVerilog 的高级特性，不可综合
2. **内存使用**: 对于大分辨率，会占用较多仿真内存
3. **帧开始信号**: 每次新帧开始时会清空写入标记，但不清空像素数据
4. **并发写入**: 如果同一周期写入多个像素（px_valid 多次为高），只有最后一个会生效
*/