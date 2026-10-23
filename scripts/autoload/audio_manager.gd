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
const SFX_FAILURE_ALARM := "failure_alarm"
const SFX_BOOSTER := "booster"
const SFX_COIN := "coin"
const SFX_FIREWORK := "firework"

const MIX_RATE: int = 44100

var _players: Array[AudioStreamPlayer] = []
var _player_index: int = 0
var _music_player: AudioStreamPlayer
var _alarm_player: AudioStreamPlayer

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
	_alarm_player = AudioStreamPlayer.new()
	_alarm_player.bus = "Master"
	_alarm_player.volume_db = -8.0
	add_child(_alarm_player)

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

func play_alarm_loop() -> void:
	if not SettingsManager.sfx_enabled():
		return
	if _alarm_player == null or not _streams.has(SFX_FAILURE_ALARM):
		return
	if _alarm_player.playing:
		return
	_alarm_player.stream = _streams[SFX_FAILURE_ALARM]
	_alarm_player.play()

func stop_alarm_loop() -> void:
	if _alarm_player != null and _alarm_player.playing:
		_alarm_player.stop()

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
	_streams[SFX_FAILURE_ALARM] = _gen_failure_alarm()
	_streams[SFX_BOOSTER] = _gen_booster_sparkle()
	_streams[SFX_COIN] = _gen_coin_clink()
	_streams[SFX_FIREWORK] = _gen_firework_pop()

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
	# Smooth, warm wooden/bubble tick (like high-end iOS UI)
	var dur: float = 0.045
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var attack: float = minf(1.0, t / 0.003)
		var env: float = attack * exp(-t * 90.0)
		var s: float = sin(t * 520.0 * TAU) * 0.42 + sin(t * 1040.0 * TAU) * 0.18 + sin(t * 260.0 * TAU) * 0.12
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_select_pop() -> AudioStreamWAV:
	# Juicy, warm, resonant bubble pop
	var dur: float = 0.085
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var norm_t: float = t / dur
		var freq: float = lerpf(300.0, 760.0, sqrt(norm_t))
		var env: float = sin(norm_t * PI) * exp(-t * 12.0)
		var s: float = sin(t * freq * TAU) * 0.50 + sin(t * freq * 2.0 * TAU) * 0.15
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_blocked_horn() -> AudioStreamWAV:
	# Smooth, warm friendly rubbery double-knock (zero harsh buzz)
	var dur: float = 0.18
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var env1: float = exp(-t * 40.0)
		var tap1: float = sin(t * lerpf(220.0, 130.0, t / 0.08) * TAU) * env1 * 0.40
		var tap2: float = 0.0
		if t > 0.05:
			var t2: float = t - 0.05
			var env2: float = exp(-t2 * 45.0)
			tap2 = sin(t2 * lerpf(180.0, 110.0, t2 / 0.08) * TAU) * env2 * 0.28
		samples[i] = tap1 + tap2
	return _gen_wav(samples)

func _gen_move_vroom() -> AudioStreamWAV:
	# Smooth electric transit acceleration glide + warm pneumatic finish
	var dur: float = 0.30
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var norm_t: float = t / dur
		var freq: float = lerpf(160.0, 360.0, norm_t * norm_t)
		var env: float = sin(norm_t * PI) * (1.0 - norm_t * 0.3)
		var tone: float = sin(t * freq * TAU) * 0.35 + sin(t * freq * 2.0 * TAU) * 0.16 + sin(t * freq * 0.5 * TAU) * 0.18
		samples[i] = tone * env
	return _gen_wav(samples)

func _gen_parking_chirp() -> AudioStreamWAV:
	# Satisfying smooth pneumatic lock & gentle chime
	var dur: float = 0.14
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 24.0)
		var s: float = sin(t * 587.33 * TAU) * 0.36 + sin(t * 1174.66 * TAU) * 0.18 + sin(t * 1761.99 * TAU) * 0.08
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_board_chime() -> AudioStreamWAV:
	# Sparkling musical crystal boarding chime (C6 + E6 + G6)
	var dur: float = 0.18
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 16.0)
		var s: float = sin(t * 1046.50 * TAU) * 0.30 + sin(t * 1318.51 * TAU) * 0.22 + sin(t * 1567.98 * TAU) * 0.14
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_depart_horn() -> AudioStreamWAV:
	# Cheerful airport transit two-tone chime (C5 -> E5/G5 chord)
	var dur: float = 0.36
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var s: float = 0.0
		if t < 0.14:
			var env1: float = exp(-t * 12.0)
			s = (sin(t * 523.25 * TAU) * 0.32 + sin(t * 1046.50 * TAU) * 0.12) * env1
		else:
			var t2: float = t - 0.14
			var env2: float = exp(-t2 * 10.0)
			s = (sin(t * 659.25 * TAU) * 0.26 + sin(t * 783.99 * TAU) * 0.24 + sin(t * 1318.51 * TAU) * 0.10) * env2
		samples[i] = s
	return _gen_wav(samples)

func _gen_victory_fanfare() -> AudioStreamWAV:
	# Sparkling orchestral celebration arpeggio: C5 -> E5 -> G5 -> C6 -> E6
	var dur: float = 0.95
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50, 1318.51]
	var note_dur: float = 0.14
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var note_idx: int = clampi(int(t / note_dur), 0, notes.size() - 1)
		var note_t: float = fmod(t, note_dur)
		var freq: float = notes[note_idx]
		var env: float = exp(-note_t * 6.5) if note_idx < notes.size() - 1 else exp(-(t - 0.56) * 3.5)
		var s: float = (sin(t * freq * TAU) * 0.32 + sin(t * freq * 2.0 * TAU) * 0.14 + sin(t * freq * 0.5 * TAU) * 0.10) * env
		samples[i] = s
	return _gen_wav(samples)

