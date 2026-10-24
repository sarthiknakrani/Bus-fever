extends Control
class_name CoinCounterHUD

## Reusable Premium Coin Counter HUD component for Bus Fever.
## Displays live coin balance using the custom glossy coin counter asset with
## a functional green plus button that opens the approved Earn Coins dialog.

signal plus_pressed()

const COUNTER_TEXTURE_PATH := "res://assets/ui/clay_textless/counter_navy_coin_plus_wide_blank.png"
const ClayStyle := preload("res://scripts/ui/style_helpers.gd")

var texture_rect: TextureRect
var balance_label: Label
var plus_button: TextureButton
var coin_target_node: Control

var _current_balance: int = 0
var _custom_action_callback: Callable = Callable()
var _custom_action_title: String = "GOT IT!"
var _active_popup: Control = null

var _save_manager: Node = null
var _audio_manager: Node = null

func _init() -> void:
	custom_minimum_size = Vector2(128, 32)
	size = Vector2(128, 32)

func _ready() -> void:
	_build_ui()
	_update_dimensions()
	var sm := _get_save_manager()
	if sm != null:
		if sm.has_method("get_coins"):
			_current_balance = sm.get_coins()
		if sm.has_signal("coins_changed") and not sm.coins_changed.is_connected(_on_coins_changed):
			sm.coins_changed.connect(_on_coins_changed)
	update_display(_current_balance)

	if not resized.is_connected(_update_dimensions):
		resized.connect(_update_dimensions)

func _exit_tree() -> void:
	var sm := _get_save_manager()
	if sm != null and sm.has_signal("coins_changed") and sm.coins_changed.is_connected(_on_coins_changed):
		sm.coins_changed.disconnect(_on_coins_changed)
	if _active_popup != null and is_instance_valid(_active_popup):
		_active_popup.queue_free()
		_active_popup = null

## Dependency injection for testing or custom scoping
func set_save_manager(sm: Node) -> void:
	if _save_manager != null and _save_manager.has_signal("coins_changed") and _save_manager.coins_changed.is_connected(_on_coins_changed):
		_save_manager.coins_changed.disconnect(_on_coins_changed)
	_save_manager = sm
	if _save_manager != null:
		if _save_manager.has_method("get_coins"):
			_current_balance = _save_manager.get_coins()
		if _save_manager.has_signal("coins_changed") and not _save_manager.coins_changed.is_connected(_on_coins_changed):
			_save_manager.coins_changed.connect(_on_coins_changed)
	update_display(_current_balance)

func set_audio_manager(am: Node) -> void:
	_audio_manager = am

func _get_save_manager() -> Node:
	if _save_manager != null and is_instance_valid(_save_manager):
		return _save_manager
	var t: SceneTree = null
	if is_inside_tree():
		t = get_tree()
	elif Engine.has_singleton("Engine"):
		var ml = Engine.get_main_loop()
		if ml is SceneTree:
			t = ml
	if t != null and t.root != null and t.root.has_node("SaveManager"):
		return t.root.get_node("SaveManager")
	return null

func _get_audio_manager() -> Node:
	if _audio_manager != null and is_instance_valid(_audio_manager):
		return _audio_manager
	var t: SceneTree = null
	if is_inside_tree():
		t = get_tree()
	elif Engine.has_singleton("Engine"):
		var ml = Engine.get_main_loop()
		if ml is SceneTree:
			t = ml
	if t != null and t.root != null and t.root.has_node("AudioManager"):
		return t.root.get_node("AudioManager")
	return null

func _play_ui_sfx() -> void:
	var am := _get_audio_manager()
	if am != null and am.has_method("play"):
		var sfx = am.get("SFX_UI")
		if sfx == null:
			sfx = "ui_click"
		am.play(sfx)

func _build_ui() -> void:
	# Clear any previous children
	for c in get_children():
		c.queue_free()

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 1. Main Background Artwork TextureRect
	texture_rect = TextureRect.new()
	texture_rect.name = "CounterTexture"
	if ResourceLoader.exists(COUNTER_TEXTURE_PATH):
		texture_rect.texture = load(COUNTER_TEXTURE_PATH)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture_rect)

	# 2. Coin Target Marker (left gold coin center for flying coin animations)
	coin_target_node = Control.new()
	coin_target_node.name = "CoinTargetMarker"
	coin_target_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin_target_node)

	# 3. Dynamic Balance Label in blank center
	balance_label = Label.new()
	balance_label.name = "BalanceLabel"
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	balance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ClayStyle.apply_label_style(
		balance_label,
		16,
		Color("FFF0AA"), # Pale gold
		Color("593209"), # Brown outline
		3,
		Color(0.2, 0.1, 0.03, 0.45),
		Vector2(0, 1),
		true
	)
	add_child(balance_label)

	# 4. Interactive Transparent Plus Button over green plus badge
	plus_button = TextureButton.new()
	plus_button.name = "PlusButton"
	plus_button.mouse_filter = Control.MOUSE_FILTER_STOP
	plus_button.focus_mode = Control.FOCUS_NONE
	plus_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS

	plus_button.pressed.connect(_on_plus_button_pressed)
	plus_button.button_down.connect(_on_plus_button_down)
	plus_button.button_up.connect(_on_plus_button_up)
	add_child(plus_button)

