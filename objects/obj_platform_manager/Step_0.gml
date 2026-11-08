with (obj_platform) {
    if (move_speed > 0) {
        timer += move_speed;
        
        x = start_x + (sin(timer) * move_range_x);
        y = start_y + (cos(timer) * move_range_y);
    }
}