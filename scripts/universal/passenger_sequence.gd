extends RefCounted
class_name PassengerSequence

## Runtime authoritative feeder state built from a WavePlan + an
## initial-on-track count. Knows:
##  - the flat ordered list of passenger colors it must release
##  - which passengers are currently on the loop (visible)
##  - which are in the feeder (queuing)
##  - which have been released (in player-facing circulation)
##  - which have been completed (boarded)
##
## The runtime calls:
##   - try_release_one() — try to push the next passenger into the feeder
##   - mark_boarded() — when an animation lands, mark one as COMPLETED
##   - reset() — restart the sequence
##
## Designed to be safe against double-board, missing-board, and out-of-
## order feeder bugs. Used by car_jam_level.gd's existing four-lane
## track logic via a thin adapter (PassengerSequenceAdapter in
## level_integration.gd) or directly for non-visual tests.

enum PState { PENDING, FEEDER, CIRCULATING, BOARDING, COMPLETED }

class Passenger:
	var id: int
	var color: String
	var lane: int = 0
	var group_id: int = 0
	var state: int = PState.PENDING
	var release_index: int = -1 # position in feeder; -1 if not yet released

func _init(plan, initial_circulating_count: int = 40, authored_groups = null) -> void:
	plan_ref = plan
	initial_count = maxi(0, initial_circulating_count)
	_passengers.clear()
	if plan == null:
		return
	var flat = plan.flatten(authored_groups)
	for i in flat.size():
		var p = Passenger.new()
		p.id = i
		p.color = String(flat[i]["color"])
		p.lane = i % 4 # 4-wide formation
		p.group_id = int(flat[i].get("group_id", flat[i].get("wave_index", 0)))
		p.state = PState.PENDING
		# The first `initial_count` passengers are placed on the loop at start.
		if i < initial_count:
			p.state = PState.CIRCULATING
		_passengers.append(p)

## Returns a fresh Passenger inner instance. Used by the constructor
## because inner class self-reference inside _init fails to parse on
## Godot 4.7.
func new_Passenger():
	return Passenger.new()

var plan_ref = null
var initial_count: int = 0
var _passengers: Array = []

func size() -> int:
	return _passengers.size()

func initial_total() -> int:
	return initial_count

## Returns number of passengers currently pending feeder entry (haven't
## been pushed into the feeder at all).
func pending_count() -> int:
	var n := 0
	for p in _passengers:
		if int(p.state) == PState.PENDING:
			n += 1
	return n

## Returns number of passengers in feeder (FEEDER state).
func feeder_count() -> int:
	var n := 0
	for p in _passengers:
		if int(p.state) == PState.FEEDER:
			n += 1
	return n

## Returns number of passengers currently circulating on the track.
func circulating_count() -> int:
	var n := 0
	for p in _passengers:
		if int(p.state) == PState.CIRCULATING:
			n += 1
	return n

## Returns number of passengers currently mid-boarding animation.
func boarding_count() -> int:
	var n := 0
	for p in _passengers:
		if int(p.state) == PState.BOARDING:
			n += 1
	return n

## Returns number of passengers who have completed boarding.
func completed_count() -> int:
	var n := 0
	for p in _passengers:
		if int(p.state) == PState.COMPLETED:
			n += 1
	return n

## Releases the next pending passenger to the FEEDER state. Returns the
## index of the released passenger, or -1 if nothing's pending.
func try_release_one_to_feeder() -> int:
	for i in _passengers.size():
		var p = _passengers[i]
		if int(p.state) == PState.PENDING:
			p.state = PState.FEEDER
			p.release_index = i
			return i
	return -1

## Releases up to `n` passengers to the feeder at once. Returns actual count.
func release_many_to_feeder(n: int) -> int:
	var k := 0
	for i in n:
		if try_release_one_to_feeder() >= 0:
			k += 1
		else:
			break
	return k

## Marks the lead FEEDER passenger as CIRCULATING (they crossed onto the
## main loop). Returns the index moved, or -1.
func try_advance_feeder_to_loop() -> int:
	for i in _passengers.size():
		var p = _passengers[i]
		if int(p.state) == PState.FEEDER:
			p.state = PState.CIRCULATING
			return i
	return -1

## Try to reserve a passenger for boarding — returns the index of the
## passenger who was just claimed, or -1 if none matches `color` AND is
## the head of the available circulating queue. The caller is responsible
## for animating and then calling mark_boarded() or release_boarding().
##
## "Head" semantics: returns the lowest-id CIRCULATING passenger whose
## color matches. This preserves queue order. If the player wants
## four-lane parallel boarding, the runtime may call this up to 4 times
## per approach (once per lane — the existing four-lane formation allows
## up to 4 simultaneous boardings at a slot, which the existing game
## already does).
func try_claim_for_boarding(color: String) -> int:
	for i in _passengers.size():
		var p = _passengers[i]
		if int(p.state) != PState.CIRCULATING:
			continue
		if String(p.color) != color:
			continue
		p.state = PState.BOARDING
		return i
	return -1

## Confirm a passenger has completed boarding (animation done). Returns
## true if a state transition happened.
func mark_boarded(index: int) -> bool:
	if index < 0 or index >= _passengers.size():
		return false
	var p = _passengers[index]
	if int(p.state) != PState.BOARDING:
		return false
	p.state = PState.COMPLETED
	return true

## Release a boarding claim (e.g. if the seat was rejected). Returns true
## if the passenger was rolled back to CIRCULATING.
func release_boarding(index: int) -> bool:
	if index < 0 or index >= _passengers.size():
		return false
	var p = _passengers[index]
	if int(p.state) == PState.BOARDING:
		p.state = PState.CIRCULATING
		return true
	return false

## All passengers completed?
func is_complete() -> bool:
	for p in _passengers:
		if int(p.state) != PState.COMPLETED:
			return false
	return true

## Reset the entire sequence to initial state (used for restart).
func reset() -> void:
	for i in _passengers.size():
		var p = _passengers[i]
		p.state = PState.PENDING if i >= initial_count else PState.CIRCULATING
		p.release_index = -1

## Returns the color of the next unserved passenger (FEEDER or
## CIRCULATING), or "" if nothing remains. Matches the validator's
## "head color" definition.
func head_color() -> String:
	for p in _passengers:
		var st = int(p.state)
		if st == PState.FEEDER or st == PState.CIRCULATING:
			return String(p.color)
	return ""

## Returns the length of the contiguous same-color run starting at the
## head of FEEDER/CIRCULATING. Used by the boarding scheduler to know
## how many passengers can board in one animation batch.
func head_run_length() -> int:
	var run := 0
	var last := ""
	for p in _passengers:
		var st = int(p.state)
		if st != PState.FEEDER and st != PState.CIRCULATING:
			continue
		var c = String(p.color)
		if last == "":
			last = c
			run = 1
		elif c == last:
			run += 1
		else:
			break
	return run

## Snapshot for save files / debugging.
func snapshot() -> Dictionary:
	var out: Dictionary = {"initial_count": initial_count, "passengers": []}
	for p in _passengers:
		out["passengers"].append({
			"id": p.id,
			"color": p.color,
			"lane": p.lane,
			"group_id": p.group_id,
			"state": p.state,
			"release_index": p.release_index
		})
	return out

## Public accessor for tests / debug.
func passenger_at(idx: int) -> Passenger:
	if idx < 0 or idx >= _passengers.size():
		return null
	return _passengers[idx]

## Public accessor for iterating.
func all() -> Array:
	return _passengers.duplicate()