func _update_dimensions() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		w = custom_minimum_size.x
		h = custom_minimum_size.y

	# Position coin target marker at the center of the left gold coin
	# The coin on the left is roughly centered at x = h * 0.52, y = h * 0.50
	if coin_target_node != null and is_instance_valid(coin_target_node):
		var coin_sz: float = h * 0.95
		coin_target_node.size = Vector2(coin_sz, coin_sz)
		coin_target_node.pivot_offset = Vector2(coin_sz * 0.5, coin_sz * 0.5)
		coin_target_node.position = Vector2(h * 0.52 - coin_sz * 0.5, h * 0.50 - coin_sz * 0.5)

	# Position balance label inside blank navy region (x = 22% to 80% of width)
	if balance_label != null and is_instance_valid(balance_label):
		balance_label.position = Vector2(w * 0.22, 0.0)
		balance_label.size = Vector2(w * 0.58, h)
		# Responsive font size based on height
		var fs: int = clampi(int(h * 0.48), 13, 24)
		balance_label.add_theme_font_size_override("font_size", fs)

	# Position plus button over green plus badge (badge center at x = 89.8% of width)
	if plus_button != null and is_instance_valid(plus_button):
		var btn_sz: float = maxf(44.0, h) # Minimum 44x44 touch target
		plus_button.size = Vector2(btn_sz, btn_sz)
		plus_button.pivot_offset = Vector2(btn_sz * 0.5, btn_sz * 0.5)
		plus_button.position = Vector2(w * 0.898 - btn_sz * 0.5, h * 0.50 - btn_sz * 0.5)

func _on_coins_changed(new_balance: int) -> void:
	_current_balance = new_balance
	update_display(_current_balance)

func update_display(amount: int) -> void:
	_current_balance = amount
	if balance_label != null and is_instance_valid(balance_label):
		balance_label.text = format_coins(amount)

## Set displayed balance without modifying saved balance (used for rolling celebration counters).
func set_displayed_balance(amount: int) -> void:
	update_display(amount)

func reset_to_save_manager_balance() -> void:
	var sm := _get_save_manager()
	if sm != null and sm.has_method("get_coins"):
		_current_balance = sm.get_coins()
	update_display(_current_balance)

## Global position of the gold coin for target of flying coin animation.
func get_coin_target_global_pos() -> Vector2:
	if coin_target_node != null and is_instance_valid(coin_target_node):
		return coin_target_node.global_position + coin_target_node.size * 0.5
	return global_position + Vector2(size.y * 0.5, size.y * 0.5)

## Juicy bounce on coin icon when a coin lands during victory.
func pulse_coin_icon() -> void:
	if coin_target_node != null and is_instance_valid(coin_target_node):
		var tw := coin_target_node.create_tween()
		coin_target_node.scale = Vector2(1.25, 1.25)
		tw.tween_property(coin_target_node, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD)

## Configure optional custom action (e.g. "PLAY NOW!" on Home screen)
func set_custom_action(title: String, callback: Callable) -> void:
	_custom_action_title = title
	_custom_action_callback = callback

func _on_plus_button_down() -> void:
	if plus_button != null and is_instance_valid(plus_button):
		var tw := plus_button.create_tween()
		tw.tween_property(plus_button, "scale", Vector2(0.88, 0.88), 0.05).set_trans(Tween.TRANS_QUAD)

