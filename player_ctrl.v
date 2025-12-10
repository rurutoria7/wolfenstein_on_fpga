`timescale 1ns / 1ps

module player_ctrl(
    input wire rst,
    input wire clk,
    input wire forward,
    input wire backward,
    input wire left,
    input wire right,
    output reg[15:0] x,
    output reg[15:0] y,
    output reg[9:0] angle
);
    // debounce part
    wire net_forward, net_backward, net_left, net_right;
    debounce db_f(
        .clk(clk),
        .pb(forward),
        .pb_debounced(net_forward)
    );
    debounce db_b(
        .clk(clk),
        .pb(backward),
        .pb_debounced(net_backward)
    );
    debounce db_l(
        .clk(clk),
        .pb(left),
        .pb_debounced(net_left)
    );
    debounce db_r(
        .clk(clk),
        .pb(right),
        .pb_debounced(net_right)
    );
    // 方向控制使用电平触发（不需要 one_pulse）
    wire db_forward, db_backward, db_left, db_right;
    assign db_forward = net_forward;
    assign db_backward = net_backward;
    assign db_left = net_left;
    assign db_right = net_right;
    // map
    wire [1:0] data;
    reg[15:0] new_x, new_y;
    reg[9:0] new_angle;
    // Use current position for collision detection to avoid combinatorial loop
    map_rom mp(
        .addr(y[15:6]*8 + x[15:6]),  // Use tile coordinates from current position
        .data(data)
    );
    // triangle lookup table (使用 Block RAM)
    wire signed [15:0] sin, cos, tan, cot;
    TrigLUT t0(
        .clk(clk),
        .in_angle(angle),
        .out_sin(sin),
        .out_cos(cos),
        .out_tan(tan),
        .out_cot(cot)
    );
    // player data
    parameter speed = 1;
    parameter turn_speed = 1;

    // FSM
    always@(posedge clk or posedge rst) begin
        if(rst) begin
            x <= 16'd96;        // 1.5 个 tile (CELL_SIZE=64)
            y <= 16'd96;        // 地图中央附近
            angle <= 10'd256;   // 90度（朝东）
        end else begin
            x <= new_x;
            y <= new_y;
            angle <= new_angle;
        end
    end

    // forward & backward
    always@(*) begin
        // 默认保持当前位置
        new_x = x;
        new_y = y;

        if(db_forward) begin
            new_x = x - cos*speed;
            new_y = y + sin * speed;
        end else if(db_backward) begin
            new_x = x + cos * speed;
            new_y = y - sin * speed;
        end

        // Collision detection temporarily disabled to avoid combinatorial loop
        // The RaycasterModule will show walls, preventing player from getting lost
        // TODO: Implement collision detection using sequential logic
    end

    // turn left or right
    always@(*) begin
        // 默认保持当前角度
        new_angle = angle;

        if(db_left) begin
            new_angle = angle - turn_speed;  // 下溢自动回绕到 1023
        end else if(db_right) begin
            new_angle = angle + turn_speed;  // 上溢自动回绕到 0
        end
        // 无需手动处理溢出，10位无符号整数自动在 0-1023 循环
    end
endmodule