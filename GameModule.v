module Game;

    reg `bus(`POS_NOOFBITS) PlayerX, PlayerY;
    reg `bus(`DEG_NOOFBITS) PlayerDir;
    reg `bus(`MAP_NOOF_TILE * `MAP_NOOF_TILE) Map;

endmodule;