func _on_plus_button_up() -> void:
	if plus_button != null and is_instance_valid(plus_button):
		var tw := plus_button.create_tween()
		tw.tween_property(plus_button, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_plus_button_pressed() -> void:
	_play_ui_sfx()
	plus_pressed.emit()
	show_earn_coins_popup()

## Lightweight informational "Earn Coins" modal explaining level rewards.
func show_earn_coins_popup() -> void:
	if _active_popup != null and is_instance_valid(_active_popup):
		_active_popup.queue_free()
		_active_popup = null

	var tree: SceneTree = null
	if is_inside_tree():
		tree = get_tree()
	elif Engine.has_singleton("Engine"):
		var ml = Engine.get_main_loop()
		if ml is SceneTree:
			tree = ml

	var popup_root := Control.new()
	popup_root.name = "EarnCoinsPopup"
	popup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_root.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_root.z_index = 500
	_active_popup = popup_root

	var parent_target: Node = null
	if tree != null and tree.root != null:
		parent_target = tree.root
	var p: Node = get_parent()
	while p != null:
		if p is CanvasLayer or p is Viewport:
			parent_target = p
			break
		p = p.get_parent()

	if parent_target != null:
		parent_target.add_child(popup_root)
	elif tree != null and tree.root != null:
		tree.root.add_child(popup_root)
	else:
		add_child(popup_root)

	# 1. Dark semi-transparent scrim
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0, 0, 0, 0.58)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_root.add_child(scrim)

	# Scrim tap dismiss
	scrim.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
			_play_ui_sfx()
			_close_popup(popup_root)
	)

	# 2. Center container
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_root.add_child(center)

	# 3. Modal Wrapper Card (Claymorphic)
	var card := PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(320, 310)
	card.pivot_offset = Vector2(160, 155)
	card.modulate.a = 1.0

	var card_style := ClayStyle.create_clay_panel(Color("fffdf7"), Color("f59e0b"), 28, 6, 22, 8, Color(0, 0, 0, 0.28))
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var card_gloss := Panel.new()
	card_gloss.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_gloss.anchor_bottom = 0.5
	card_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cg_style := ClayStyle.create_clay_highlight_style(28, 0.22)
	card_gloss.add_theme_stylebox_override("panel", cg_style)
	card.add_child(card_gloss)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header HBox (Title centered, Close button on top-right)
	var header_hbox := HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header_hbox)

	var dummy_spacer := Control.new()
	dummy_spacer.custom_minimum_size = Vector2(34, 34)
	dummy_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_hbox.add_child(dummy_spacer)

	var header_rect := ClayStyle.create_banner_header("EARN COINS", "res://assets/ui/clay_textless/banner_navy_gold_blank.png", Vector2(200, 44), 22)
	header_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_rect)

	var close_btn := ClayStyle.create_clay_texture_button("res://assets/ui/clay_textless/icon_close_red.png", Vector2(34, 34), 0.95)
	close_btn.pressed.connect(func():
		_play_ui_sfx()
		_close_popup(popup_root)
	)
	header_hbox.add_child(close_btn)

	# Coin Graphic inside a soft warm clay pedestal
	var coin_center := CenterContainer.new()
	coin_center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var coin_pedestal := PanelContainer.new()
	coin_pedestal.custom_minimum_size = Vector2(88, 80)
	coin_pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ped_style := ClayStyle.create_clay_panel(Color("fef3c7"), Color("f59e0b"), 28, 4, 12, 3, Color(0.96, 0.62, 0.11, 0.25))
	coin_pedestal.add_theme_stylebox_override("panel", ped_style)
	coin_center.add_child(coin_pedestal)

	var coin_ped_gloss := Panel.new()
	coin_ped_gloss.set_anchors_preset(Control.PRESET_FULL_RECT)
	coin_ped_gloss.anchor_bottom = 0.5
	coin_ped_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_ped_gloss.add_theme_stylebox_override("panel", ClayStyle.create_clay_highlight_style(28, 0.30))
	coin_pedestal.add_child(coin_ped_gloss)

	var coin_margin := CenterContainer.new()
	coin_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_pedestal.add_child(coin_margin)

	var coin_icon := TextureRect.new()
	coin_icon.custom_minimum_size = Vector2(72, 64)
	coin_icon.size = Vector2(72, 64)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.texture = load("res://assets/ui/clay_textless/icon_coin_gold.png")
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_margin.add_child(coin_icon)

	vbox.add_child(coin_center)

	# Explanation Text
	var desc_lbl := Label.new()
	desc_lbl.text = "Clear traffic and complete puzzle levels to collect coins!\n\nEach victory awards +50 Coins."
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ClayStyle.apply_label_style(desc_lbl, 15, Color("334155"), Color.TRANSPARENT, 0, Color.TRANSPARENT, Vector2.ZERO, false)
	vbox.add_child(desc_lbl)

	# Claymorphic Action Button
	var act_btn := ClayStyle.create_text_button(
		"res://assets/ui/clay_textless/button_orange_wide_blank.png",
		_custom_action_title,
		Vector2(210, 56),
		20,
		false,
		0.95
	)
	act_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	act_btn.pressed.connect(func():
		_play_ui_sfx()
		var cb := _custom_action_callback
		_close_popup(popup_root)
		if cb.is_valid():
			cb.call()
	)
	vbox.add_child(act_btn)

	# Entrance Animation
	card.scale = Vector2(0.9, 0.9)
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_popup(popup: Control) -> void:
	if popup == null or not is_instance_valid(popup):
		return
	var card = popup.get_node_or_null("CenterContainer/Card")
	if card != null and is_instance_valid(card):
		var tw := card.create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "scale", Vector2(0.85, 0.85), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(card, "modulate:a", 0.0, 0.12)
		tw.chain().tween_callback(func():
			if is_instance_valid(popup):
				popup.queue_free()
		)
	else:
		popup.queue_free()
	_active_popup = null

static func format_coins(n: int) -> String:
	var s := str(absi(n))
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	if n < 0:
		res = "-" + res
	return res
