extends Node

func _ready() -> void:
    get_tree().root.size = Vector2i(720, 1280)
    await get_tree().create_timer(1.0).timeout
    var img = get_viewport().get_texture().get_image()
    img.save_png("home_screen_updated.png")
    get_tree().quit()
