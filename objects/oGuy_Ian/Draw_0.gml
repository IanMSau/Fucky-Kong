// draws the sprite flipped by facing, mask stays unflipped
draw_sprite_ext(sprite_index, image_index, x, y, facing, image_yscale, image_angle, image_blend, image_alpha);

// state and jumps above the head, toggle with F1
if (debug_draw)
{
    draw_set_color(c_white);
    draw_text_transformed(x - 16*10, y - 28*10, state_names[state], 0.5*10, 0.5*10, 0);
    draw_text_transformed(x - 16*10, y - 22*10, "jumps " + string(jumps_left), 0.5*10, 0.5*10, 0);
}