extends Node

## Procedural Audio Manager.
## Synthesizes punchy, cheerful sound effects and casual background music
## on the fly using AudioStreamWAV. Zero external asset files needed,
## cross-platform, and fully responsive to SettingsManager toggles.

signal sfx_played(name: String)

const SFX_UI := "ui"
const SFX_SELECT := "select"
const SFX_BLOCKED := "blocked"
const SFX_MOVE := "move"
const SFX_PARKING := "parking"
const SFX_BOARD := "board"
const SFX_DEPART := "depart"
const SFX_VICTORY := "victory"
const SFX_FAILURE := "failure"
const SFX_BOOSTER := "booster"

const MIX_RATE: int = 44100

var _players: Array[AudioStreamPlayer] = []
var _player_index: int = 0
var _music_player: AudioStreamPlayer

var _streams: Dictionary = {}
var _music_stream: AudioStreamWAV

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_players()
	_generate_all_sfx()
	_generate_music()
	if SettingsManager.music_enabled():
		play_music()

func _init_players() -> void:
	for i in 8:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = -12.0
	add_child(_music_player)

func play(sfx_name: String) -> void:
	if not SettingsManager.sfx_enabled():
		return
	emit_signal("sfx_played", sfx_name)
	if not _streams.has(sfx_name):
		return
	var stream: AudioStreamWAV = _streams[sfx_name]
	var p: AudioStreamPlayer = _players[_player_index]
	_player_index = (_player_index + 1) % _players.size()
	p.stream = stream
	p.play()

func play_music(_track: String = "") -> void:
	if not SettingsManager.music_enabled():
		return
	if _music_player == null or _music_stream == null:
		return
	if _music_player.playing:
		return
	_music_player.stream = _music_stream
	_music_player.play()

func stop_music() -> void:
	if _music_player != null and _music_player.playing:
		_music_player.stop()

# -----------------------------------------------------------------
# PROCEDURAL SOUND SYNTHESIS
# -----------------------------------------------------------------

func _generate_all_sfx() -> void:
	_streams[SFX_UI] = _gen_ui_click()
	_streams[SFX_SELECT] = _gen_select_pop()
	_streams[SFX_BLOCKED] = _gen_blocked_horn()
	_streams[SFX_MOVE] = _gen_move_vroom()
	_streams[SFX_PARKING] = _gen_parking_chirp()
	_streams[SFX_BOARD] = _gen_board_chime()
	_streams[SFX_DEPART] = _gen_depart_horn()
	_streams[SFX_VICTORY] = _gen_victory_fanfare()
	_streams[SFX_FAILURE] = _gen_failure_buzzer()
	_streams[SFX_BOOSTER] = _gen_booster_sparkle()

func _gen_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var count: int = samples.size()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var val: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, val)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = 0
	return stream

func _gen_ui_click() -> AudioStreamWAV:
	var dur: float = 0.05
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 60.0)
		var s: float = sin(t * 800.0 * TAU) * 0.4 + sin(t * 1600.0 * TAU) * 0.2
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_select_pop() -> AudioStreamWAV:
	var dur: float = 0.09
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var freq: float = lerpf(350.0, 720.0, t / dur)
		var env: float = sin((t / dur) * PI)
		var s: float = sin(t * freq * TAU) * 0.5
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_blocked_horn() -> AudioStreamWAV:
	var dur: float = 0.2
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = 1.0 - (t / dur)
		var s1: float = float(signf(sin(t * 165.0 * TAU))) * 0.25
		var s2: float = float(signf(sin(t * 135.0 * TAU))) * 0.25
		samples[i] = (s1 + s2) * env
	return _gen_wav(samples)

func _gen_move_vroom() -> AudioStreamWAV:
	var dur: float = 0.28
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var freq: float = lerpf(180.0, 360.0, t / dur)
		var env: float = sin((t / dur) * PI)
		var s: float = sin(t * freq * TAU) * 0.4 + sin(t * freq * 2.0 * TAU) * 0.2
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_parking_chirp() -> AudioStreamWAV:
	var dur: float = 0.12
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var freq: float = lerpf(900.0, 450.0, t / dur)
		var env: float = exp(-t * 25.0)
		var s: float = sin(t * freq * TAU) * 0.4
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_board_chime() -> AudioStreamWAV:
	var dur: float = 0.16
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 18.0)
		var s: float = sin(t * 659.25 * TAU) * 0.35 + sin(t * 1318.5 * TAU) * 0.18
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_depart_horn() -> AudioStreamWAV:
	var dur: float = 0.38
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = 1.0 - (t / dur)
		var beep_gate: float = 1.0 if (t < 0.1 or (t > 0.14 and t < 0.24)) else 0.0
		var horn: float = (sin(t * 440.0 * TAU) + sin(t * 554.37 * TAU)) * 0.25 * beep_gate
		var rev: float = sin(t * (180.0 + t * 400.0) * TAU) * 0.2 * (t / dur)
		samples[i] = (horn + rev) * env
	return _gen_wav(samples)

func _gen_victory_fanfare() -> AudioStreamWAV:
	var dur: float = 0.9
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50, 1567.98]
	var note_dur: float = 0.15
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var note_idx: int = clampi(int(t / note_dur), 0, notes.size() - 1)
		var note_t: float = fmod(t, note_dur)
		var freq: float = notes[note_idx]
		var env: float = exp(-note_t * 6.0) if note_idx < notes.size() - 1 else exp(-(t - 0.6) * 4.0)
		var s: float = (sin(t * freq * TAU) * 0.35 + sin(t * freq * 2.0 * TAU) * 0.15) * env
		samples[i] = s
	return _gen_wav(samples)

func _gen_failure_buzzer() -> AudioStreamWAV:
	var dur: float = 0.5
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var freq: float = lerpf(260.0, 110.0, t / dur)
		var env: float = 1.0 - (t / dur)
		var s: float = (sin(t * freq * TAU) + float(signf(sin(t * freq * TAU))) * 0.5) * 0.3
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_booster_sparkle() -> AudioStreamWAV:
	var dur: float = 0.45
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [659.25, 783.99, 987.77, 1318.51, 1567.98, 1975.53]
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var note_idx: int = clampi(int(t / 0.07), 0, notes.size() - 1)
		var note_t: float = fmod(t, 0.07)
		var freq: float = notes[note_idx]
		var env: float = exp(-note_t * 12.0)
		var s: float = sin(t * freq * TAU) * 0.35 * env
		samples[i] = s
	return _gen_wav(samples)

func _generate_music() -> void:
	var bar_dur: float = 1.0
	var total_dur: float = 8.0
	var count: int = int(float(MIX_RATE) * total_dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var chord_roots: Array[float] = [261.63, 220.0, 174.61, 196.0, 261.63, 220.0, 174.61, 196.0]
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var bar_idx: int = clampi(int(t / bar_dur), 0, chord_roots.size() - 1)
		var root: float = chord_roots[bar_idx]
		var bar_t: float = fmod(t, bar_dur)
		var env: float = exp(-bar_t * 2.5) * 0.15
		var bass: float = sin(t * root * 0.5 * TAU) * 0.12 * exp(-bar_t * 1.5)
		var chord: float = (sin(t * root * TAU) + sin(t * (root * 1.5) * TAU) + sin(t * (root * 2.0) * TAU)) * env
		var melody_env: float = exp(-fmod(bar_t, 0.5) * 6.0) * 0.08
		var melody: float = sin(t * (root * 2.5) * TAU) * melody_env
		samples[i] = bass + chord + melody
	_music_stream = _gen_wav(samples, true)