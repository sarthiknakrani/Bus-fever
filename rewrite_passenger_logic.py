import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# We need to add state variables
state_vars = """
# Continuous Passenger Track State
var passenger_track: Path2D
var active_passengers: Array[Dictionary] = []
var track_time: float = 0.0
const PASSENGER_SPACING := 32.0
const TRACK_SPEED := 40.0
"""
code = code.replace("var passenger_views: Array[PassengerView] = []", state_vars)

# We replace the old _refresh_passenger_track with _init_passenger_track
init_track_code = """
func _init_passenger_track() -> void:
	passenger_track = Path2D.new()
	var curve = Curve2D.new()
	# Create an oval track
	var center = Vector2(0, -60)
	var rx = 180.0
	var ry = 70.0
	var pts = 32
	for i in range(pts + 1):
		var t = float(i) / pts * PI * 2.0
		curve.add_point(center + Vector2(cos(t)*rx, sin(t)*ry))
	passenger_track.curve = curve
	passenger_visuals.add_child(passenger_track)

	_fill_passenger_track()

func _fill_passenger_track() -> void:
	var needed = min(20, controller.queue.get_total_remaining())
	if active_passengers.size() >= needed: return
	
	var visible_groups := controller.queue.get_visible_groups(needed)
	var current_idx = 0
	
	# Skip ones we already spawned
	for g in visible_groups:
		for i in g.remaining_count:
			if current_idx >= active_passengers.size() and current_idx < needed:
				var pv := PassengerView.new()
				pv.setup(g.color_id)
				var pf := PathFollow2D.new()
				pf.loop = true
				pf.rotates = false
				pf.add_child(pv)
				passenger_track.add_child(pf)
				
				# Initial position behind the last one
				var start_prog = track_time + current_idx * PASSENGER_SPACING
				pf.progress = start_prog
				
				active_passengers.append({
					"view": pv,
					"follower": pf,
					"color_id": g.color_id
				})
			current_idx += 1
"""

# Replace _refresh_passenger_track
code = re.sub(r'func _refresh_passenger_track\(\) -> void:[\s\S]*?pass_idx \+= 1', init_track_code.strip('\n'), code)

# We need a _process function to animate them
process_code = """
func _process(delta: float) -> void:
	if controller.state == CarJamController.GameState.PLAYING:
		track_time -= TRACK_SPEED * delta
		var track_len = passenger_track.curve.get_baked_length()
		if track_time < 0: track_time += track_len
		
		for i in active_passengers.size():
			var p = active_passengers[i]
			var pf: PathFollow2D = p["follower"]
			var target_prog = track_time + i * PASSENGER_SPACING
			
			# Wrap around logic for smooth lerping
			target_prog = fmod(target_prog, track_len)
			if target_prog < 0: target_prog += track_len
			
			var diff = target_prog - pf.progress
			if diff > track_len / 2.0: diff -= track_len
			if diff < -track_len / 2.0: diff += track_len
			
			pf.progress += diff * 10.0 * delta # Smooth catch up
"""
code = code.replace("func _ready() -> void:", process_code + "\nfunc _ready() -> void:")

# Change _ready to call _init_passenger_track instead of _refresh_passenger_track
code = code.replace("_refresh_passenger_track()", "_init_passenger_track()")

# Update _on_queue_updated to just fill missing passengers
code = code.replace("func _on_queue_updated() -> void:\n\t_init_passenger_track()", "func _on_queue_updated() -> void:\n\t_fill_passenger_track()")

# Modify _on_boarding_started to use real passengers
boarding_code = """
func _on_boarding_started(vehicle_id: int, color_id: String, count: int, slot_id: int) -> void:
	_play_sfx("board")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv != null:
		var v_model: VehicleModel = controller.vehicles.get(vehicle_id, null)
		if v_model != null:
			vv.set_occupancy(v_model.passenger_occupancy)
		vv.play_badge_pulse()

	var slot_pos := _get_slot_world_pos(slot_id)

	# Extract real passengers from the track
	for i in count:
		if active_passengers.is_empty(): break
		
		# Find first matching passenger (should be at front of queue)
		var p_idx = -1
		for j in active_passengers.size():
			if active_passengers[j]["color_id"] == color_id:
				p_idx = j
				break
		
		if p_idx == -1: break
		
		var p_dict = active_passengers.pop_at(p_idx)
		var pv: PassengerView = p_dict["view"]
		var pf: PathFollow2D = p_dict["follower"]
		
		var global_p = pv.global_position
		pf.remove_child(pv)
		boarding_effects.add_child(pv)
		pv.global_position = global_p
		pf.queue_free()
		
		var delay: float = float(i) * 0.12
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(pv, "global_position", parking_root.global_position + slot_pos + Vector2(0, 12), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(pv.queue_free)
"""
code = re.sub(r'func _on_boarding_started[\s\S]*?tw\.tween_callback\(pv\.queue_free\)', boarding_code.strip('\n'), code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Rewrote passenger logic.")
