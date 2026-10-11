extends RefCounted
class_name PassengerDemand

## Pure-data descriptor of how many passengers a level needs, in what color
## order, and against which buses. Computed from the authoritative level
## data (buses & their capacities). This is the level-independent core of
## the universal passenger system: every wave generator and validator
## ultimately consumes a PassengerDemand and is required to produce a
## compatible passenger order.
##
## The class makes NO assumptions about specific colors, counts, or bus
## capacities. It works for any number of colors, any number of buses, any
## capacity. A wave of 40 yellow passengers for one level is the same data
## shape as a wave of 4 yellow passengers for another.

## Total passengers demanded across all colors.
var total: int = 0

## Map of color id -> total passengers demanded of that color.
var by_color: Dictionary = {}

## Buses that still need passengers, color-keyed. Each value is an Array
## of Dictionary: {"id": String, "capacity": int, "remaining": int}.
## remaining is initialized to capacity and decremented as wave slots
## are absorbed for that bus.
var buses_by_color: Dictionary = {}

## Ordered list of bus ids as they appear in the source data. The player
## can tap buses in this declared order or after accessibility rules are
## applied; the universal system does not enforce the original order.
var bus_order: Array = []

## Construct from a CarJamLevelData (or any object exposing .vehicles with
## color_id and capacity). Returns an empty demand if no vehicles.
static func from_carjam_level(lvl) -> PassengerDemand:
	var pd: PassengerDemand = (load("res://scripts/universal/passenger_demand.gd") as GDScript).new()
	if lvl == null:
		return pd
	var vehicles = lvl.vehicles if "vehicles" in lvl else []
	for v in vehicles:
		var color = String(v.color_id)
		var cap = int(v.capacity)
		if not pd.buses_by_color.has(color):
			pd.buses_by_color[color] = []
		pd.buses_by_color[color].append({
			"id": String(v.code) if "code" in v else str(v.id),
			"capacity": cap,
			"remaining": cap
		})
		pd.by_color[color] = int(pd.by_color.get(color, 0)) + cap
		pd.total += cap
		pd.bus_order.append(String(v.code) if "code" in v else str(v.id))
	return pd

## Construct from an arbitrary Array of buses (each a Dictionary with
## "color" and "capacity", plus optional "id"). Useful for unit tests.
static func from_bus_dicts(buses: Array) -> PassengerDemand:
	var pd: PassengerDemand = (load("res://scripts/universal/passenger_demand.gd") as GDScript).new()
	for b in buses:
		var color = String(b.get("color", ""))
		var cap = int(b.get("capacity", 0))
		var bid = String(b.get("id", ""))
		if cap <= 0:
			continue
		if not pd.buses_by_color.has(color):
			pd.buses_by_color[color] = []
		pd.buses_by_color[color].append({
			"id": bid,
			"capacity": cap,
			"remaining": cap
		})
		pd.by_color[color] = int(pd.by_color.get(color, 0)) + cap
		pd.total += cap
		pd.bus_order.append(bid)
	return pd

## How many distinct colors are present.
func color_count() -> int:
	return buses_by_color.size()

## Sorted list of color ids (deterministic ordering for tests).
func sorted_colors() -> Array:
	var keys: Array = []
	for k in by_color.keys():
		keys.append(k)
	keys.sort()
	return keys

## Apply a wave (consume N passengers of `color` from buses). Returns the
## number actually absorbed (0 if no bus of that color has remaining
## seats, in which case the player would soft-lock). Refuses to exceed
## individual bus capacity (the universal model is: NO passenger is
## double-counted and NO bus exceeds capacity).
func apply_wave(color: String, count: int) -> int:
	if count <= 0 or not buses_by_color.has(color):
		return 0
	var buses: Array = buses_by_color[color]
	var absorbed := 0
	for b in buses:
		if absorbed >= count:
			break
		var rem = int(b["remaining"])
		if rem <= 0:
			continue
		var take = mini(rem, count - absorbed)
		b["remaining"] = rem - take
		absorbed += take
	return absorbed

## Reset all buses to full remaining = capacity. Used by validators that
## want to re-walk waves without rebuilding the demand.
func reset_buses() -> void:
	for color in buses_by_color.keys():
		for b in buses_by_color[color]:
			b["remaining"] = int(b["capacity"])

## Returns true if every bus has 0 remaining seats.
func fully_assigned() -> bool:
	for color in buses_by_color.keys():
		for b in buses_by_color[color]:
			if int(b["remaining"]) > 0:
				return false
	return true

## Returns a snapshot suitable for diagnostics.
func snapshot() -> Dictionary:
	var buses: Dictionary = {}
	for color in buses_by_color.keys():
		var arr: Array = []
		for b in buses_by_color[color]:
			arr.append({"id": b["id"], "capacity": b["capacity"], "remaining": b["remaining"]})
		buses[color] = arr
	return {
		"total": total,
		"by_color": by_color.duplicate(),
		"bus_order": bus_order.duplicate(),
		"buses": buses
	}
