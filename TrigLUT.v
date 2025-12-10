`timescale 1ns / 1ps

// TrigLUT.v
// 三角函数查找表模块 - 使用 Block RAM IP (blk_mem_gen_1)
// 1024 个角度值（0-1023 对应 0-2π）
// 输出：sin, cos, tan, cot（16 位定点数，Q9.7 格式）

module TrigLUT (
    input wire clk,                                // 时钟信号
    input wire [9:0] in_angle,                     // 角度输入 [0, 1024) 对应 [0, 2π)
    output wire signed [15:0] out_sin,             // sin(angle) Q9.7 格式
    output wire signed [15:0] out_cos,             // cos(angle) Q9.7 格式
    output wire signed [15:0] out_tan,             // tan(angle) Q9.7 格式
    output wire signed [15:0] out_cot              // cot(angle) Q9.7 格式
);

    // Block RAM 输出（64位：sin, cos, tan, cot）
    wire [63:0] bram_data;

    // 实例化 Block RAM
    blk_mem_gen_1 triglut_bram (
        .clka(clk),
        .addra(in_angle),
        .douta(bram_data)
    );

    // 分解 64 位数据到各个三角函数输出
    // 格式：[sin(15:0), cos(15:0), tan(15:0), cot(15:0)]
    assign out_sin = bram_data[63:48];  // 最高 16 位
    assign out_cos = bram_data[47:32];  // 次高 16 位
    assign out_tan = bram_data[31:16];  // 次低 16 位
    assign out_cot = bram_data[15:0];   // 最低 16 位

endmodule