func _gen_failure_buzzer() -> AudioStreamWAV:
	# Gentle, friendly descending minor chord (A minor) - zero harsh buzzing
	var dur: float = 0.55
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [440.0, 392.0, 349.23, 329.63]
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var note_idx: int = clampi(int(t / 0.13), 0, notes.size() - 1)
		var note_t: float = fmod(t, 0.13)
		var freq: float = notes[note_idx]
		var env: float = exp(-note_t * 8.0) * (1.0 - t / dur)
		var s: float = (sin(t * freq * TAU) * 0.30 + sin(t * freq * 0.5 * TAU) * 0.15) * env
		samples[i] = s
	return _gen_wav(samples)

func _gen_failure_alarm() -> AudioStreamWAV:
	# Smooth marimba pulsing warning chime (587Hz / 440Hz soft pulses)
	var dur: float = 3.0
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var pulse_t: float = fmod(t, 0.5)
		var freq: float = 587.33 if fmod(t, 1.0) < 0.5 else 440.0
		var env: float = exp(-pulse_t * 9.0) if pulse_t < 0.38 else 0.0
		var s: float = (sin(t * freq * TAU) * 0.22 + sin(t * freq * 2.0 * TAU) * 0.08) * env
		samples[i] = s
	return _gen_wav(samples, true)

func _gen_booster_sparkle() -> AudioStreamWAV:
	# Delicate fairy bell sparkle
	var dur: float = 0.45
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [783.99, 987.77, 1174.66, 1318.51, 1567.98, 1975.53]
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var note_idx: int = clampi(int(t / 0.065), 0, notes.size() - 1)
		var note_t: float = fmod(t, 0.065)
		var freq: float = notes[note_idx]
		var env: float = exp(-note_t * 14.0)
		var s: float = (sin(t * freq * TAU) * 0.30 + sin(t * freq * 2.0 * TAU) * 0.10) * env
		samples[i] = s
	return _gen_wav(samples)

func _generate_music() -> void:
	# Cozy, lush chillout Rhodes electric piano progression (8 bars, seamlessly looped)
	var bar_dur: float = 1.25
	var total_dur: float = 10.0
	var count: int = int(float(MIX_RATE) * total_dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	# Chords: Cmaj7, Am7, Dm7, G7, Em7, Am7, Fmaj7, G7
	var chords = [
		[261.63, 329.63, 392.00, 493.88], # Cmaj7
		[220.00, 261.63, 329.63, 392.00], # Am7
		[146.83, 220.00, 261.63, 349.23], # Dm7
		[196.00, 246.94, 293.66, 349.23], # G7
		[164.81, 246.94, 293.66, 392.00], # Em7
		[220.00, 261.63, 329.63, 392.00], # Am7
		[174.61, 261.63, 329.63, 440.00], # Fmaj7
		[196.00, 293.66, 349.23, 440.00], # G11
	]
	var bass_roots = [130.81, 110.00, 73.42, 98.00, 82.41, 110.00, 87.31, 98.00]
	var melodies = [523.25, 493.88, 440.00, 392.00, 440.00, 493.88, 523.25, 587.33]

	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var bar_idx: int = clampi(int(t / bar_dur), 0, chords.size() - 1)
		var bar_t: float = fmod(t, bar_dur)
		var chord: Array = chords[bar_idx]
		var bass: float = bass_roots[bar_idx]
		var mel: float = melodies[bar_idx]

		# Warm bass
		var bass_env: float = exp(-bar_t * 1.8)
		var bass_val: float = (sin(t * bass * TAU) * 0.16 + sin(t * bass * 2.0 * TAU) * 0.06) * bass_env

		# Soft Rhodes piano chord (warm sine with gentle bell overtone)
		var chord_env: float = exp(-bar_t * 2.2) * 0.08
		var chord_val: float = 0.0
		for freq in chord:
			chord_val += sin(t * freq * TAU) + sin(t * freq * 2.0 * TAU) * 0.18
		chord_val *= chord_env

		# Sweet, delicate music box melody on beat 2
		var mel_t: float = fmod(bar_t, 0.625)
		var mel_env: float = exp(-mel_t * 5.0) * 0.05
		var mel_val: float = (sin(t * mel * TAU) * 0.8 + sin(t * mel * 2.0 * TAU) * 0.2) * mel_env

		samples[i] = bass_val + chord_val + mel_val
	_music_stream = _gen_wav(samples, true)

func _gen_coin_clink() -> AudioStreamWAV:
	var dur: float = 0.16
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 22.0)
		var s: float = (sin(t * 1975.53 * TAU) * 0.4 + sin(t * 2637.02 * TAU) * 0.25 + sin(t * 3951.07 * TAU) * 0.1) * env
		samples[i] = s
	return _gen_wav(samples)

func _gen_firework_pop() -> AudioStreamWAV:
	var dur: float = 0.30
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 12.0)
		var noise: float = randf_range(-0.25, 0.25) * env
		var thump: float = sin(t * lerpf(340.0, 80.0, t / dur) * TAU) * 0.35 * env
		samples[i] = thump + noise
	return _gen_wav(samples)