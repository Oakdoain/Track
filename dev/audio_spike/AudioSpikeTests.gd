extends SceneTree

const AudioSpikeScene := preload("res://dev/audio_spike/AudioSpike.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var spike := AudioSpikeScene.instantiate()
	root.add_child(spike)
	await process_frame
	await process_frame

	_check(spike.evaluate_selection(8.0, 14.0) == "AUD_BG_01", "测试1：8–14 秒命中 AUD_BG_01")
	_check(spike.evaluate_selection(22.0, 28.0) == "AUD_REPEAT_A", "测试2：22–28 秒命中 AUD_REPEAT_A")
	_check(spike.evaluate_selection(36.0, 42.0) == "AUD_REPEAT_B", "测试3：36–42 秒命中 AUD_REPEAT_B")

	var repeat_a: Dictionary = spike.save_observation(22.0, 28.0)
	var repeat_b: Dictionary = spike.save_observation(36.0, 42.0)
	var background: Dictionary = spike.save_observation(8.0, 14.0)
	_check(
		spike.evaluate_connection(repeat_a, repeat_b) == "R04【两段声音高度一致】",
		"测试4：Repeat A + Repeat B 生成 R04"
	)
	_check(
		spike.evaluate_connection(background, repeat_a) == "没有形成有效连接",
		"测试5：BG + Repeat A 不形成有效连接"
	)
	_check(spike.evaluate_selection(0.0, 60.0).is_empty(), "测试6：0–60 秒不命中任何目标")
	_check(spike.evaluate_selection(13.2, 15.0).is_empty(), "测试7：低重合选区不命中")

	var waveform: Control = spike.get_waveform_view_for_test()
	waveform.set_selection(28.0, 22.0)
	var normalized: Vector2 = waveform.get_selection()
	_check(is_equal_approx(normalized.x, 22.0) and is_equal_approx(normalized.y, 28.0), "测试8：反向拖拽标准化为 22–28 秒")

	var saved_count: int = spike.get_observations().size()
	spike.clear_temporary_selection()
	_check(not waveform.has_selection() and spike.get_observations().size() == saved_count, "测试9：清除临时选区不删除已保存观察")

	spike.configure_media_for_test(
		"res://dev/audio_spike/missing_test_audio.wav",
		"res://dev/audio_spike/missing_test_audio.waveform.json"
	)
	var missing_audio_ok: bool = (
		not spike.is_audio_available()
		and spike.get_audio_status_text() == "未找到 test_audio.wav，当前仅测试波形选择。"
	)
	_check(missing_audio_ok, "测试10：缺少 test_audio.wav 时场景仍可运行")

	spike.configure_media_for_test(
		"res://dev/audio_spike/test_audio.wav",
		"res://dev/audio_spike/test_audio.waveform.json"
	)
	await process_frame
	var duration_delta: float = absf(
		spike.get_audio_duration_seconds() - spike.get_waveform_duration_seconds()
	)
	_check(duration_delta <= 0.05, "测试11：waveform JSON 与音频时长误差不超过 0.05 秒")

	waveform = spike.get_waveform_view_for_test()
	var waveform_width: float = waveform.size.x
	_check(is_equal_approx(waveform.time_to_x(0.0), 0.0), "测试12：0 秒映射到波形最左端")
	_check(
		is_equal_approx(waveform.time_to_x(spike.get_audio_duration_seconds()), waveform_width),
		"测试13：音频终点映射到波形最右端"
	)
	_check(
		is_equal_approx(waveform.time_to_x(spike.get_audio_duration_seconds() * 0.5), waveform_width * 0.5),
		"测试14：音频中点映射到波形中点"
	)
	var roundtrip_error := maxf(
		absf(waveform.x_to_time(waveform.time_to_x(22.0)) - 22.0),
		absf(waveform.x_to_time(waveform.time_to_x(28.0)) - 28.0)
	)
	_check(roundtrip_error < 0.001, "测试15：22–28 秒时间/X往返误差小于 0.001 秒")
	_check(
		spike.is_using_real_waveform() and waveform.get_waveform_peak_count() == 1024,
		"测试16：真实 waveform JSON 成功加载且未使用假波形"
	)

	spike.configure_media_for_test(
		"res://dev/audio_spike/test_audio.wav",
		"res://dev/audio_spike/missing.waveform.json"
	)
	_check(
		not spike.is_using_real_waveform() and "Waveform fallback" in spike.get_audio_status_text(),
		"测试17：waveform JSON 缺失时正确 fallback"
	)

	var corrupt_path := "user://audio_spike_corrupt.waveform.json"
	var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	if corrupt_file:
		corrupt_file.store_string("{ waveform is broken")
		corrupt_file.close()
	spike.configure_media_for_test("res://dev/audio_spike/test_audio.wav", corrupt_path)
	_check(
		not spike.is_using_real_waveform() and "Waveform fallback" in spike.get_audio_status_text(),
		"测试18：损坏的 waveform JSON 安全 fallback"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))

	_check(
		spike.get_observation_select_mode_for_test() == ItemList.SELECT_TOGGLE
		and spike.toggle_observation_selection_for_test(0)
		and spike.get_selected_observation_indices() == PackedInt32Array([0]),
		"测试19：SELECT_TOGGLE 模式下单击观察节点即可选中"
	)
	_check(
		spike.toggle_observation_selection_for_test(1)
		and spike.get_selected_observation_indices() == PackedInt32Array([0, 1]),
		"测试20：单击第二个节点时第一个保持选中"
	)
	_check(
		spike.toggle_observation_selection_for_test(0)
		and spike.get_selected_observation_indices() == PackedInt32Array([1]),
		"测试21：再次单击已选节点可以取消"
	)
	spike.toggle_observation_selection_for_test(0)
	var third_selection_accepted: bool = spike.toggle_observation_selection_for_test(2)
	_check(
		not third_selection_accepted
		and spike.get_selected_observation_indices() == PackedInt32Array([0, 1])
		and spike.get_result_text() == "一次最多选择两个音频观察节点。",
		"测试22：第三个节点被拒绝并显示上限提示"
	)

	spike.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Audio Spike acceptance: 22/22 passed")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("Audio Spike acceptance: %d/22 passed" % (22 - _failures.size()))
	quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_failures.append(label)
