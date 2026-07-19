param(
    [string]$SourceDirectory = "assets/audio/source",
    [string]$OutputDirectory = "assets/audio/ui",
    [string]$FfmpegPath = ""
)

$ErrorActionPreference = "Stop"

$projectFfmpeg = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\bin\ffmpeg\ffmpeg.exe"))
if ([string]::IsNullOrWhiteSpace($FfmpegPath)) {
    if (Test-Path -LiteralPath $projectFfmpeg) {
        $FfmpegPath = $projectFfmpeg
    } else {
        $globalFfmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if ($null -ne $globalFfmpeg) {
            $FfmpegPath = $globalFfmpeg.Source
        }
    }
}
if ([string]::IsNullOrWhiteSpace($FfmpegPath) -or -not (Test-Path -LiteralPath $FfmpegPath)) {
    throw "ffmpeg was not found. Expected tools/bin/ffmpeg/ffmpeg.exe or a global ffmpeg command."
}

function Find-SourceFile([string]$Pattern) {
    $match = Get-ChildItem -LiteralPath $SourceDirectory -Filter $Pattern -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $match) {
        Write-Warning "Missing source audio: $SourceDirectory/$Pattern"
        return $null
    }
    return $match.FullName
}

function Invoke-Ffmpeg([string[]]$Arguments, [string]$OutputPath) {
    & $FfmpegPath -hide_banner -loglevel warning -y @Arguments
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
        throw "Audio preparation failed: $OutputPath"
    }
    Write-Host "Prepared $OutputPath"
}

$incomingSource = Find-SourceFile "pixabay_cellphone_ringing_6475.*"
$outgoingSource = Find-SourceFile "pixabay_phone_ringing_382734.*"
$typingSource = Find-SourceFile "pixabay_keyboard_typing_5997.*"

$phoneOutput = Join-Path $OutputDirectory "phone"
$textOutput = Join-Path $OutputDirectory "text"
New-Item -ItemType Directory -Force -Path $phoneOutput, $textOutput | Out-Null

if ($null -ne $incomingSource) {
    $output = Join-Path $phoneOutput "incoming_ring_loop.ogg"
    Invoke-Ffmpeg @(
        "-i", $incomingSource,
        "-af", "atrim=start=0:end=2,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.04,afade=t=out:st=1.96:d=0.04",
        "-c:a", "libvorbis", "-q:a", "5", $output
    ) $output
}

if ($null -ne $outgoingSource) {
    $output = Join-Path $phoneOutput "outgoing_ringback.ogg"
    Invoke-Ffmpeg @(
        "-i", $outgoingSource,
        "-af", "afade=t=in:st=0:d=0.04",
        "-c:a", "libvorbis", "-q:a", "5", $output
    ) $output
}

if ($null -ne $typingSource) {
    $output = Join-Path $textOutput "node_typing_loop.ogg"
    Invoke-Ffmpeg @(
        "-ss", "0.5", "-t", "3.0", "-i", $typingSource,
        "-af", "afade=t=in:st=0:d=0.04,afade=t=out:st=2.96:d=0.04",
        "-c:a", "libvorbis", "-q:a", "4", $output
    ) $output
}

Write-Host "UI audio preparation finished. Missing sources were skipped; no placeholder audio was created."
