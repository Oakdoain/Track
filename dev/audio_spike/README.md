# T-001B Real Waveform & A/V Sync Spike

## Purpose

验证《最后一次试麦》未来可能使用的真实音频区间框选玩法，重点检查以下四个时间是否一致：

```text
玩家听到声音的时间 ≈ 播放器时间 ≈ 波形位置 ≈ 鼠标框选换算时间
```

本页面只验证“播放测试音频 → 在真实预计算波形上框选 → 保存 Audio Observation → 连接两个观察 → 生成测试推理结果”的最小闭环。它不属于正式案件 UI，也不接入正式 Narrative Graph、电话或存档系统。

## How to generate the test media

测试 WAV 完全由 FFmpeg 合成，不包含互联网或第三方音频。项目内便携 FFmpeg 可用时，在项目根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\dev\audio_spike\prepare_test_audio.ps1
```

脚本会生成：

```text
res://dev/audio_spike/test_audio.wav
res://dev/audio_spike/test_audio.waveform.json
```

可通过 `-SampleCount` 调整离线波形桶数量；默认是 1024。脚本会调用现有的 `tools/audio/generate_waveform_json.ps1`，Godot 运行时不解析 PCM。

## How to run

在 Godot 4.7.2 编辑器中打开 `res://dev/audio_spike/AudioSpike.tscn`，使用“运行当前场景”（F6）。

也可从命令行运行：

```powershell
godot --path . res://dev/audio_spike/AudioSpike.tscn
```

自动验收：

```powershell
godot --headless --path . --script res://dev/audio_spike/AudioSpikeTests.gd
```

加载规则：

- WAV 与有效 waveform JSON 都存在：播放真实 WAV，并显示真实 min/max 波形。
- WAV 存在、JSON 缺失或无效：播放真实 WAV，显示程序波形，并标注 `Waveform fallback`。
- WAV 缺失：保持 T-001A 的无音频降级行为；播放控件禁用，框选闭环仍可运行。

## Waveform JSON format

```json
{
  "version": 1,
  "audio_path": "res://dev/audio_spike/test_audio.wav",
  "duration": 60.0,
  "sample_count": 1024,
  "method": "peak_min_max_normalized",
  "peaks": [[-0.1, 0.12]],
  "samples": [0.12]
}
```

每个 `peaks` 元素表示一个等长时间桶的最小/最大振幅，范围为 -1.0～1.0。`samples` 是同一桶的最大绝对振幅，作为现有正式波形消费者的向后兼容字段。

## Current targets

| Target | Time range | Internal result |
| --- | ---: | --- |
| `AUD_BG_01` | 8–14 s | `A01` |
| `AUD_REPEAT_A` | 22–28 s | `A02` |
| `AUD_REPEAT_B` | 36–42 s | `A03` |

测试音频内容：

- 8–14 秒：较明显但低音量的粉红噪声环境段。
- 22–28 秒：双音调节奏测试片段 A。
- 36–42 秒：由同一源片段复制的测试片段 B。

这些后台名称不会显示在运行页面中，波形也不会高亮目标区间。

## Current hit rules

- 目标区间覆盖率 `overlap >= 60%`。
- 玩家选区长度 `<= target duration × 1.8`。
- 可保存选区最短长度为 `0.30 s`。
- 若同时满足多个目标，选择覆盖率最高者。

## Automated validation

- [x] 原 T-001A 10 项选择、命中、连接和降级测试
- [x] waveform JSON duration 与实际音频时长一致
- [x] 0 秒映射到波形最左端
- [x] duration 映射到波形最右端
- [x] duration / 2 映射到波形中点
- [x] 22–28 秒时间/X往返误差小于 0.001 秒
- [x] 真实 waveform JSON 加载时不使用 fake waveform
- [x] waveform JSON 缺失时安全 fallback
- [x] waveform JSON 损坏时安全 fallback

## Manual A/V sync checklist

- [ ] A. 播放完整测试音频，并观察播放头连续移动。
- [ ] B. 听到 8–14 秒环境段时，确认波形同时出现明显变化。
- [ ] C. 听到 22–28 秒测试片段 A，并记住其节奏。
- [ ] D. 听到 36–42 秒重复片段 B，确认听感与 A 一致。
- [ ] E. 不参考后台目标数据，仅依靠听觉和波形框选 A、B。
- [ ] F. 保存两个 Audio Observation。
- [ ] G. 连接两个观察并得到 `R04【两段声音高度一致】`。
- [ ] H. 记录“听到的位置”和“波形显示的位置”是否存在可感知偏移。

## Not included

- 正式 22:40 音频或正式案件音轨
- 波形缩放和边缘微调
- 正式 Narrative Graph、案件 JSON、存档和调查时钟
- FFT、频谱、自动声音识别或相似度分析
- 专业音频编辑器功能

## Known issues

- 波形是离线分桶后的峰值包络，不显示桶内更细粒度的瞬态。
- 波形暂不支持缩放；精确选区的手感需要留到 T-001C 评估。
- 播放器视觉时间使用 Godot 播放位置、最后一次混音时间和输出延迟补偿；不同声卡仍可能存在一帧左右的显示差异，但不会累计漂移。
- Audio Observation 暂存在当前场景内存中，关闭页面后不会保留。
