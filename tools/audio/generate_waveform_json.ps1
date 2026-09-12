param(
    [Parameter(Mandatory = $true)]
    [string]$InputAudio,

    [Parameter(Mandatory = $true)]
    [string]$OutputJson,

    [int]$SampleCount = 256,

    [string]$FfmpegPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
if ([string]::IsNullOrWhiteSpace($FfmpegPath)) {
    $portableFfmpeg = Join-Path $projectRoot "tools/bin/ffmpeg/ffmpeg.exe"
    $FfmpegPath = if (Test-Path -LiteralPath $portableFfmpeg) { $portableFfmpeg } else { "ffmpeg" }
}

$inputPath = (Resolve-Path -LiteralPath $InputAudio).Path
$outputCandidate = if ([System.IO.Path]::IsPathRooted($OutputJson)) { $OutputJson } else { Join-Path (Get-Location) $OutputJson }
$outputPath = [System.IO.Path]::GetFullPath($outputCandidate)
$outputDirectory = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

$temporaryPcm = Join-Path ([System.IO.Path]::GetTempPath()) ("track-waveform-{0}.f32le" -f ([guid]::NewGuid().ToString("N")))
try {
    & $FfmpegPath -hide_banner -loglevel error -y -i $inputPath -ac 1 -ar 12000 -f f32le $temporaryPcm
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temporaryPcm)) {
        throw "FFmpeg could not decode $inputPath"
    }

    $bytes = [System.IO.File]::ReadAllBytes($temporaryPcm)
    $floatCount = [int]($bytes.Length / 4)
    if ($floatCount -le 0) {
        throw "Decoded audio contains no samples: $inputPath"
    }

    $bucketMinimums = New-Object System.Collections.Generic.List[double]
    $bucketMaximums = New-Object System.Collections.Generic.List[double]
    for ($bucket = 0; $bucket -lt $SampleCount; $bucket++) {
        $start = [int][math]::Floor($bucket * $floatCount / $SampleCount)
        $end = [int][math]::Ceiling(($bucket + 1) * $floatCount / $SampleCount)
        $minimum = 1.0
        $maximum = -1.0
        for ($index = $start; $index -lt [math]::Min($end, $floatCount); $index++) {
            $value = [BitConverter]::ToSingle($bytes, $index * 4)
            if ($value -lt $minimum) { $minimum = $value }
            if ($value -gt $maximum) { $maximum = $value }
        }
        $bucketMinimums.Add($minimum)
        $bucketMaximums.Add($maximum)
    }

    $normalizationMaximum = 0.0
    for ($bucket = 0; $bucket -lt $SampleCount; $bucket++) {
        $absoluteMinimum = [math]::Abs($bucketMinimums[$bucket])
        $absoluteMaximum = [math]::Abs($bucketMaximums[$bucket])
        $normalizationMaximum = [math]::Max(
            $normalizationMaximum,
            [math]::Max($absoluteMinimum, $absoluteMaximum)
        )
    }
    if ($normalizationMaximum -le 0.0) { $normalizationMaximum = 1.0 }

    $normalizedPeaks = New-Object System.Collections.Generic.List[object]
    $normalizedSamples = New-Object System.Collections.Generic.List[double]
    for ($bucket = 0; $bucket -lt $SampleCount; $bucket++) {
        $normalizedMinimum = [math]::Round($bucketMinimums[$bucket] / $normalizationMaximum, 6)
        $normalizedMaximum = [math]::Round($bucketMaximums[$bucket] / $normalizationMaximum, 6)
        $normalizedPeaks.Add([object]@($normalizedMinimum, $normalizedMaximum))
        $normalizedSamples.Add(
            [math]::Round([math]::Max([math]::Abs($normalizedMinimum), [math]::Abs($normalizedMaximum)), 6)
        )
    }

    $duration = $floatCount / 12000.0
    $resourcePath = "res://" + $inputPath.Substring($projectRoot.Length).TrimStart('\').Replace('\', '/')
    $document = [ordered]@{
        version = 1
        audio_path = $resourcePath
        duration = [math]::Round($duration, 6)
        sample_count = $SampleCount
        method = "peak_min_max_normalized"
        peaks = $normalizedPeaks
        samples = $normalizedSamples
    }
    $document | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $outputPath -Encoding utf8
}
finally {
    if (Test-Path -LiteralPath $temporaryPcm) {
        Remove-Item -LiteralPath $temporaryPcm -Force
    }
}
