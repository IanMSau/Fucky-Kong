window_set_size(1280, 720);

// constants
#macro INPUT_BUFFER_FRAMES   6     // frames a jump press stays buffered
#macro STICK_DEADZONE        0.25
#macro STICK_WALK_THRESHOLD  0.65  // under this = walk, over = dash
#macro STICK_PRESS_THRESHOLD 0.5   // for tap jump / fastfall

enum PSTATE
{
	IDLE,
	WALK,
	DASH,
	RUN,
	SKID,
	CROUCH,
	JUMPSQUAT,
	AIR,
	LANDING,
}

state_names = ["IDLE", "WALK", "DASH", "RUN", "SKID", "CROUCH", "JUMPSQUAT", "AIR", "LANDING"];

// movement stats, pixels per frame
stats =
{
	gravity          : 0.30,
	max_fall         : 4.0,
	fast_fall        : 6.0,

	walk_accel       : 0.25,
	walk_max         : 1.2,
	dash_speed       : 2.4,
	dash_frames      : 10,   // dash dance window
	run_accel        : 0.3,
	run_max          : 2.4,
	ground_friction  : 0.18,
	skid_friction    : 0.16,

	air_accel        : 0.14,
	air_max          : 1.7,
	air_friction     : 0.03,

	jumpsquat_frames : 4,
	full_hop         : -5.2,
	short_hop        : -3.2,
	double_jump      : -4.8,
	jump_h_boost     : 0.6,  // how much the stick adds to hsp on jump
	max_jumps        : 2,
	landing_frames   : 4,
};

// initial values all zero
hsp      = 0;
vsp      = 0;
hsp_frac = 0;
vsp_frac = 0;

facing       = 1;
state        = PSTATE.IDLE;
state_timer  = 0;
jumps_left   = stats.max_jumps;
fast_falling = false;
grounded     = false;
debug_draw   = false;

// DEBUG: respawn point for falling off the stage
spawn_x = x;
spawn_y = y;

// input, gets filled in by poll_input() every step
input =
{
	x            : 0,
	y            : 0,
	prev_x       : 0,
	prev_y       : 0,
	walk_held    : false,
	jump_held    : false,
	jump_buffer  : 0,
	down_pressed : false,
};

poll_input = function()
{
	// keyboard
	var _kx    = (keyboard_check(vk_right) || keyboard_check(ord("D"))) - (keyboard_check(vk_left) || keyboard_check(ord("A")));  // keyboard left/right, -1 to 1
	var _ky    = (keyboard_check(vk_down)  || keyboard_check(ord("S"))) - (keyboard_check(vk_up)   || keyboard_check(ord("W")));  // keyboard up/down, -1 to 1 (down is positive)
	var _jump_pressed = keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("X"));  // jump went down this frame
	var _jump_held    = keyboard_check(vk_space) || keyboard_check(ord("X"));  // jump is being held
	var _walk         = keyboard_check(vk_shift);  // walk modifier

	// use whatever controller is plugged in first
	var _sx = 0;    // controller stick x
	var _sy = 0;    // controller stick y
	var _pad = -1;  // controller slot, -1 if none connected
	for (var i = 0; i < gamepad_get_device_count(); i++)
	{
		if (gamepad_is_connected(i)) { _pad = i; break; }
	}

	if (_pad != -1)
	{
		_sx = gamepad_axis_value(_pad, gp_axislh);
		_sy = gamepad_axis_value(_pad, gp_axislv);
		if (point_distance(0, 0, _sx, _sy) < STICK_DEADZONE)
		{
			_sx = 0;
			_sy = 0;
		}
		// d-pad adds on top of the stick
		_sx += gamepad_button_check(_pad, gp_padr) - gamepad_button_check(_pad, gp_padl);
		_sy += gamepad_button_check(_pad, gp_padd) - gamepad_button_check(_pad, gp_padu);

		_jump_pressed = _jump_pressed || gamepad_button_check_pressed(_pad, gp_face3) || gamepad_button_check_pressed(_pad, gp_face4);
		_jump_held    = _jump_held    || gamepad_button_check(_pad, gp_face3)         || gamepad_button_check(_pad, gp_face4);
	}

	input.prev_x = input.x;
	input.prev_y = input.y;
	input.x = clamp((_kx != 0) ? _kx : _sx, -1, 1);
	input.y = clamp((_ky != 0) ? _ky : _sy, -1, 1);
	input.walk_held = _walk;

	// up also jumps, _up_pressed is true the frame up gets pushed
	var _up_pressed = (input.y <= -STICK_PRESS_THRESHOLD) && (input.prev_y > -STICK_PRESS_THRESHOLD);
	_jump_pressed   = _jump_pressed || _up_pressed;
	input.jump_held = _jump_held || (input.y <= -STICK_PRESS_THRESHOLD);

	if (_jump_pressed) input.jump_buffer = INPUT_BUFFER_FRAMES;
	else if (input.jump_buffer > 0) input.jump_buffer--;

	input.down_pressed = (input.y >= STICK_PRESS_THRESHOLD) && (input.prev_y < STICK_PRESS_THRESHOLD);
};

// _new_state: a PSTATE value, also resets the frame counter
change_state = function(_new_state)
{
	state = _new_state;
	state_timer = 0;
};

// moves _value toward _target by _amount without overshooting
approach = function(_value, _target, _amount)
{
	if (_value < _target) return min(_value + _amount, _target);
	return max(_value - _amount, _target);
};

// true if a jump is buffered, and clears the buffer
consume_jump = function()
{
	if (input.jump_buffer > 0)
	{
		input.jump_buffer = 0;
		return true;
	}
	return false;
};

// true if holding walk or the stick is only tilted part way
is_walking_input = function()
{
	return input.walk_held || (abs(input.x) < STICK_WALK_THRESHOLD);
};

// _dir: -1 for left, 1 for right
start_dash = function(_dir)
{
	facing = _dir;
	hsp = _dir * stats.dash_speed;
	change_state(PSTATE.DASH);
};

// doesn't touch jumps_left, the caller sets that
enter_air = function()
{
	fast_falling = false;
	change_state(PSTATE.AIR);
};

// gives jumps back and starts landing lag
land = function()
{
	vsp = 0;
	vsp_frac = 0;
	fast_falling = false;
	jumps_left = stats.max_jumps;
	change_state(PSTATE.LANDING);
};

// moves 1px at a time, leftover fractions carry to next frame
move_and_collide_frac = function()
{
	hsp_frac += hsp;
	var _move_x = round(hsp_frac);  // whole pixels to move this frame
	hsp_frac -= _move_x;
	var _dir_x = sign(_move_x);     // -1, 0 or 1, one pixel per step
	repeat (abs(_move_x))
	{
		if (place_meeting(x + _dir_x, y, oGroundTile))
		{
			hsp = 0;
			hsp_frac = 0;
			break;
		}
		x += _dir_x;
	}

	vsp_frac += vsp;
	var _move_y = round(vsp_frac);  // whole pixels to move this frame
	vsp_frac -= _move_y;
	var _dir_y = sign(_move_y);     // -1, 0 or 1, one pixel per step
	repeat (abs(_move_y))
	{
		if (place_meeting(x, y + _dir_y, oGroundTile))
		{
			vsp = 0;
			vsp_frac = 0;
			break;
		}
		y += _dir_y;
	}
};
