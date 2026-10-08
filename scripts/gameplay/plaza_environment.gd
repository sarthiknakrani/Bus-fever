extends Node2D

class_name PlazaEnvironment

func _ready() -> void:
    # Use the composite island to ensure zero gaps and a coherent stone underlay
    var tex = ResourceLoader.load("res://assets/sprites/premium_plaza/fountain_island_composite.png") as Texture2D
    if tex:
        var island = Sprite2D.new()
        island.name = "FountainIsland"
        island.texture = tex
        # 1200x420. Track is 540x180.
        # Scale to fit exactly inside the track oval safely
        island.scale = Vector2(0.35, 0.35)
        island.position = Vector2(0, 0)
        add_child(island)

    # Subtle animated water overlay aligned with the central spout
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
