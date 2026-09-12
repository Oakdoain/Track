extends Control

const WaveformViewScript := preload("res://dev/audio_spike/WaveformView.gd")
const FONT_SANS := preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const FONT_SANS_MEDIUM := preload("res://assets/fonts/NotoSansCJKsc-Medium.otf")
const FONT_MONO := preload("res://assets/fonts/IBMPlexMono-Regular.ttf")

const TEST_AUDIO_PATH := "res://dev/audio_spike/test_audio.wav"
const TEST_WAVEFORM_PATH := "res://dev/audio_spike/test_audio.waveform.json"
const FALLBACK_DURATION := 60.0
const WAVEFORM_DURATION_TOLERANCE := 0.05
const OVERLAP_THRESHOLD := 0.60
const MAX_SELECTION_SCALE := 1.80
const MIN_SELECTION_DURATION := 0.30

const TARGETS: Array[Dictionary] = [
	{
		"id": "AUD_BG_01",
		"start": 8.0,
		"end": 14.0,
		"result_node": "A01",
	},
	{
		"id": "AUD_REPEAT_A",
		"start": 22.0,
		"end": 28.0,
		"result_node": "A02",
	},
	{
		"id": "AUD_REPEAT_B",
		"start": 36.0,
		"end": 42.0,
		"result_node": "A03",
	},
]

const C_BACKGROUND := Color("#F7F9FF")
const C_PANEL := Color("#EEF3FF")
const C_WHITE := Color("#FFFFFF")
const C_BLUE := Color("#143FA4")
const C_BLUE_DARK := Color("#0A318A")
const C_LINE := Color("#D7DEF3")
const C_TEXT := Color("#26314C")
const C_SUBTEXT := Color("#5B6684")
const C_MUTED := Color("#8995B8")

var _audio_player: AudioStreamPlayer
var _play_button: Button
var _seek_slider: HSlider
var _time_label: Label
var _missing_audio_label: Label
var _waveform_view: Control
var _selection_label: Label
var _mark_button: Button
var _clear_button: Button
var _marker_list: ItemList
var _connect_button: Button
var _result_label: Label

var _duration_seconds: float = FALLBACK_DURATION
var _audio_available: bool = false
var _using_real_waveform: bool = false
var _waveform_duration_seconds: float = 0.0
var _waveform_load_error: String = ""
var _selection_start: float = 0.0
var _selection_end: float = 0.0
var _has_selection: bool = false
var _is_seeking: bool = false
var _resume_after_seek: bool = false
var _observations: Array[Dictionary] = []


func _ready() -> void:
	_build_interface()
	_connect_signals()
	_configure_media(TEST_AUDIO_PATH, TEST_WAVEFORM_PATH)
	_update_playback_ui(0.0)
	_update_selection_ui()
	set_process(true)


func _process(_delta: float) -> void:
	if not _audio_available or _is_seeking:
		return
	if _audio_player.playing:
		var position := _get_audible_playback_position()
		_update_playback_ui(position)


func evaluate_selection(start_time: float, end_time: float) -> String:
	var normalized_start := minf(start_time, end_time)
	var normalized_end := maxf(start_time, end_time)
	var selected_duration := normalized_end - normalized_start
	if selected_duration < MIN_SELECTION_DURATION:
		return ""

	var best_target_id := ""
	var best_overlap_ratio := 0.0
	for target in TARGETS:
		var target_start := float(target.get("start", 0.0))
		var target_end := float(target.get("end", 0.0))
		var target_duration := target_end - target_start
		if target_duration <= 0.0:
			continue
		var overlap_start := maxf(normalized_start, target_start)
		var overlap_end := minf(normalized_end, target_end)
		var overlap_length := maxf(overlap_end - overlap_start, 0.0)
		var overlap_ratio := overlap_length / target_duration
		var length_is_valid := selected_duration <= target_duration * MAX_SELECTION_SCALE
		if overlap_ratio >= OVERLAP_THRESHOLD and length_is_valid and overlap_ratio > best_overlap_ratio:
			best_overlap_ratio = overlap_ratio
			best_target_id = str(target.get("id", ""))
	return best_target_id


