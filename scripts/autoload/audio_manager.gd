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
	# Velvety, warm rounded wooden/bubble tap (iOS haptic style - zero click harshness)
	var dur: float = 0.045
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var attack: float = minf(1.0, t / 0.004)
		var env: float = attack * exp(-t * 60.0)
		var freq: float = lerpf(320.0, 200.0, t / dur)
		var s: float = sin(t * freq * TAU) * 0.40 + sin(t * freq * 2.0 * TAU) * 0.10
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_select_pop() -> AudioStreamWAV:
	# Gentle, juicy, rounded waterdrop pop
	var dur: float = 0.08
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var norm_t: float = t / dur
		var attack: float = minf(1.0, t / 0.005)
		var freq: float = lerpf(260.0, 480.0, sqrt(norm_t))
		var env: float = attack * exp(-t * 22.0)
		var s: float = sin(t * freq * TAU) * 0.42 + sin(t * freq * 2.0 * TAU) * 0.08
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_blocked_horn() -> AudioStreamWAV:
	# Warm, polite wooden marimba double tap (pure mellow sines, zero harsh buzz)
	var dur: float = 0.18
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var att1: float = minf(1.0, t / 0.005)
		var env1: float = att1 * exp(-t * 32.0)
		var tap1: float = (sin(t * 180.0 * TAU) * 0.32 + sin(t * 360.0 * TAU) * 0.08) * env1
		var tap2: float = 0.0
		if t > 0.06:
			var t2: float = t - 0.06
			var att2: float = minf(1.0, t2 / 0.005)
			var env2: float = att2 * exp(-t2 * 34.0)
			tap2 = (sin(t2 * 140.0 * TAU) * 0.28 + sin(t2 * 280.0 * TAU) * 0.06) * env2
		samples[i] = tap1 + tap2
	return _gen_wav(samples)

func _gen_move_vroom() -> AudioStreamWAV:
	# Silky-smooth electric glide purr with soft Tukey cosine fade
	var dur: float = 0.28
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var norm_t: float = t / dur
		var freq: float = lerpf(140.0, 260.0, norm_t * norm_t)
		var env: float = sin(norm_t * PI)
		var tone: float = sin(t * freq * TAU) * 0.30 + sin(t * freq * 2.0 * TAU) * 0.10 + sin(t * freq * 0.5 * TAU) * 0.12
		samples[i] = tone * env
	return _gen_wav(samples)

func _gen_parking_chirp() -> AudioStreamWAV:
	# Smooth, mellow warm Rhodes arrival chime (C5 + G5)
	var dur: float = 0.15
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var attack: float = minf(1.0, t / 0.006)
		var env: float = attack * exp(-t * 16.0)
		var s: float = sin(t * 523.25 * TAU) * 0.32 + sin(t * 783.99 * TAU) * 0.18 + sin(t * 1046.50 * TAU) * 0.06
		samples[i] = s * env
	return _gen_wav(samples)

func _gen_board_chime() -> AudioStreamWAV:
	# Warm, gentle, cozy kalimba / wooden marimba boarding chime (A4 + C#5 + E5 pentatonic triad)
	# Smooth attack and warm fundamental eliminate harsh digital treble ping completely
	var dur: float = 0.16
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var attack: float = minf(1.0, t / 0.005)
		var env: float = attack * exp(-t * 12.0)
		var s: float = (sin(t * 440.00 * TAU) * 0.42 + sin(t * 554.37 * TAU) * 0.26 + sin(t * 659.25 * TAU) * 0.16 + sin(t * 880.00 * TAU) * 0.05) * env
		samples[i] = s
	return _gen_wav(samples)

func _gen_depart_horn() -> AudioStreamWAV:
	# Cheerful, warm two-tone transit chime (G4 -> C5/E5 warm chord)
	var dur: float = 0.35
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var s: float = 0.0
		if t < 0.13:
			var att1: float = minf(1.0, t / 0.006)
			var env1: float = att1 * exp(-t * 10.0)
			s = (sin(t * 392.00 * TAU) * 0.34 + sin(t * 784.00 * TAU) * 0.08) * env1
		else:
			var t2: float = t - 0.13
			var att2: float = minf(1.0, t2 / 0.006)
			var env2: float = att2 * exp(-t2 * 9.0)
			s = (sin(t * 523.25 * TAU) * 0.28 + sin(t * 659.25 * TAU) * 0.22 + sin(t * 1046.50 * TAU) * 0.06) * env2
		samples[i] = s
	return _gen_wav(samples)

func _gen_victory_fanfare() -> AudioStreamWAV:
	# Warm, joyful marimba / vibraphone celebration arpeggio: C5 -> E5 -> G5 -> C6
	var dur: float = 0.85
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var note_dur: float = 0.14
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var note_idx: int = clampi(int(t / note_dur), 0, notes.size() - 1)
		var note_t: float = fmod(t, note_dur)
		var freq: float = notes[note_idx]
		var att: float = minf(1.0, note_t / 0.006)
		var env: float = att * (exp(-note_t * 6.0) if note_idx < notes.size() - 1 else exp(-(t - 0.42) * 3.5))
		var s: float = (sin(t * freq * TAU) * 0.32 + sin(t * freq * 2.0 * TAU) * 0.08 + sin(t * freq * 0.5 * TAU) * 0.12) * env
		samples[i] = s
	return _gen_wav(samples)

