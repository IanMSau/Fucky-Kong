if (keyboard_check_pressed(ord("P"))) {
    
    // CONFIGURATION
    var _target_x      = room_width / 2;  
    var _target_y      = room_height / 3; 
    var _scale_width   = 8.0;             
    var _scale_height  = 1.0;             
    
    var _is_moving     = true;           
    var _speed_val     = 0.005;            
    var _dist_x        = 350;             
    var _dist_y        = 0;              

    // SPAWN
    var _inst = instance_create_layer(_target_x, _target_y, layer, obj_platform);
    
    // INJECT CONFIGURATION PARAMETERS
    with (_inst) {
        // Set initial anchors
        start_x = _target_x;
        start_y = _target_y;
        timer = 0;
        
        // Stretch the visual sprite
        image_xscale = _scale_width;
        image_yscale = _scale_height;
        
        // Inject movement rules if toggled on
        if (_is_moving) {
            move_speed   = _speed_val;
            move_range_x = _dist_x;
            move_range_y = _dist_y;
        } else {
            move_speed   = 0;
            move_range_x = 0;
            move_range_y = 0;
        }
    }
    
    // ENGINE SAFETY BOOT
    if (!instance_exists(obj_platform_manager)) {
        instance_create_layer(0, 0, layer, obj_platform_manager);
    }
    
    show_debug_message("Custom platform configured and deployed!");
}