func create_observation(start_time: float, end_time: float) -> Dictionary:
	var normalized_start := minf(start_time, end_time)
	var normalized_end := maxf(start_time, end_time)
	if normalized_end - normalized_start < MIN_SELECTION_DURATION:
		return {}
	return {
		"id": "MARKER_%02d" % (_observations.size() + 1),
		"start": normalized_start,
		"end": normalized_end,
		"matched_target": evaluate_selection(normalized_start, normalized_end),
	}


func save_observation(start_time: float, end_time: float) -> Dictionary:
	var observation := create_observation(start_time, end_time)
	if observation.is_empty():
		return {}
	_observations.append(observation)
	var display_index := _observations.size()
	_marker_list.add_item(
		"音频观察 #%02d\n%s — %s s" % [
			display_index,
			_format_seconds(float(observation["start"]), 2),
			_format_seconds(float(observation["end"]), 2),
		]
	)
	_marker_list.set_item_metadata(_marker_list.item_count - 1, observation.duplicate(true))
	return observation.duplicate(true)


func evaluate_connection(first: Dictionary, second: Dictionary) -> String:
	var first_target := str(first.get("matched_target", ""))
	var second_target := str(second.get("matched_target", ""))
	var is_repeat_pair := (
		(first_target == "AUD_REPEAT_A" and second_target == "AUD_REPEAT_B")
		or (first_target == "AUD_REPEAT_B" and second_target == "AUD_REPEAT_A")
	)
	if is_repeat_pair:
		return "R04【两段声音高度一致】"
	return "没有形成有效连接"


func clear_temporary_selection() -> void:
	_waveform_view.clear_selection()


func get_observations() -> Array[Dictionary]:
	return _observations.duplicate(true)


func get_waveform_view_for_test() -> Control:
	return _waveform_view


func is_audio_available() -> bool:
	return _audio_available


func get_audio_status_text() -> String:
	return _missing_audio_label.text


func get_result_text() -> String:
	return _result_label.text


func get_selected_observation_indices() -> PackedInt32Array:
	return _marker_list.get_selected_items()


func get_observation_select_mode_for_test() -> ItemList.SelectMode:
	return _marker_list.select_mode


func toggle_observation_selection_for_test(index: int) -> bool:
	if index < 0 or index >= _marker_list.item_count:
		return false
	var will_select := not _marker_list.is_selected(index)
	if will_select:
		_marker_list.select(index, false)
	else:
		_marker_list.deselect(index)
	return _apply_observation_selection_limit(index, will_select)


func is_using_real_waveform() -> bool:
	return _using_real_waveform


func get_audio_duration_seconds() -> float:
	return _duration_seconds if _audio_available else 0.0


func get_waveform_duration_seconds() -> float:
	return _waveform_duration_seconds


func configure_media_for_test(audio_path: String, waveform_path: String) -> void:
	_configure_media(audio_path, waveform_path)


