// TrigLUT_sim_only.sv
// 仅用于仿真的三角函数查找表
// 使用 SystemVerilog 的 $sin, $cos 等系统函数

`timescale 1ns / 1ps

module TrigLUT_sim_only #(
    parameter WIDTH_TRIG = 16,  // 定点数位宽
    parameter FRAC_BITS = 7     // 小数位数 (Q9.7 格式)
) (
    input  wire [9:0] in_angle,                    // 角度输入 [0, 1024) 对应 [0, 2π)
    output wire signed [WIDTH_TRIG-1:0] out_sin,   // sin(angle)
    output wire signed [WIDTH_TRIG-1:0] out_cos,   // cos(angle)
    output wire signed [WIDTH_TRIG-1:0] out_tan,   // tan(angle)
    output wire signed [WIDTH_TRIG-1:0] out_cot    // 1/tan(angle) = cot(angle)
);

    // 常数定义
    localparam real PI = 3.14159265358979323846;
    localparam real ANGLE_SCALE = 2.0 * PI / 1024.0;  // 角度缩放因子
    localparam real FIXED_SCALE = 128.0;              // 2^7 用于定点转换 (Q9.7)
    localparam signed [WIDTH_TRIG-1:0] LARGE_VALUE = (1 << (WIDTH_TRIG-1)) - 1;  // 最大正值
    localparam signed [WIDTH_TRIG-1:0] SMALL_VALUE = -(1 << (WIDTH_TRIG-1));     // 最小负值

    // 特殊角度定义
    localparam [9:0] ANGLE_0   = 10'd0;
    localparam [9:0] ANGLE_90  = 10'd256;
    localparam [9:0] ANGLE_180 = 10'd512;
    localparam [9:0] ANGLE_270 = 10'd768;

    // 实数计算
    real angle_rad;
    real sin_real, cos_real, tan_real, cot_real;

    // 定点数转换
    reg signed [WIDTH_TRIG-1:0] sin_fixed;
    reg signed [WIDTH_TRIG-1:0] cos_fixed;
    reg signed [WIDTH_TRIG-1:0] tan_fixed;
    reg signed [WIDTH_TRIG-1:0] cot_fixed;

    // 角度转弧度
    always_comb begin
        angle_rad = in_angle * ANGLE_SCALE;
    end

    // 计算三角函数值
    always_comb begin
        // 计算 sin 和 cos
        sin_real = $sin(angle_rad);
        cos_real = $cos(angle_rad);

        // 转换为定点数 (Q4.16)
        sin_fixed = $rtoi(sin_real * FIXED_SCALE);
        cos_fixed = $rtoi(cos_real * FIXED_SCALE);

        // 计算 tan 和 cot，需要特殊处理边界情况
        if (in_angle == ANGLE_90 || in_angle == ANGLE_270) begin
            // tan(90°) = ±∞, cot = 1/tan = 0
            tan_fixed = (in_angle == ANGLE_90) ? LARGE_VALUE : SMALL_VALUE;
            cot_fixed = 0;
        end else if (in_angle == ANGLE_0 || in_angle == ANGLE_180) begin
            // tan(0°) = 0, cot = 1/tan = ±∞
            tan_fixed = 0;
            cot_fixed = (in_angle == ANGLE_0) ? LARGE_VALUE : SMALL_VALUE;
        end else begin
            // 正常计算
            tan_real = $tan(angle_rad);

            // Clamp tan 到 [-255, 255] 范围 (Q9.7 最大约 ±256)
            if (tan_real > 255.0)
                tan_fixed = LARGE_VALUE;
            else if (tan_real < -255.0)
                tan_fixed = SMALL_VALUE;
            else
                tan_fixed = $rtoi(tan_real * FIXED_SCALE);

            // 计算 cot = 1/tan
            cot_real = 1.0 / tan_real;

            // Clamp cot 到 [-255, 255] 范围 (Q9.7 最大约 ±256)
            if (cot_real > 255.0)
                cot_fixed = LARGE_VALUE;
            else if (cot_real < -255.0)
                cot_fixed = SMALL_VALUE;
            else
                cot_fixed = $rtoi(cot_real * FIXED_SCALE);
        end
    end

    // 输出赋值
    assign out_sin = sin_fixed;
    assign out_cos = cos_fixed;
    assign out_tan = tan_fixed;
    assign out_cot = cot_fixed;

endmodule
