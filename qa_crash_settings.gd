extends SceneTree
func _init():
    # Load Autoloads manually to test headless main
    var root_node = Node2D.new()
    root.add_child(root_node)
    
    var am = load("res://scripts/autoload/audio_manager.gd").new()
    am.name = "AudioManager"
    root.add_child(am)
    
    var setm = load("res://scripts/autoload/settings_manager.gd").new()
    setm.name = "SettingsManager"
    root.add_child(setm)

    var gc = load("res://scripts/autoload/game_controller.gd").new()
    gc.name = "GameController"
    root.add_child(gc)
    
    var sm = load("res://scripts/autoload/save_manager.gd").new()
    sm.name = "SaveManager"
    root.add_child(sm)

    call_deferred("run_test", root_node)

func run_test(root_node):
    var main = load("res://scenes/main.tscn").instantiate()
    root_node.add_child(main)
    await create_timer(1.0).timeout
    
    print("Clicking settings...")
    main._on_settings_pressed()
    await create_timer(1.0).timeout
    
    if main._settings_overlay != null:
        print("Settings overlay is present and valid!")
    else:
        print("Settings overlay is NULL!")
        
    print("Children of Main:")
    for c in main.get_children():
        print(" - ", c.name)
    quit()
