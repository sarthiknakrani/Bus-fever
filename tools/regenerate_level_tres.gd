extends SceneTree

# Regenerates level_001.tres from the current factory settings.
# Ensures the saved resource has all current fields including plus_slot_ids.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[Regen] Saving level_001.tres from CarJamLevelFactory.create_level_1()...")
	var ok: bool = CarJamLevelFactory.save_level_1_tres("res://levels/level_001.tres")
	if ok:
		print("[Regen] Saved successfully.")
	else:
		print("[Regen] FAILED to save.")
	quit(0 if ok else 1)
