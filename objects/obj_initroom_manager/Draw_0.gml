
for (var i = 0; i < array_length(global.roomIndexes); i++)
{
	draw_text_transformed(x + 50, y + 100*i, "FOR: ", 4, 4, 0);
	draw_text_transformed(x + 180, y + 100*i, global.roomIndexes[i], 4, 4, 0);
	draw_text_transformed(x + 900, y + 100*i, "PRESS: ", 4, 4, 0);
	draw_text_transformed(x + 1150, y + 100*i, i, 4, 4, 0);
}