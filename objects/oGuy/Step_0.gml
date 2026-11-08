poll_input();
if (keyboard_check_pressed(vk_f1)) debug_draw = !debug_draw;

grounded = place_meeting(x, y + 1, oGroundTile);
state_timer++;

var _s   = stats;  // shorthand for stats
var _dir = sign(input.x);  // -1, 0 or 1 for held direction
var _down_held = (input.y >= STICK_PRESS_THRESHOLD);  // down held far enough to crouch

switch (state)
{
	case PSTATE.IDLE:
		hsp = approach(hsp, 0, _s.ground_friction);
		if (consume_jump()) { change_state(PSTATE.JUMPSQUAT); break; }
		if (_down_held)     { change_state(PSTATE.CROUCH);    break; }
		if (_dir != 0)
		{
			if (is_walking_input())
			{
				facing = _dir;
				change_state(PSTATE.WALK);
			}
			else start_dash(_dir);
		}
		break;

	case PSTATE.WALK:
		if (consume_jump()) { change_state(PSTATE.JUMPSQUAT); break; }
		if (_down_held)     { change_state(PSTATE.CROUCH);    break; }
		if (_dir == 0)      { change_state(PSTATE.IDLE);      break; }
		if (!is_walking_input()) { start_dash(_dir); break; }

		facing = _dir;
		var _scale  = input.walk_held ? 1 : clamp(abs(input.x) / STICK_WALK_THRESHOLD, 0, 1);  // 0-1, how far the stick is tilted
		var _target = _dir * _s.walk_max * _scale;  // walk speed we're heading toward
		if (abs(hsp) > abs(_target) && sign(hsp) == _dir) hsp = approach(hsp, _target, _s.ground_friction);
		else hsp = approach(hsp, _target, _s.walk_accel);
		break;

	case PSTATE.DASH:
		if (consume_jump()) { change_state(PSTATE.JUMPSQUAT); break; }

		// dash dance
		if (_dir == -facing && !is_walking_input()) { start_dash(_dir); break; }

		hsp = facing * _s.dash_speed;
		if (state_timer >= _s.dash_frames)
		{
			if (_dir == facing) change_state(PSTATE.RUN);
			else change_state(PSTATE.IDLE);
		}
		break;

	case PSTATE.RUN:
		if (consume_jump()) { change_state(PSTATE.JUMPSQUAT); break; }
		if (_down_held)     { change_state(PSTATE.CROUCH);    break; }
		if (_dir == 0)      { change_state(PSTATE.IDLE);      break; }
		if (_dir == -facing){ change_state(PSTATE.SKID);      break; }

		hsp = approach(hsp, facing * _s.run_max, _s.run_accel);
		break;

	case PSTATE.SKID:
		if (consume_jump()) { change_state(PSTATE.JUMPSQUAT); break; }

		hsp = approach(hsp, 0, _s.skid_friction);
		if (hsp == 0)
		{
			facing = -facing;
			if (_dir == facing) change_state(PSTATE.RUN);
			else change_state(PSTATE.IDLE);
		}
		break;

	case PSTATE.CROUCH:
		hsp = approach(hsp, 0, _s.ground_friction);
		if (consume_jump()) { change_state(PSTATE.JUMPSQUAT); break; }
		if (!_down_held)    { change_state(PSTATE.IDLE);      break; }
		break;

	case PSTATE.JUMPSQUAT:
		if (state_timer >= _s.jumpsquat_frames)
		{
			// let go of jump before squat ends = short hop
			vsp = input.jump_held ? _s.full_hop : _s.short_hop;

			var _max_h = max(_s.air_max, abs(hsp));  // speed cap, keeps running momentum
			hsp = clamp(hsp + input.x * _s.jump_h_boost, -_max_h, _max_h);

			jumps_left = _s.max_jumps - 1;
			enter_air();
		}
		break;

	case PSTATE.AIR:
		// check jumps_left first so we don't eat a buffered jump right before landing
		if (jumps_left > 0 && consume_jump())
		{
			vsp = _s.double_jump;
			hsp = input.x * _s.air_max;
			jumps_left--;
			fast_falling = false;
		}

		// drift, but keep extra speed from running jumps
		if (_dir != 0)
		{
			var _air_target = input.x * _s.air_max;  // drift speed we're heading toward
			if (abs(hsp) <= _s.air_max || sign(hsp) != _dir) hsp = approach(hsp, _air_target, _s.air_accel);
			else hsp = approach(hsp, _air_target, _s.air_friction);
		}
		else hsp = approach(hsp, 0, _s.air_friction);

		// fastfall only after the peak
		if (!fast_falling && vsp >= 0 && input.down_pressed) fast_falling = true;

		if (fast_falling) vsp = _s.fast_fall;
		else vsp = min(vsp + _s.gravity, _s.max_fall);
		break;

	case PSTATE.LANDING:
		hsp = approach(hsp, 0, _s.ground_friction);
		if (state_timer >= _s.landing_frames)
		{
			change_state(_down_held ? PSTATE.CROUCH : PSTATE.IDLE);
		}
		break;
}

if (state != PSTATE.AIR && grounded) vsp = 0;

move_and_collide_frac();

// check if we landed or walked off something
grounded = place_meeting(x, y + 1, oGroundTile);

if (state == PSTATE.AIR)
{
	if (grounded && vsp >= 0) land();
}
else if (!grounded)
{
	// walked off a ledge, only the double jump is left
	jumps_left = _s.max_jumps - 1;
	enter_air();
}

// DEBUG: send back to spawn after leaving the room
if (y > room_height + 64 || x < -64 || x > room_width + 64)
{
	x = spawn_x;
	y = spawn_y;
	hsp = 0;
	vsp = 0;
	hsp_frac = 0;
	vsp_frac = 0;
	fast_falling = false;
	jumps_left = _s.max_jumps;
	change_state(PSTATE.IDLE);
}
