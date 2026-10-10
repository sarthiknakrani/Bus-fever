extends TextureButton
class_name Button3D

var viewport: SubViewport
var camera: Camera3D
var mesh_instance: MeshInstance3D
var icon_sprite: Sprite3D
var label_3d: Label3D
var plus_label: Label3D

var base_color: Color
var b_depth: float
var is_pressed := false

func setup_3d(mesh_path: String, color: Color, icon_path: String, text: String, size_2d: Vector2, has_plus: bool = false, custom_depth: float = 16.0):
	self.custom_minimum_size = size_2d
	self.ignore_texture_size = true
	self.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	base_color = color
	b_depth = custom_depth
	
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.size = size_2d
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.msaa_3d = Viewport.MSAA_4X
	
	var world = Node3D.new()
	viewport.add_child(world)
	
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size_2d.y
	camera.position = Vector3(0, 0, 150)
	camera.current = true
	world.add_child(camera)
	
	var light = DirectionalLight3D.new()
	light.position = Vector3(50, 100, 100)
	light.rotation_degrees = Vector3(-45, 20, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true # Soft grounded shadow effect
	world.add_child(light)
	
	var fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(30, -30, 0)
	fill_light.light_energy = 0.4
	world.add_child(fill_light)
	
	mesh_instance = MeshInstance3D.new()
	var mesh = load(mesh_path) as Mesh
	mesh_instance.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.15 # Glossy
	mat.metallic = 0.1
	mesh_instance.material_override = mat
	world.add_child(mesh_instance)
	
	var face_z = mesh.get_aabb().position.z + mesh.get_aabb().size.z + 1.0
	
	if icon_path != "":
		icon_sprite = Sprite3D.new()
		icon_sprite.texture = load(icon_path)
		icon_sprite.position = Vector3(0, 0, face_z)
		icon_sprite.pixel_size = 1.0
		# Center it properly
		var tex_h = icon_sprite.texture.get_height()
		if tex_h > 0:
			var target_h = size_2d.y * 0.65
			var scale_f = target_h / float(tex_h)
			icon_sprite.scale = Vector3(scale_f, scale_f, scale_f)
			
		mesh_instance.add_child(icon_sprite)
		
	if text != "":
		label_3d = Label3D.new()
		label_3d.text = text
		label_3d.pixel_size = 1.0
		# If the button is 80 units high, a 36-unit font is nicely proportioned (about 45% of height)
		# For pause buttons (56 high), 24 is nicely proportioned.
		label_3d.font_size = int(size_2d.y * 0.45) if icon_path == "" else int(size_2d.y * 0.25)
		label_3d.outline_size = max(2, int(label_3d.font_size * 0.2))
		label_3d.position = Vector3(0, 0, face_z)
		label_3d.modulate = Color("ffffff")
		
		# User requested "dark-blue extrusion/shadow" for Home Play, "dark green" for Pause Play, "dark orange" for Home
		var outline_col = Color("1e3a8a") # default dark blue
		if "22c55e" in base_color.to_html(): outline_col = Color("064e3b") # dark green
		if "f97316" in base_color.to_html(): outline_col = Color("7c2d12") # dark orange/brown
		label_3d.outline_modulate = outline_col
		if icon_path != "":
			label_3d.position.y -= size_2d.y * 0.25 # Move text below icon? Wait, if there's an icon, the text is usually external.
			# But for pause menu buttons, there's text only.
		mesh_instance.add_child(label_3d)
		
	if has_plus:
		plus_label = Label3D.new()
		plus_label.text = "✚"
		plus_label.font_size = int(size_2d.y * 0.6)
		plus_label.outline_size = 4
		plus_label.modulate = Color("ffffff")
		plus_label.outline_modulate = Color("064e3b")
		# Position top right
		plus_label.position = Vector3(size_2d.x * 0.35, size_2d.y * 0.35, face_z + 1.0)
		mesh_instance.add_child(plus_label)
		
	add_child(viewport)
	
	var vp_tex = viewport.get_texture()
	self.texture_normal = vp_tex
	self.texture_pressed = vp_tex
	
	self.button_down.connect(_on_down)
	self.button_up.connect(_on_up)
	self.mouse_exited.connect(_on_up)

func _on_down():
	if is_pressed: return
	is_pressed = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tw = create_tween()
	tw.tween_property(mesh_instance, "position:y", -b_depth * 0.25, 0.05).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(mesh_instance, "scale:z", 0.7, 0.05).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func(): viewport.render_target_update_mode = SubViewport.UPDATE_ONCE)

func _on_up():
	if not is_pressed: return
	is_pressed = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tw = create_tween()
	tw.tween_property(mesh_instance, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(mesh_instance, "scale:z", 1.0, 0.1).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func(): viewport.render_target_update_mode = SubViewport.UPDATE_ONCE)

