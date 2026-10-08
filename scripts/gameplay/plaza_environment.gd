extends Node2D

class_name PlazaEnvironment

func _ready() -> void:
    # INTEGRATED ARTWORK
    var art = Sprite2D.new()
    var tex = ResourceLoader.load("res://assets/sprites/fountain_masked.png") as Texture2D
    if tex:
        art.texture = tex
        # The track is 540x180. The image is 1024x768.
        # To fit inside the 180 height without covering the walkway, we must scale by 180/768 = 0.23.
        # We cannot stretch it horizontally (non-uniform scale) without distorting and damaging the artwork.
        art.scale = Vector2(0.23, 0.23) 
        art.position = Vector2(0, 0)
    add_child(art)
    
    # We keep a small water stream at the center to retain the lightweight animation.
    var stream_f = CPUParticles2D.new()
    stream_f.name = "StreamFront"
    stream_f.position = Vector2(0, -20)
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
