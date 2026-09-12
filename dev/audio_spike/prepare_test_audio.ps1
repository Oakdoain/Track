param(
    [int]$SampleCount = 1024,
    [string]$FfmpegPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
if ([string]::IsNullOrWhiteSpace($FfmpegPath)) {
    $portableFfmpeg = Join-Path $projectRoot "tools/bin/ffmpeg/ffmpeg.exe"
    $FfmpegPath = if (Test-Path -LiteralPath $portableFfmpeg) { $portableFfmpeg } else { "ffmpeg" }
}

$outputAudio = Join-Path $PSScriptRoot "test_audio.wav"
$outputWaveform = Join-Path $PSScriptRoot "test_audio.waveform.json"
$waveformGenerator = Join-Path $projectRoot "tools/audio/generate_waveform_json.ps1"

$filter = @"
[0:a]volume=0.018[bed];
[1:a]highpass=f=70,lowpass=f=1600,afade=t=in:st=0:d=0.18,afade=t=out:st=5.82:d=0.18,adelay=8000[environment];
[2:a]volume='if(lt(mod(t,0.75),0.30),0.22,0.055)':eval=frame,tremolo=f=3.2:d=0.28[repeat_low];
[3:a]volume=0.075,tremolo=f=2.1:d=0.22[repeat_high];
[repeat_low][repeat_high]amix=inputs=2:duration=shortest:normalize=0,afade=t=in:st=0:d=0.03,afade=t=out:st=5.94:d=0.06[repeat];
[repeat]asplit=2[repeat_a][repeat_b];
[repeat_a]adelay=22000[repeat_a_delayed];
[repeat_b]adelay=36000[repeat_b_delayed];
[bed][environment][repeat_a_delayed][repeat_b_delayed]amix=inputs=4:duration=longest:normalize=0,atrim=start=0:end=60,afade=t=in:st=0:d=0.03,afade=t=out:st=59.94:d=0.06,alimiter=limit=0.88[out]
"@ -replace "`r?`n", ""

& $FfmpegPath -hide_banner -loglevel warning -y `
    -f lavfi -i "sine=frequency=72:sample_rate=48000:duration=60" `
    -f lavfi -i "anoisesrc=color=pink:duration=6:amplitude=0.20:r=48000:seed=731" `
    -f lavfi -i "sine=frequency=392:sample_rate=48000:duration=6" `
    -f lavfi -i "sine=frequency=587.33:sample_rate=48000:duration=6" `
    -filter_complex $filter -map "[out]" -ac 1 -ar 48000 -c:a pcm_s16le $outputAudio
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputAudio)) {
    throw "Failed to generate the T-001B test WAV."
}

& $waveformGenerator `
    -InputAudio $outputAudio `
    -OutputJson $outputWaveform `
    -SampleCount $SampleCount `
    -FfmpegPath $FfmpegPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputWaveform)) {
    throw "Failed to generate the T-001B waveform JSON."
}

$ffprobePath = Join-Path (Split-Path -Parent $FfmpegPath) "ffprobe.exe"
if (-not (Test-Path -LiteralPath $ffprobePath)) {
    $ffprobePath = "ffprobe"
}
$duration = & $ffprobePath -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $outputAudio
if ($LASTEXITCODE -ne 0) {
    throw "FFprobe could not validate the generated test WAV."
}

Write-Output "Generated: $outputAudio"
Write-Output "Generated: $outputWaveform"
Write-Output "Duration: $duration seconds"
Write-Output "Waveform buckets: $SampleCount"
