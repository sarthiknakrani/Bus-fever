extends SceneTree

func _init() -> void:
    var lvl = CarJamLevelData.new()
    lvl.level_id = 1
    lvl.title = "Level 1"
    lvl.board_size = Vector2i(5, 5)
    lvl.parking_slots_count = 7

    var v1 = CarJamVehicleData.new()
    v1.id = 1
    v1.code = "v1_yellow"
    v1.color_id = "yellow"
    v1.capacity = 4
    v1.direction = CarJamVehicleData.Direction.DOWN
    v1.anchor = Vector2i(1, 0)
    var arr1: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
    v1.footprint = arr1

    var v2 = CarJamVehicleData.new()
    v2.id = 2
    v2.code = "v2_blue"
    v2.color_id = "blue"
    v2.capacity = 4
    v2.direction = CarJamVehicleData.Direction.LEFT
    v2.anchor = Vector2i(3, 1)
    var arr2: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, 0)]
    v2.footprint = arr2

    var v3 = CarJamVehicleData.new()
    v3.id = 3
    v3.code = "v3_red"
    v3.color_id = "red"
    v3.capacity = 4
    v3.direction = CarJamVehicleData.Direction.RIGHT
    v3.anchor = Vector2i(1, 2)
    var arr3: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
    v3.footprint = arr3

    var v4 = CarJamVehicleData.new()
    v4.id = 4
    v4.code = "v4_yellow"
    v4.color_id = "yellow"
    v4.capacity = 4
    v4.direction = CarJamVehicleData.Direction.UP
    v4.anchor = Vector2i(3, 4)
    var arr4: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, -1)]
    v4.footprint = arr4

    var v5 = CarJamVehicleData.new()
    v5.id = 5
    v5.code = "v5_blue"
    v5.color_id = "blue"
    v5.capacity = 4
    v5.direction = CarJamVehicleData.Direction.DOWN
    v5.anchor = Vector2i(2, 3)
    var arr5: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
    v5.footprint = arr5
    
    var v6 = CarJamVehicleData.new()
    v6.id = 6
    v6.code = "v6_red"
    v6.color_id = "red"
    v6.capacity = 4
    v6.direction = CarJamVehicleData.Direction.LEFT
    v6.anchor = Vector2i(1, 3)
    var arr6: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, 0)]
    v6.footprint = arr6

    var varr: Array[CarJamVehicleData] = [v1, v2, v3, v4, v5, v6]
    lvl.vehicles = varr

    var g1 = PassengerGroupData.new()
    g1.color_id = "yellow"
    g1.initial_count = 4
    var g2 = PassengerGroupData.new()
    g2.color_id = "blue"
    g2.initial_count = 4
    var g3 = PassengerGroupData.new()
    g3.color_id = "red"
    g3.initial_count = 4
    var g4 = PassengerGroupData.new()
    g4.color_id = "yellow"
    g4.initial_count = 4
    var g5 = PassengerGroupData.new()
    g5.color_id = "blue"
    g5.initial_count = 4
    var g6 = PassengerGroupData.new()
    g6.color_id = "red"
    g6.initial_count = 4
    
    var garr: Array[PassengerGroupData] = [g1, g2, g3, g4, g5, g6]
    lvl.passenger_groups = garr

    ResourceSaver.save(lvl, "res://levels/level_001.tres")
    print("Level 1 saved.")
    quit()
