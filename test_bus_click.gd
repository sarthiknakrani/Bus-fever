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
    if v_keys.size() > 0:
        var vehicle_id = 0
        # Let's find an unblocked bus. Bus 1 is usually at the bottom and unblocked.
        for id in v_keys:
            var v = controller.vehicles[id]
            var res = controller.board.check_swept_escape(v)
            if res["can_escape"]:
                vehicle_id = id
                break
        
        print("Clicking vehicle: ", vehicle_id)
        controller.tap_vehicle(vehicle_id)
    await create_timer(1.0).timeout
    quit()