func _gen_failure_buzzer() -> AudioStreamWAV:
	# Gentle, cozy descending marimba phrase (E4 -> D4 -> C4 -> A3) - zero harsh buzz
	var dur: float = 0.50
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [329.63, 293.66, 261.63, 220.00]
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var note_idx: int = clampi(int(t / 0.12), 0, notes.size() - 1)
		var note_t: float = fmod(t, 0.12)
		var freq: float = notes[note_idx]
		var att: float = minf(1.0, note_t / 0.006)
		var env: float = att * exp(-note_t * 7.5) * (1.0 - t / dur)
		var s: float = (sin(t * freq * TAU) * 0.30 + sin(t * freq * 0.5 * TAU) * 0.15) * env
		samples[i] = s
	return _gen_wav(samples)

func _gen_failure_alarm() -> AudioStreamWAV:
	# Smooth, gentle pulsing marimba warning tone (392Hz / 329Hz)
	var dur: float = 2.0
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var pulse_t: float = fmod(t, 0.5)
		var freq: float = 392.00 if fmod(t, 1.0) < 0.5 else 329.63
		var att: float = minf(1.0, pulse_t / 0.01)
		var env: float = att * exp(-pulse_t * 8.0) if pulse_t < 0.40 else 0.0
		var s: float = (sin(t * freq * TAU) * 0.22 + sin(t * freq * 2.0 * TAU) * 0.05) * env
		samples[i] = s
	return _gen_wav(samples, true)

func _gen_booster_sparkle() -> AudioStreamWAV:
	# Delicate, silky fairy chime with soft attacks
	var dur: float = 0.40
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [783.99, 987.77, 1174.66, 1318.51, 1567.98]
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var note_idx: int = clampi(int(t / 0.075), 0, notes.size() - 1)
		var note_t: float = fmod(t, 0.075)
		var freq: float = notes[note_idx]
		var att: float = minf(1.0, note_t / 0.005)
		var env: float = att * exp(-note_t * 12.0)
		var s: float = (sin(t * freq * TAU) * 0.26 + sin(t * freq * 2.0 * TAU) * 0.06) * env
		samples[i] = s
	return _gen_wav(samples)

func _generate_music() -> void:
	# Cozy, lush chillout Rhodes electric piano progression (8 bars, seamlessly looped)
	var bar_dur: float = 1.25
	var total_dur: float = 10.0
	var count: int = int(float(MIX_RATE) * total_dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	# Warm chords: Cmaj7, Am7, Dm7, G7, Em7, Am7, Fmaj7, G7
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

		# Warm electric bass
		var bass_att: float = minf(1.0, bar_t / 0.01)
		var bass_env: float = bass_att * exp(-bar_t * 1.6)
		var bass_val: float = (sin(t * bass * TAU) * 0.16 + sin(t * bass * 2.0 * TAU) * 0.04) * bass_env

		# Soft Rhodes piano chord (pure warm sines with soft 10ms attack and gentle decay)
		var chord_att: float = minf(1.0, bar_t / 0.015)
		var chord_env: float = chord_att * exp(-bar_t * 1.8) * 0.075
		var chord_val: float = 0.0
		for freq in chord:
			chord_val += sin(t * freq * TAU) + sin(t * freq * 2.0 * TAU) * 0.10
		chord_val *= chord_env

		# Delicate, mellow music box melody
		var mel_t: float = fmod(bar_t, 0.625)
		var mel_att: float = minf(1.0, mel_t / 0.008)
		var mel_env: float = mel_att * exp(-mel_t * 4.5) * 0.04
		var mel_val: float = (sin(t * mel * TAU) * 0.8 + sin(t * mel * 2.0 * TAU) * 0.15) * mel_env

		samples[i] = bass_val + chord_val + mel_val
	_music_stream = _gen_wav(samples, true)

func _gen_coin_clink() -> AudioStreamWAV:
	# Gentle, warm ceramic clink
	var dur: float = 0.14
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var attack: float = minf(1.0, t / 0.003)
		var env: float = attack * exp(-t * 24.0)
		var s: float = (sin(t * 1318.51 * TAU) * 0.35 + sin(t * 1760.00 * TAU) * 0.20) * env
		samples[i] = s
	return _gen_wav(samples)

func _gen_firework_pop() -> AudioStreamWAV:
	# Soft, festive poof (low-pass filtered warm thump)
	var dur: float = 0.25
	var count: int = int(float(MIX_RATE) * dur)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 14.0)
		var noise: float = randf_range(-0.15, 0.15) * env
		var thump: float = sin(t * lerpf(240.0, 70.0, t / dur) * TAU) * 0.30 * env
		samples[i] = thump + noise
	return _gen_wav(samples)