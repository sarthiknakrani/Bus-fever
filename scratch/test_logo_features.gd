extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TESTING LOGO POSITION, BREATHE ANIMATION & GLOSS SHINE ---")
	var scn = load("res://scenes/main.tscn")
	var inst = scn.instantiate()
	root.add_child(inst)
	root.get_viewport().size = Vector2i(390, 844)

	await process_frame
	await process_frame
	await process_frame

	var logo_wrapper: Control = inst.get_node("HomeRoot/HUD/TitleLogoWrapper")
	var logo_rect: TextureRect = logo_wrapper.get_node("LogoTexture")
	var sm: ShaderMaterial = logo_rect.material as ShaderMaterial

	print("1. Logo Geometry on 390x844:")
	print("   Position: ", logo_wrapper.position)
	print("   Size: ", logo_wrapper.size)
	print("   Pivot offset: ", logo_wrapper.pivot_offset)
	assert(logo_wrapper.position.y > 120.0, "Logo should be shifted down below y=120")
	assert(logo_wrapper.pivot_offset == logo_wrapper.size * 0.5, "Pivot offset should be centered for breathing")

	print("2. Shader Parameters:")
	var sw = sm.get_shader_parameter("shine_width")
	var ss = sm.get_shader_parameter("shine_softness")
	var sec_w = sm.get_shader_parameter("secondary_width")
	print("   shine_width: ", sw)
	print("   shine_softness: ", ss)
	print("   secondary_width: ", sec_w)
	assert(abs(sw - 0.035) < 0.001, "shine_width should be 0.035")
	assert(abs(ss - 0.018) < 0.001, "shine_softness should be 0.018")

	print("3. Testing Breathing Animation Scale over time:")
	var init_scale: Vector2 = logo_wrapper.scale
	print("   Initial scale: ", init_scale)
	
	# Simulate 0.9 seconds of tweens
	for i in range(30):
		await process_frame

	var scaled: Vector2 = logo_wrapper.scale
	print("   Scale during breathe: ", scaled)
	assert(scaled.x >= 0.999 and scaled.x <= 1.035, "Scale should remain in subtle breathing range [1.0, 1.025]")

	# Test 476x1024 layout
	print("4. Testing 476x1024 layout (User Device):")
	inst._update_layout(Vector2(476, 1024))
	print("   Position on 476x1024: ", logo_wrapper.position)
	print("   Size on 476x1024: ", logo_wrapper.size)
	assert(logo_wrapper.position.y >= 140.0, "Logo y on 1024 height should be >= 140.0 for balanced spacing")
	assert(logo_wrapper.position.y + logo_wrapper.size.y <= 1024 * 0.435, "Logo bottom must not overlap skyline")

	print("=== ALL LOGO VERIFICATION TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