func _build_interface() -> void:
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _panel_style(C_BACKGROUND, C_BACKGROUND, 0))
	add_child(background)

	var page_margin := MarginContainer.new()
	page_margin.add_theme_constant_override("margin_left", 36)
	page_margin.add_theme_constant_override("margin_right", 36)
	page_margin.add_theme_constant_override("margin_top", 24)
	page_margin.add_theme_constant_override("margin_bottom", 24)
	background.add_child(page_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page_margin.add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 64.0
	page.add_child(header)

	var heading_stack := VBoxContainer.new()
	heading_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_stack.add_theme_constant_override("separation", 2)
	header.add_child(heading_stack)

	var title := _label("Audio Interaction Spike", 28, C_BLUE, FONT_SANS_MEDIUM)
	heading_stack.add_child(title)
	var notice := _label("仅用于技术验证，不属于正式案件UI", 14, C_SUBTEXT, FONT_SANS)
	heading_stack.add_child(notice)

	var code_badge := Label.new()
	code_badge.text = "T-001"
	code_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	code_badge.custom_minimum_size = Vector2(92.0, 36.0)
	code_badge.add_theme_font_override("font", FONT_MONO)
	code_badge.add_theme_font_size_override("font_size", 16)
	code_badge.add_theme_color_override("font_color", C_BLUE)
	code_badge.add_theme_stylebox_override("normal", _panel_style(C_WHITE, C_BLUE, 1))
	header.add_child(code_badge)

	_missing_audio_label = _label("", 14, C_SUBTEXT, FONT_SANS)
	_missing_audio_label.custom_minimum_size.y = 26.0
	page.add_child(_missing_audio_label)

	var playback_panel := PanelContainer.new()
	playback_panel.add_theme_stylebox_override("panel", _panel_style(C_WHITE, C_LINE, 1, 8, 8, 10, 10))
	page.add_child(playback_panel)
	var playback_row := HBoxContainer.new()
	playback_row.add_theme_constant_override("separation", 14)
	playback_panel.add_child(playback_row)

	_play_button = Button.new()
	_play_button.text = "播放"
	_play_button.custom_minimum_size = Vector2(92.0, 42.0)
	_style_button(_play_button)
	playback_row.add_child(_play_button)

	_seek_slider = HSlider.new()
	_seek_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seek_slider.min_value = 0.0
	_seek_slider.max_value = FALLBACK_DURATION
	_seek_slider.step = 0.05
	_seek_slider.custom_minimum_size.y = 42.0
	playback_row.add_child(_seek_slider)

	_time_label = _label("00:00.0 / 01:00.0", 15, C_TEXT, FONT_MONO)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.custom_minimum_size.x = 164.0
	playback_row.add_child(_time_label)

	_waveform_view = WaveformViewScript.new() as Control
	_waveform_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_waveform_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_waveform_view)

	_selection_label = _label("选区：—", 15, C_TEXT, FONT_MONO)
	_selection_label.custom_minimum_size.y = 28.0
	page.add_child(_selection_label)

	var selection_actions := HBoxContainer.new()
	selection_actions.add_theme_constant_override("separation", 10)
	page.add_child(selection_actions)
	_mark_button = Button.new()
	_mark_button.text = "标记选区"
	_mark_button.custom_minimum_size = Vector2(126.0, 42.0)
	_style_button(_mark_button)
	selection_actions.add_child(_mark_button)
	_clear_button = Button.new()
	_clear_button.text = "清除选区"
	_clear_button.custom_minimum_size = Vector2(126.0, 42.0)
	_style_button(_clear_button)
	selection_actions.add_child(_clear_button)

	var marker_header := HBoxContainer.new()
	page.add_child(marker_header)
	var marker_title := _label("Audio Observations", 18, C_BLUE, FONT_SANS_MEDIUM)
	marker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marker_header.add_child(marker_title)
	var marker_help := _label("多选两个观察后连接", 13, C_MUTED, FONT_SANS)
	marker_header.add_child(marker_help)

	_marker_list = ItemList.new()
	_marker_list.select_mode = ItemList.SELECT_TOGGLE
	_marker_list.allow_reselect = true
	_marker_list.custom_minimum_size.y = 96.0
	_marker_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_marker_list.add_theme_font_override("font", FONT_SANS)
	_marker_list.add_theme_font_size_override("font_size", 15)
	_marker_list.add_theme_color_override("font_color", C_TEXT)
	_marker_list.add_theme_color_override("font_selected_color", C_WHITE)
	_marker_list.add_theme_stylebox_override("panel", _panel_style(C_WHITE, C_LINE, 1, 10, 10, 8, 8))
	_marker_list.add_theme_stylebox_override("selected", _panel_style(C_BLUE, C_BLUE, 1, 8, 8, 5, 5))
	_marker_list.add_theme_stylebox_override("selected_focus", _panel_style(C_BLUE_DARK, C_BLUE_DARK, 1, 8, 8, 5, 5))
	page.add_child(_marker_list)

	var result_row := HBoxContainer.new()
	result_row.add_theme_constant_override("separation", 12)
	page.add_child(result_row)
	_connect_button = Button.new()
	_connect_button.text = "连接所选"
	_connect_button.custom_minimum_size = Vector2(126.0, 48.0)
	_style_button(_connect_button)
	result_row.add_child(_connect_button)
	var result_panel := PanelContainer.new()
	result_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_panel.custom_minimum_size.y = 48.0
	result_panel.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_LINE, 1, 12, 12, 8, 8))
	result_row.add_child(result_panel)
	_result_label = _label("等待连接测试", 15, C_SUBTEXT, FONT_SANS)
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_panel.add_child(_result_label)

	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "SpikeAudioPlayer"
	add_child(_audio_player)


