extends Node2D

class_name PlazaEnvironment

func _ready() -> void:
    # Fountain is temporarily disabled as requested
    visible = false
    set_process(false)
    set_physics_process(false)
    
    # We leave the node structure mostly empty or hidden so the track remains clean
    pass
