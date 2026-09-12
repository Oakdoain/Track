param(
    [string]$FfmpegPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
if ([string]::IsNullOrWhiteSpace($FfmpegPath)) {
    $portableFfmpeg = Join-Path $projectRoot "tools/bin/ffmpeg/ffmpeg.exe"
    $FfmpegPath = if (Test-Path -LiteralPath $portableFfmpeg) { $portableFfmpeg } else { "ffmpeg" }
}

$outputDirectory = Join-Path $projectRoot "data/cases/case_02/last_soundcheck/media"
$outputAudio = Join-Path $outputDirectory "soundcheck_2240.ogg"
$outputWaveform = Join-Path $outputDirectory "soundcheck_2240_waveform.json"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$filter = @"
[1:a]volume=0.055,tremolo=f=0.27:d=0.4[voice];
[2:a]volume='if(isnan(t),0,if(lt(mod(t-18.4,1.15),0.07),0.16,0.0))':eval=frame[wheel];
[0:a][voice][wheel]amix=inputs=3:duration=longest:normalize=0[base];
[base]asplit=2[main][copy];
[copy]atrim=start=8:end=14,asetpts=PTS-STARTPTS,adelay=43800|43800,volume=0.7[repeat];
[main][repeat]amix=inputs=2:duration=longest:normalize=0,
afade=t=in:st=0:d=0.03,
afade=t=out:st=71.94:d=0.06,
alimiter=limit=0.86[out]
"@ -replace "`r?`n", ""

& $FfmpegPath -hide_banner -loglevel warning -y `
    -f lavfi -i "anoisesrc=color=pink:duration=72:amplitude=0.08:r=48000" `
    -f lavfi -i "sine=frequency=196:sample_rate=48000:duration=72" `
    -f lavfi -i "sine=frequency=93:sample_rate=48000:duration=72" `
    -filter_complex $filter -map "[out]" -c:a libvorbis -q:a 5 $outputAudio
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputAudio)) {
    throw "Failed to generate the last soundcheck audio."
}

& (Join-Path $PSScriptRoot "generate_waveform_json.ps1") `
    -InputAudio $outputAudio `
    -OutputJson $outputWaveform `
    -SampleCount 256 `
    -FfmpegPath $FfmpegPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputWaveform)) {
    throw "Failed to generate the last soundcheck waveform data."
}

Write-Output "Generated: $outputAudio"
Write-Output "Generated: $outputWaveform"
