// tb_TrigLUT_sim_only.sv
// TrigLUT_sim_only 的测试平台

`timescale 1ns / 1ps

module tb_TrigLUT_sim_only;

    // 参数
    parameter WIDTH_TRIG = 20;
    parameter FRAC_BITS = 16;

    // 信号声明
    reg [9:0] angle;
    wire signed [WIDTH_TRIG-1:0] sin_val, cos_val, tan_val, atan_val;

    // 实例化被测模块
    TrigLUT_sim_only #(
        .WIDTH_TRIG(WIDTH_TRIG),
        .FRAC_BITS(FRAC_BITS)
    ) uut (
        .in_angle(angle),
        .out_sin(sin_val),
        .out_cos(cos_val),
        .out_tan(tan_val),
        .out_atan(atan_val)
    );

    // 辅助函数：将定点数转换为实数
    function real fixed_to_real(input signed [WIDTH_TRIG-1:0] fixed_val);
        fixed_to_real = $itor(fixed_val) / 65536.0;
    endfunction

    // 测试序列
    initial begin
        $display("========================================");
        $display("TrigLUT Simulation Test");
        $display("Format: Q4.16 Fixed Point");
        $display("========================================");
        $display("Angle(deg) | Angle(int) | sin       | cos       | tan       | atan");
        $display("------------------------------------------------------------------------");

        // 测试关键角度
        test_angle(0, "0°");
        test_angle(256, "90°");
        test_angle(512, "180°");
        test_angle(768, "270°");

        $display("------------------------------------------------------------------------");

        // 测试一些常用角度
        test_angle(85, "30°");
        test_angle(171, "60°");
        test_angle(128, "45°");
        test_angle(341, "120°");
        test_angle(427, "150°");
        test_angle(597, "210°");
        test_angle(683, "240°");
        test_angle(853, "300°");
        test_angle(939, "330°");

        $display("------------------------------------------------------------------------");

        // 测试边界附近的角度
        $display("\nTesting angles near 90:");
        test_angle(255, "89.65°");
        test_angle(256, "90°");
        test_angle(257, "90.35°");

        $display("\n========================================");
        $display("Test Complete");
        $display("========================================");

        $finish;
    end

    // 测试辅助任务
    task test_angle(input [9:0] test_angle, input string angle_name);
        begin
            angle = test_angle;
            #10;  // 等待组合逻辑稳定

            $display("%-10s | %4d       | %8.5f | %8.5f | %8.5f | %8.5f",
                     angle_name,
                     test_angle,
                     fixed_to_real(sin_val),
                     fixed_to_real(cos_val),
                     fixed_to_real(tan_val),
                     fixed_to_real(atan_val));
        end
    endtask

endmodule
