extends Node2D

class_name PlazaEnvironment

func _ready() -> void:
    _setup_plaza()

func _load_tex(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        return ResourceLoader.load(path) as Texture2D
    return null

func _setup_plaza() -> void:
    var tex_base = _load_tex("res://assets/sprites/premium_plaza/plaza_base.png")
    
    # 0. Drop Shadow for Plaza Base
    var shadow = Sprite2D.new()
    shadow.texture = tex_base
    shadow.modulate = Color(0, 0, 0, 0.25)
    shadow.position = Vector2(0, 15)
    add_child(shadow)
    
    # 1. Base Stone Plaza
    var base_sprite = Sprite2D.new()
    base_sprite.texture = tex_base
    add_child(base_sprite)
    
    # 2. Outer Greenery (Shrubs/Flower beds)
    var greenery_sprite = Sprite2D.new()
    greenery_sprite.texture = _load_tex("res://assets/sprites/premium_plaza/plaza_greenery.png")
    add_child(greenery_sprite)
    
    var tex_fountain = _load_tex("res://assets/sprites/premium_plaza/fountain_base.png")
    
    # 2.5 Drop Shadow for Fountain
    var fountain_shadow = Sprite2D.new()
    fountain_shadow.texture = tex_fountain
    fountain_shadow.modulate = Color(0, 0, 0, 0.3)
    fountain_shadow.position = Vector2(0, 10)
    add_child(fountain_shadow)
    
    # 3. Fountain Structure Base
    var fountain_base = Sprite2D.new()
    fountain_base.texture = tex_fountain
    add_child(fountain_base)
    
    # 4. Animated Water
    var fountain_water = Sprite2D.new()
    fountain_water.texture = _load_tex("res://assets/sprites/premium_plaza/fountain_water.png")
    var mat = ShaderMaterial.new()
    mat.shader = ResourceLoader.load("res://shaders/water_ripple.gdshader") as Shader
    fountain_water.material = mat
    add_child(fountain_water)
    
    # 5. Center Statue/Spout
    var fountain_center = Sprite2D.new()
    fountain_center.texture = _load_tex("res://assets/sprites/premium_plaza/fountain_center.png")
    fountain_center.position = Vector2(0, -15)
    
    # Spout shadow
    var spout_shadow = Sprite2D.new()
    spout_shadow.texture = fountain_center.texture
    spout_shadow.modulate = Color(0, 0, 0, 0.4)
    spout_shadow.position = Vector2(5, 5)
    spout_shadow.z_index = -1
    fountain_center.add_child(spout_shadow)
    
    add_child(fountain_center)
