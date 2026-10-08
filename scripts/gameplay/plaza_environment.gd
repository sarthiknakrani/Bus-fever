extends Node2D

class_name PlazaEnvironment

func _ready() -> void:
    # FOUNTAIN CENTER
    var center_tex = ResourceLoader.load("res://assets/sprites/premium_plaza/fountain_center.png") as Texture2D
    if center_tex:
        var center = Sprite2D.new()
        center.name = "FountainCenter"
        center.texture = center_tex
        # Need to fit 745x505 into roughly 300x180 so it's prominent in the middle
        # Scale to fit height 150 -> 150/505 = 0.3
        center.scale = Vector2(0.3, 0.3)
        center.position = Vector2(0, 0)
        add_child(center)
        
    # GARDEN LEFT
    var left_tex = ResourceLoader.load("res://assets/sprites/premium_plaza/garden_left.png") as Texture2D
    if left_tex:
        var garden_l = Sprite2D.new()
        garden_l.name = "GardenLeft"
        garden_l.texture = left_tex
        # 388x402 scaled down
        garden_l.scale = Vector2(0.28, 0.28)
        garden_l.position = Vector2(-170, 0)
        add_child(garden_l)
        
    # GARDEN RIGHT
    var right_tex = ResourceLoader.load("res://assets/sprites/premium_plaza/garden_right.png") as Texture2D
    if right_tex:
        var garden_r = Sprite2D.new()
        garden_r.name = "GardenRight"
        garden_r.texture = right_tex
        garden_r.scale = Vector2(0.28, 0.28)
        garden_r.position = Vector2(170, 0)
        add_child(garden_r)

    # We keep a small water stream at the center to retain the lightweight animation.
    var stream_f = CPUParticles2D.new()
    stream_f.name = "StreamFront"
    stream_f.position = Vector2(0, -10)
    stream_f.amount = 16
    stream_f.lifetime = 0.4
    stream_f.direction = Vector2(0, 1)
    stream_f.spread = 15
    stream_f.gravity = Vector2(0, 400)
    stream_f.initial_velocity_min = 10
    stream_f.initial_velocity_max = 30
    stream_f.scale_amount_min = 2.0
    stream_f.scale_amount_max = 3.0
    stream_f.color = Color(0.7, 0.9, 1.0, 0.6)
    stream_f.z_index = 9
    add_child(stream_f)
    
    var splash = CPUParticles2D.new()
    splash.name = "SplashBase"
    splash.position = Vector2(0, 15)
    splash.amount = 12
    splash.lifetime = 0.3
    splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    splash.emission_rect_extents = Vector2(20, 5)
    splash.direction = Vector2(0, -1)
    splash.spread = 60
    splash.gravity = Vector2(0, 150)
    splash.initial_velocity_min = 10
    splash.initial_velocity_max = 20
    splash.scale_amount_min = 1.0
    splash.scale_amount_max = 2.0
    splash.color = Color(0.8, 0.95, 1.0, 0.8)
    splash.z_index = 9
    add_child(splash)
