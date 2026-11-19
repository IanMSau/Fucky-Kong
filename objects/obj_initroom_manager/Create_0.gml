draw_set_color(c_white);
//draw_text_transformed(x - 16, y - 28, state_names[state], 0.5, 0.5, 0);
global.roomIndexes = [];
for (var i = 0; i <= room_last; i++) {
  if (room_exists(i)) {
    var tmpName = room_get_name(i);
    global.roomIndexes[i] = tmpName;
  }
}
//var _roomname = room_get_name(room);

/// @function       keyboard_get_number()
/// @description    Returns the pressed number key and -1 if none.

checkinput = function()
{
	
	return 
	(
	    (keyboard_key >= ord("0") && keyboard_key <= ord("9"))
	    ? keyboard_key - ord("0")
	    : -1
	);
}