func _connect_signals() -> void:
	_waveform_view.selection_changed.connect(_on_selection_changed)
	_waveform_view.selection_cleared.connect(_on_selection_cleared)
	_mark_button.pressed.connect(_on_mark_pressed)
	_clear_button.pressed.connect(clear_temporary_selection)
	_connect_button.pressed.connect(_on_connect_pressed)
	_marker_list.multi_selected.connect(_on_marker_multi_selected)
	_play_button.pressed.connect(_on_play_pressed)
	_seek_slider.drag_started.connect(_on_seek_drag_started)
	_seek_slider.drag_ended.connect(_on_seek_drag_ended)
	_seek_slider.value_changed.connect(_on_seek_value_changed)
	_audio_player.finished.connect(_on_audio_finished)


func _configure_media(audio_path: String, waveform_path: String) -> void:
	_audio_player.stop()
	_audio_player.stream = null
	_audio_available = false
	_using_real_waveform = false
	_waveform_duration_seconds = 0.0
	_waveform_load_error = ""
	if ResourceLoader.exists(audio_path):
		var loaded := ResourceLoader.load(audio_path)
		if loaded is AudioStream:
			_audio_player.stream = loaded as AudioStream
			_duration_seconds = maxf(_audio_player.stream.get_length(), 0.001)
			_audio_available = true
	if not _audio_available:
		_duration_seconds = FALLBACK_DURATION
		_missing_audio_label.text = "未找到 test_audio.wav，当前仅测试波形选择。"
		_missing_audio_label.add_theme_color_override("font_color", C_MUTED)
		_apply_fake_waveform()
	else:
		_using_real_waveform = _load_waveform_json(waveform_path, _duration_seconds)
		if _using_real_waveform:
			_missing_audio_label.text = "Real waveform · test_audio.wav / test_audio.waveform.json"
			_missing_audio_label.add_theme_color_override("font_color", C_SUBTEXT)
		else:
			_apply_fake_waveform()
			_missing_audio_label.text = "已加载 test_audio.wav · Waveform fallback（%s）" % _waveform_load_error
			_missing_audio_label.add_theme_color_override("font_color", C_MUTED)
	_play_button.disabled = not _audio_available
	_seek_slider.editable = _audio_available
	_seek_slider.max_value = _duration_seconds
	_waveform_view.set_duration(_duration_seconds)
	_update_playback_ui(0.0)


