extends SceneTree

func _init() -> void:
    var arr = []
    var needed = 20
    var current_idx = 0
    for i in range(needed):
        if current_idx >= arr.size() and current_idx < needed:
            arr.append(1)
        current_idx += 1
    print("Final size: ", arr.size())
    quit()
