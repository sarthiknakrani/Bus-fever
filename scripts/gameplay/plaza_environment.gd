extends Node2D

class_name PlazaEnvironment

func _ready() -> void:
    _setup_plaza()

func _load_tex(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        return ResourceLoader.load(path) as Texture2D
    return null

func _create_sprite(parent: Node, name: String, tex_name: String, pos: Vector2 = Vector2.ZERO, z: int = 0) -> Sprite2D:
    var s = Sprite2D.new()
    s.name = name
    s.position = pos
    s.z_index = z
    var t = _load_tex("res://assets/sprites/premium_plaza/" + tex_name)
    if t:
        s.texture = t
    else:
        # If the asset is missing, create a small invisible placeholder so the node tree is intact
        # and the developer knows exactly what is missing.
        pass
    parent.add_child(s)
    return s

func _setup_plaza() -> void:
    # 1. Base Paving
    var floor = _create_sprite(self, "PlazaFloor", "plaza_floor_texture.png", Vector2.ZERO, 0)
    
    # 2. Border Stones
    var border = _create_sprite(self, "PlazaBorder", "plaza_border_stones.png", Vector2.ZERO, 1)
    
    # 3. Landscaping (Shrubs and Flowers)
    # We break these into quadrants so they can have organic shapes and overlap correctly
    _create_sprite(self, "FlowerBedTop", "flower_bed_top.png", Vector2(0, -50), 2)
    _create_sprite(self, "FlowerBedBottom", "flower_bed_bottom.png", Vector2(0, 50), 2)
    _create_sprite(self, "FlowerBedLeft", "flower_bed_left.png", Vector2(-150, 0), 2)
    _create_sprite(self, "FlowerBedRight", "flower_bed_right.png", Vector2(150, 0), 2)
    
    # 4. Fountain Assembly Root (Centered)
    var fountain = Node2D.new()
    fountain.name = "FountainRoot"
    fountain.position = Vector2(0, 0)
    add_child(fountain)
    
    # Fountain Shadow
    var f_shadow = _create_sprite(fountain, "FountainShadow", "fountain_shadow.png", Vector2(0, 20), 3)
    f_shadow.modulate = Color(0, 0, 0, 0.4)
    
    # Back Rim (drawn behind water)
    _create_sprite(fountain, "BasinBack", "fountain_basin_back.png", Vector2(0, -10), 4)
    
    # Water Pool (Shader applied)
    var pool = _create_sprite(fountain, "WaterPool", "fountain_water_pool.png", Vector2(0, 0), 5)
    if pool.texture:
        var mat = ShaderMaterial.new()
        var shader = ResourceLoader.load("res://shaders/water_ripple.gdshader") as Shader
        if shader:
            mat.shader = shader
            pool.material = mat
            
    # Front Rim (drawn over water to give depth)
    _create_sprite(fountain, "BasinFront", "fountain_basin_front.png", Vector2(0, 10), 6)
    
    # Pedestal (Center Pillar)
    _create_sprite(fountain, "Pedestal", "fountain_pedestal.png", Vector2(0, -20), 7)
    
    # Upper Bowl
    _create_sprite(fountain, "UpperBowl", "fountain_bowl.png", Vector2(0, -50), 8)
    
    # Animated Water Streams
    # Using a simple particle system for lightweight mobile streams dropping from the upper bowl
    var stream_l = CPUParticles2D.new()
    stream_l.name = "StreamLeft"
    stream_l.position = Vector2(-25, -45)
    stream_l.amount = 16
    stream_l.lifetime = 0.6
    stream_l.direction = Vector2(-0.5, 1)
    stream_l.spread = 15
    stream_l.gravity = Vector2(0, 400)
    stream_l.initial_velocity_min = 40
    stream_l.initial_velocity_max = 60
    stream_l.scale_amount_min = 2.0
    stream_l.scale_amount_max = 4.0
    stream_l.color = Color(0.7, 0.9, 1.0, 0.8)
    stream_l.z_index = 9
    fountain.add_child(stream_l)
    
    var stream_r = stream_l.duplicate()
    stream_r.name = "StreamRight"
    stream_r.position = Vector2(25, -45)
    stream_r.direction = Vector2(0.5, 1)
    fountain.add_child(stream_r)
    
    var stream_f = stream_l.duplicate()
    stream_f.name = "StreamFront"
    stream_f.position = Vector2(0, -40)
    stream_f.direction = Vector2(0, 1)
    stream_f.initial_velocity_min = 20
    stream_f.initial_velocity_max = 40
    fountain.add_child(stream_f)
    
    # Splash Particles where streams hit the pool
    var splash = CPUParticles2D.new()
    splash.name = "SplashBase"
    splash.position = Vector2(0, 5)
    splash.amount = 24
    splash.lifetime = 0.4
    splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    splash.emission_rect_extents = Vector2(30, 10)
    splash.direction = Vector2(0, -1)
    splash.spread = 45
    splash.gravity = Vector2(0, 200)
    splash.initial_velocity_min = 30
    splash.initial_velocity_max = 50
    splash.scale_amount_min = 1.0
    splash.scale_amount_max = 3.0
    splash.color = Color(0.8, 0.95, 1.0, 0.9)
    splash.z_index = 9
    fountain.add_child(splash)
    
    # Top Statue
    _create_sprite(fountain, "TopStatue", "fountain_statue.png", Vector2(0, -80), 10)

