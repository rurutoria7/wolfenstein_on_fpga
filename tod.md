- setting
    - Game Resolution: 160x120
        - FrameBufferSize = 230400 = 230k bits
    - Pos Coord: 
        ```
        ^ y (0-1023)
        |
        |
        +--------> x (0 ~ 1023)
        ```
    - Degree : [0, 2Pi] --> [0, 1024] ?

- module Game
    ```c
    Constants:
        bus(1*8*8) Map // 8x8
    States:
        bus(x * 2) PlayerPos
        bus(x) PlayerDir
    Trans:
    ```

- module Raycaster
    ```c
    in: inx, iny, ina, clk
    out: u, v, color

    States:
        Unow, Vnow
        
    ```