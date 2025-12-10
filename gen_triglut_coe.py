#!/usr/bin/env python3
"""
生成 TrigLUT COE 文件用于 Xilinx Block RAM 初始化
生成 1024 个角度值的 sin, cos, tan, cot
使用 Q9.7 定点格式（16 位，7 位小数）
"""

import math

def to_fixed_point(value, frac_bits=7):
    """将浮点数转换为定点数（Q9.7 格式）"""
    scale = 2 ** frac_bits
    fixed = int(round(value * scale))

    # 限制在 16 位有符号范围内
    max_val = 32767
    min_val = -32768
    if fixed > max_val:
        fixed = max_val
    elif fixed < min_val:
        fixed = min_val

    return fixed

def to_unsigned_hex(value):
    """将有符号整数转换为无符号 16 位十六进制"""
    if value < 0:
        value = (1 << 16) + value
    return f"{value:04x}"

def generate_trig_lut():
    """生成三角函数查找表"""
    num_angles = 1024
    angle_scale = 2.0 * math.pi / num_angles

    sin_table = []
    cos_table = []
    tan_table = []
    cot_table = []

    for i in range(num_angles):
        angle_rad = i * angle_scale

        # 计算三角函数
        sin_val = math.sin(angle_rad)
        cos_val = math.cos(angle_rad)

        # sin 和 cos 转定点
        sin_fixed = to_fixed_point(sin_val)
        cos_fixed = to_fixed_point(cos_val)

        # 处理 tan 和 cot 的特殊情况
        if i == 256 or i == 768:  # 90° 和 270°
            tan_fixed = 32767 if i == 256 else -32768
            cot_fixed = 0
        elif i == 0 or i == 512:  # 0° 和 180°
            tan_fixed = 0
            cot_fixed = 32767 if i == 0 else -32768
        else:
            tan_val = math.tan(angle_rad)

            # 限制 tan 的范围
            if tan_val > 255.0:
                tan_fixed = 32767
            elif tan_val < -255.0:
                tan_fixed = -32768
            else:
                tan_fixed = to_fixed_point(tan_val)

            # 计算 cot = 1/tan
            if abs(tan_val) < 1e-6:
                cot_fixed = 32767 if cos_val > 0 else -32768
            else:
                cot_val = 1.0 / tan_val
                if cot_val > 255.0:
                    cot_fixed = 32767
                elif cot_val < -255.0:
                    cot_fixed = -32768
                else:
                    cot_fixed = to_fixed_point(cot_val)

        sin_table.append(sin_fixed)
        cos_table.append(cos_fixed)
        tan_table.append(tan_fixed)
        cot_table.append(cot_fixed)

    return sin_table, cos_table, tan_table, cot_table

def write_coe_file(filename, data_table, description):
    """写入 COE 文件"""
    with open(filename, 'w') as f:
        f.write(f"; {description}\n")
        f.write("; 1024 entries, 16-bit signed values (Q9.7 format)\n")
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")

        for i, value in enumerate(data_table):
            hex_val = to_unsigned_hex(value)
            if i == len(data_table) - 1:
                f.write(f"{hex_val};\n")
            else:
                f.write(f"{hex_val},\n")

def write_combined_coe_file(filename, sin_table, cos_table, tan_table, cot_table):
    """写入合并的 COE 文件（sin, cos, tan, cot 按顺序 64 位宽）"""
    with open(filename, 'w') as f:
        f.write("; Combined TrigLUT lookup table\n")
        f.write("; 1024 entries, 64-bit values\n")
        f.write("; Format: [sin(15:0), cos(15:0), tan(15:0), cot(15:0)]\n")
        f.write("; Each value is Q9.7 signed fixed-point (16 bits)\n")
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")

        for i in range(len(sin_table)):
            sin_hex = to_unsigned_hex(sin_table[i])
            cos_hex = to_unsigned_hex(cos_table[i])
            tan_hex = to_unsigned_hex(tan_table[i])
            cot_hex = to_unsigned_hex(cot_table[i])

            # 按顺序合并：sin, cos, tan, cot
            combined = f"{sin_hex}{cos_hex}{tan_hex}{cot_hex}"

            if i == len(sin_table) - 1:
                f.write(f"{combined};\n")
            else:
                f.write(f"{combined},\n")

if __name__ == '__main__':
    print("生成三角函数查找表...")
    sin_table, cos_table, tan_table, cot_table = generate_trig_lut()

    print("生成合并的 COE 文件...")
    write_combined_coe_file('triglut.coe', sin_table, cos_table, tan_table, cot_table)

    print("✓ 成功生成 triglut.coe")
    print(f"  表大小: 1024 项")
    print(f"  数据宽度: 64 位 (sin[15:0], cos[15:0], tan[15:0], cot[15:0])")
    print(f"  格式: Q9.7 (16位定点，7位小数)")

    # 验证几个关键角度
    print("\n验证关键角度:")
    test_angles = [0, 256, 512, 768]  # 0°, 90°, 180°, 270°
    angle_names = ['0°', '90°', '180°', '270°']

    for idx, name in zip(test_angles, angle_names):
        print(f"  {name:5s}: sin={sin_table[idx]:6d} ({to_unsigned_hex(sin_table[idx])}), "
              f"cos={cos_table[idx]:6d} ({to_unsigned_hex(cos_table[idx])})")
        print(f"         tan={tan_table[idx]:6d} ({to_unsigned_hex(tan_table[idx])}), "
              f"cot={cot_table[idx]:6d} ({to_unsigned_hex(cot_table[idx])})")
