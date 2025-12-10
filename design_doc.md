## Constant

- Game Resolution: 160x120
    - for future, frame buffer should be to 320 x 240
    - FrameBufferSize = 230400 = 230k bits
- Color: RGB444
- Pixel Coord:
    - unsigned 10 bit
    ```
    +------> x
    |
    |
    V y
    ```
- World Coord: 
    - unsigned 10 bit
    ```
    ^ y (0-512)
    |
    |
    +--------> x (0 ~ 512)
    ```
- Map
    - Tile: 8x8
    - Tile Width = (512 / 8) = 64
- Timing:
    - 100 MHz
    - 60 FPS
    - ClockPerFrame: 1e8/60 = 1.66e6 clk
    - ColumnPerFrame = ClockPerFrame/Width = 10375 clk

## Data Type

- World Position: 16 bit unsigned integer
- Angle: 10 bit unsigned integer
- Sin/Cos/Tan/Cot : Q9.7 signed fixed-point
    - according to Cot/Tan scope, under 10 bit Angle
- Pixel Coord : 10 bit unsigned integer

## Modules

- module PlayerController
    ```c
    in:
        clk, rst
        keyboard_io
    out:
        bus(WIDTH_POS * 2) player_pos
        bus(WIDTH_ANG * 2) player_dir
    ```

- module Raycaster
    ```c
    in: inx, iny, ina, clk
    out: u, v, color
    ```
    - Pre Calculate
        ```c
        in: px, py, ra
        out: vrx, vry, vxo, vyo, vskip
             hrx, hry, hxo, hyo, hskip

        tan = ...
        div_tan = ... // cot

        // look exactly up or down
        vskip = (ra == 90 || ra == 270)? 1 : 0
        vrx = (ra < 90 || ra > 270)? ceil_to_tile(px) : floor_to_tile(px)
        vry = py + tan * (vrx - px) // dy = tan * dx
        vox = TILE_WIDTH
        voy = TILE_WIDTH * tan

        hskip = (ra == 0 || ra == 180)? 1 : 0
        hry = (ra > 0 && ra < 180)?  ceil_to_tile(py) : floor_to_tile(px)
        hrx = px + (hry - py) * div_tan;
        hoy = TILE_WIDTH;
        hox = TILE_WIDTH * div_tan;
        ```

        <img src="image.png" alt="DDA Illustration" style="zoom:40%;" />

    - FSM
        ```mermaid
        stateDiagram-v2

        DRAW_COL: DRAW_COL
        DRAW_COL : / output px_x, px_y, color

        [*] --> IDLE

        IDLE --> PRECALC : frame_start == 1 <br> / **x, y, a <= in_signal**

        PRECALC --> VER_DDA : done == 1  / <br> **rx, ry, xo, yo <= ...**

        VER_DDA --> VER_DDA : hit == 0 / <br> **rx, ry <= rx+ox, ry+yo**
        VER_DDA --> HOR_DDA : hit == 1 <br> / **rx, ry <= reset** <br> / **vdis <= ...**

        HOR_DDA --> HOR_DDA : hit == 0 / <br> **rx, ry <= rx+ox, ry+yo**
        HOR_DDA --> CALC_HEIGHT : hit == 1 / <br> **px_y <= 0** / <br> **hdis <= ...**

        CALC_HEIGHT --> DRAW_COL : done / **height <= ...**

        DRAW_COL --> DRAW_COL : px_done == 1 / <br> **px_y <= ...**
        DRAW_COL --> NEXT_COL : col_done == 1 /

        NEXT_COL --> PRECALC : frame_done == 0 / <br> **a <= ...**
        NEXT_COL --> IDLE : frame_done == 1
        ```

- module TrigLUT (三角函数查找表)
