module player_ctrl(
    input wire rst,
    input wire clk,
    input wire forward,
    input wire backward,
    input wire left,
    input wire right,
    output reg[2:0] x,
    output reg[2:0] y,
    output reg[8:0] angle
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
    reg[2:0] new_x, new_y;
    map_rom mp(
        .addr(new_y*8 + new_x),
        .data(data)
    );
    // player data
    parameter speed = 1;
    parameter turn_speed = 90; // unit is degree

    // FSM
    always@(posedge clk or posedge rst) begin
        if(rst) begin
            // initial position
            x <= 0;
            y <= 0;
            angle <= 0;
            new_x <= 0;
            new_y <= 0;
        end else begin
            // walk
            if(forward) begin
                // check whether hit wall
                case(angle)
                    0: new_y = y - 1;
                    90: new_x = x + 1;
                    180: new_y = y + 1;
                    270: new_x = x - 1;
                endcase

                if(data == 0) begin
                    x <= new_x;
                    y <= new_y;
                end
            end
            if(backward) begin
                // check whether hit wall
                case(angle)
                    0: new_y = y + 1;
                    90: new_x = x - 1;
                    180: new_y = y - 1;
                    270: new_x = x + 1;
                endcase

                if(data == 0) begin
                    x <= new_x;
                    y <= new_y;
                end
            end
            // turn
            if(left) begin
                angle <= (angle - turn_speed < 0) ? 360 + angle - turn_speed : angle - turn_speed;
            end
            if(right) begin
                angle <= (angle + turn_speed) % 360;
            end
        end
    end
endmodule