func _load_waveform_json(path: String, expected_duration: float) -> bool:
	if not FileAccess.file_exists(path):
		_waveform_load_error = "未找到 waveform JSON"
		return false
	var json_text := FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	var parse_result := parser.parse(json_text)
	if parse_result != OK:
		_waveform_load_error = "waveform JSON 损坏"
		return false
	if not parser.data is Dictionary:
		_waveform_load_error = "waveform JSON 根节点不是对象"
		return false
	var document := parser.data as Dictionary
	if int(document.get("version", 0)) != 1:
		_waveform_load_error = "waveform JSON 版本不受支持"
		return false
	var waveform_duration := float(document.get("duration", 0.0))
	if waveform_duration <= 0.0:
		_waveform_load_error = "waveform duration 无效"
		return false
	if absf(waveform_duration - expected_duration) > WAVEFORM_DURATION_TOLERANCE:
		_waveform_load_error = "waveform 与音频时长不一致"
		return false
	var raw_peaks: Variant = document.get("peaks", [])
	if not raw_peaks is Array:
		_waveform_load_error = "waveform peaks 缺失"
		return false
	var peak_rows := raw_peaks as Array
	if peak_rows.is_empty():
		_waveform_load_error = "waveform peaks 缺失"
		return false
	if int(document.get("sample_count", 0)) != peak_rows.size():
		_waveform_load_error = "waveform sample_count 不一致"
		return false

	var peaks := PackedVector2Array()
	peaks.resize(peak_rows.size())
	for index in range(peak_rows.size()):
		var raw_peak: Variant = peak_rows[index]
		if not raw_peak is Array:
			_waveform_load_error = "waveform peak 格式无效"
			return false
		var values := raw_peak as Array
		if values.size() != 2:
			_waveform_load_error = "waveform peak 格式无效"
			return false
		if not _is_number(values[0]) or not _is_number(values[1]):
			_waveform_load_error = "waveform peak 不是数字"
			return false
		var minimum := float(values[0])
		var maximum := float(values[1])
		if minimum < -1.0 or maximum > 1.0 or minimum > maximum:
			_waveform_load_error = "waveform peak 超出范围"
			return false
		peaks[index] = Vector2(minimum, maximum)

	_waveform_view.set_waveform_peaks(peaks)
	_waveform_duration_seconds = waveform_duration
	return true


func _apply_fake_waveform() -> void:
	_waveform_view.set_duration(_duration_seconds)
	_waveform_view.set_waveform(_generate_fake_waveform(720))
	_waveform_duration_seconds = _duration_seconds
	_using_real_waveform = false


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _get_audible_playback_position() -> float:
	var position := _audio_player.get_playback_position()
	if _audio_player.stream_paused:
		return clampf(position, 0.0, _duration_seconds)
	position += AudioServer.get_time_since_last_mix()
	position -= AudioServer.get_output_latency()
	return clampf(position, 0.0, _duration_seconds)


func _on_play_pressed() -> void:
	if not _audio_available:
		return
	if _audio_player.playing:
		_audio_player.stream_paused = not _audio_player.stream_paused
	else:
		_audio_player.play(_seek_slider.value)
	_play_button.text = "播放" if _audio_player.stream_paused else "暂停"


func _on_audio_finished() -> void:
	_play_button.text = "播放"
	_update_playback_ui(0.0)


func _on_seek_drag_started() -> void:
	if not _audio_available:
		return
	_is_seeking = true
	_resume_after_seek = _audio_player.playing and not _audio_player.stream_paused
	if _audio_player.playing:
		_audio_player.stream_paused = true


func _on_seek_drag_ended(_value_changed: bool) -> void:
	if not _audio_available:
		return
	_audio_player.seek(_seek_slider.value)
	if _audio_player.playing:
		_audio_player.stream_paused = not _resume_after_seek
	_is_seeking = false
	_play_button.text = "暂停" if _resume_after_seek else "播放"
	_update_playback_ui(_seek_slider.value)


func _on_seek_value_changed(value: float) -> void:
	if _is_seeking:
		_time_label.text = "%s / %s" % [
			_format_seconds(value, 1),
			_format_seconds(_duration_seconds, 1),
		]
		_waveform_view.set_playhead(value)


func _on_selection_changed(start_time: float, end_time: float) -> void:
	_selection_start = start_time
	_selection_end = end_time
	_has_selection = true
	_update_selection_ui()


func _on_selection_cleared() -> void:
	_has_selection = false
	_selection_start = 0.0
	_selection_end = 0.0
	_update_selection_ui()


func _update_selection_ui() -> void:
	if not _has_selection:
		_selection_label.text = "选区：—"
		_mark_button.disabled = true
		_clear_button.disabled = true
		return
	var selection_duration := _selection_end - _selection_start
	_selection_label.text = "选区：%s — %s s  （%.2f s）" % [
		_format_seconds(_selection_start, 2),
		_format_seconds(_selection_end, 2),
		selection_duration,
	]
	_mark_button.disabled = selection_duration < MIN_SELECTION_DURATION
	_clear_button.disabled = false


