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
    // one_pulse part
    wire db_forward, db_backward, db_left, db_right;
    one_pulse op_f(
        .clk(clk),
        .pb_in(net_forward),
        .pb_out(db_forward)
    );
    one_pulse op_b(
        .clk(clk),
        .pb_in(net_backward),
        .pb_out(db_backward)
    );
    one_pulse op_l(
        .clk(clk),
        .pb_in(net_left),
        .pb_out(db_left)
    );
    one_pulse op_r(
        .clk(clk),
        .pb_in(net_right),
        .pb_out(db_right)
    );
    // map
    wire [1:0] data;
    reg[15:0] new_x, new_y;
    reg[9:0] new_angle;
    map_rom mp(
        .addr(new_y*8 + new_x),
        .data(data)
    );
    // triangle
    reg[15:0] sin, cos, tan, cot;
    TrigLUT t0(
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
            x <= 0;
            y <= 0;
            angle <= 0;
        end else begin
            x <= new_x;
            y <= new_y;
            angle <= new_angle;
        end
    end

    // forward & backward
    always@(*) begin
        if(forward) begin 
            new_x = x - cos*speed;
            new_y = y + sin * speed;
        end 
        
        if(backward) begin
            new_x = x + cos * speed;
            new_y = y - sin * speed;
        end

        // check whether hit wall
        if(data == 1) begin
            new_x = x;
            new_y = y;
        end
    end

    // turn left or right
    always@(*) begin
        if(left) begin
            new_angle = angle - turn_speed + 1024;
        end

        if(right) begin
            new_angle = angle + turn_speed;
        end

        if(new_angle >= 1024) new_angle = (new_angle) % 1024;
    end
endmodule