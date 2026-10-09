extends SceneTree
func _init():
    var main = load("res://scenes/level1.tscn")
    change_scene_to_packed(main)
    call_deferred("run_test")
func run_test():
    await create_timer(1.0).timeout
    var cj_level = current_scene
    var controller = cj_level.controller
    var v_keys = controller.vehicles.keys()
    
    # Try clicking all buses to see if ANY bus can escape
    var any_escaped = false
    for id in v_keys:
        var v = controller.vehicles[id]
        var res = controller.board.check_swept_escape(v)
        if res["can_escape"]:
            print("Bus ", id, " can escape! Clicking it...")
            controller.tap_vehicle(id)
            any_escaped = true
            break
            
    if not any_escaped:
        print("ERROR: NO BUSES CAN ESCAPE IN LEVEL 1!")
    
    await create_timer(1.0).timeout
    quit()