func _on_mark_pressed() -> void:
	if not _has_selection:
		return
	var observation := save_observation(_selection_start, _selection_end)
	if observation.is_empty():
		_result_label.text = "选区至少需要 %.2f 秒。" % MIN_SELECTION_DURATION
		return
	_result_label.text = "已保存音频观察 #%02d" % _observations.size()


func _on_connect_pressed() -> void:
	var selected := _marker_list.get_selected_items()
	if selected.size() != 2:
		_result_label.text = "请选择两个音频观察节点。"
		return
	var first := _observations[selected[0]]
	var second := _observations[selected[1]]
	var result := evaluate_connection(first, second)
	_result_label.text = "生成节点：\n%s" % result if result.begins_with("R04") else result


func _on_marker_multi_selected(index: int, selected: bool) -> void:
	_apply_observation_selection_limit(index, selected)


func _apply_observation_selection_limit(index: int, selected: bool) -> bool:
	if not selected:
		return true
	if _marker_list.get_selected_items().size() <= 2:
		return true
	_marker_list.deselect(index)
	_result_label.text = "一次最多选择两个音频观察节点。"
	return false


func _update_playback_ui(position: float) -> void:
	if not _is_seeking:
		_seek_slider.set_value_no_signal(position)
	_time_label.text = "%s / %s" % [
		_format_seconds(position, 1),
		_format_seconds(_duration_seconds, 1),
	]
	_waveform_view.set_playhead(position)


func _generate_fake_waveform(point_count: int) -> PackedFloat32Array:
	var points := PackedFloat32Array()
	points.resize(point_count)
	for index in range(point_count):
		var t := float(index) / float(maxi(point_count - 1, 1))
		var slow := sin(t * TAU * 7.0) * 0.30
		var medium := sin(t * TAU * 31.0 + 0.7) * 0.23
		var fast := sin(t * TAU * 83.0 + 1.4) * 0.13
		var envelope := 0.62 + 0.24 * sin(t * TAU * 2.0 + 0.3)
		points[index] = clampf((0.24 + absf(slow + medium + fast)) * envelope, 0.08, 0.96)
	return points


func _format_seconds(value: float, decimals: int) -> String:
	var safe_value := maxf(value, 0.0)
	var minutes := int(floor(safe_value / 60.0))
	var seconds := fmod(safe_value, 60.0)
	if decimals == 2:
		return "%02d:%05.2f" % [minutes, seconds]
	return "%02d:%04.1f" % [minutes, seconds]


func _label(text_value: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style_button(button: Button) -> void:
	button.add_theme_font_override("font", FONT_SANS_MEDIUM)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", C_BLUE)
	button.add_theme_color_override("font_hover_color", C_WHITE)
	button.add_theme_color_override("font_pressed_color", C_WHITE)
	button.add_theme_color_override("font_focus_color", C_BLUE)
	button.add_theme_color_override("font_disabled_color", C_MUTED)
	button.add_theme_stylebox_override("normal", _panel_style(C_WHITE, C_BLUE, 1, 8, 8, 6, 6))
	button.add_theme_stylebox_override("hover", _panel_style(C_BLUE, C_BLUE, 1, 8, 8, 6, 6))
	button.add_theme_stylebox_override("pressed", _panel_style(C_BLUE_DARK, C_BLUE_DARK, 1, 8, 8, 6, 6))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, C_BLUE, 1, 8, 8, 6, 6))
	button.add_theme_stylebox_override("disabled", _panel_style(C_PANEL, C_LINE, 1, 8, 8, 6, 6))


func _panel_style(
	fill: Color,
	border: Color,
	border_width: int,
	margin_left: int = 0,
	margin_right: int = 0,
	margin_top: int = 0,
	margin_bottom: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = float(margin_left)
	style.content_margin_right = float(margin_right)
	style.content_margin_top = float(margin_top)
	style.content_margin_bottom = float(margin_bottom)
	return style
