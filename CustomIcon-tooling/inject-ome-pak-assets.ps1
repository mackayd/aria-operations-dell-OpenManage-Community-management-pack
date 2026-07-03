<#
.SYNOPSIS
Injects custom Dell OME icons into an MP Builder-generated PAK file.

.DESCRIPTION
Patches only image assets in the outer PAK and nested adapters.zip archive.
Dashboard content, adapter code, and MP Builder design content are not modified.

The script expects Dell OME icon files in the icons directory by default:

  dell-ome-appliance.png
  dell-server.png
  dell-cpu-socket.png
  dell-memory-dimm.png
  dell-storage-controller.png
  dell-storage-drive.png
  dell-power-supply.png
  dell-server-subsystem-health.png

Icons must be PNG files at least 64x64. By default this script also requires
exactly 400x400 pixels to match the validated Dell OME release icon standard.

.PARAMETER Pak
Path to the MP Builder-generated Dell OME PAK.

.PARAMETER IconsDir
Directory containing Dell OME icon PNG files. Defaults to .\icons beside this script.

.PARAMETER Output
Output PAK path. Defaults to '<input>_icons.pak'.

.PARAMETER Force
Overwrite the output file if it already exists.

.PARAMETER AllowNon400
Allow icons that are at least 64x64 but not exactly 400x400. A warning is emitted.

.EXAMPLE
.\inject-ome-pak-assets.ps1 ".\Dell-OME-RestAPI-Community-Management-Pack-1.5.0.pak" -Force

.EXAMPLE
.\inject-ome-pak-assets.ps1 ".\Dell-OME-RestAPI-Community-Management-Pack-1.5.0.pak" -Output ".\Dell-OME-RestAPI-Community-Management-Pack-1.5.0-icon-injected.pak" -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Pak,

    [Parameter()]
    [string]$IconsDir = "",

    [Parameter()]
    [string]$Output = "",

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$AllowNon400
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if ([string]::IsNullOrWhiteSpace($IconsDir)) {
    $IconsDir = Join-Path $PSScriptRoot "icons"
}

$IconFiles = [ordered]@{
    adapter            = "dell-ome-appliance.png"
    default            = "dell-ome-appliance.png"
    world              = "dell-ome-appliance.png"
    relatives          = "dell-server.png"
    ome_appliance      = "dell-ome-appliance.png"
    server             = "dell-server.png"
    cpu_socket         = "dell-cpu-socket.png"
    memory_dimm        = "dell-memory-dimm.png"
    storage_controller = "dell-storage-controller.png"
    storage_drive      = "dell-storage-drive.png"
    power_supply       = "dell-power-supply.png"
    subsystem_health   = "dell-server-subsystem-health.png"
}

function Get-DefaultOutputPath {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$PakFile)

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($PakFile.Name)
    foreach ($suffix in @("-icon-injected", "_icon-injected", "_custom", "_icons")) {
        if ($stem.EndsWith($suffix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $stem = $stem.Substring(0, $stem.Length - $suffix.Length)
            break
        }
    }

    return Join-Path $PakFile.DirectoryName "$stem`_icons$($PakFile.Extension)"
}

function Get-PngDimensions {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 24) {
        throw "PNG file is too small: $Path"
    }

    $pngSignature = @(137, 80, 78, 71, 13, 10, 26, 10)
    for ($i = 0; $i -lt $pngSignature.Count; $i++) {
        if ($bytes[$i] -ne $pngSignature[$i]) {
            throw "File is not a PNG: $Path"
        }
    }

    $width = ([int]$bytes[16] -shl 24) -bor ([int]$bytes[17] -shl 16) -bor ([int]$bytes[18] -shl 8) -bor [int]$bytes[19]
    $height = ([int]$bytes[20] -shl 24) -bor ([int]$bytes[21] -shl 16) -bor ([int]$bytes[22] -shl 8) -bor [int]$bytes[23]

    return [pscustomobject]@{
        Width  = $width
        Height = $height
    }
}

function Read-ZipEntryBytes {
    param([Parameter(Mandatory = $true)][System.IO.Compression.ZipArchiveEntry]$Entry)

    $inputStream = $Entry.Open()
    try {
        $memory = [System.IO.MemoryStream]::new()
        try {
            $inputStream.CopyTo($memory)
            return ,$memory.ToArray()
        }
        finally {
            $memory.Dispose()
        }
    }
    finally {
        $inputStream.Dispose()
    }
}

function Write-ZipEntryBytes {
    param(
        [Parameter(Mandatory = $true)][System.IO.Compression.ZipArchive]$Target,
        [Parameter(Mandatory = $true)][System.IO.Compression.ZipArchiveEntry]$SourceEntry,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [byte[]]$Data
    )

    $newEntry = $Target.CreateEntry($SourceEntry.FullName, [System.IO.Compression.CompressionLevel]::Optimal)
    $newEntry.LastWriteTime = $SourceEntry.LastWriteTime

    if ($Data.Length -gt 0) {
        $outputStream = $newEntry.Open()
        try {
            $outputStream.Write($Data, 0, $Data.Length)
        }
        finally {
            $outputStream.Dispose()
        }
    }
}

function Import-Icons {
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][bool]$AllowNon400Icons
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        throw "Icons directory not found: $Directory"
    }

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($filename in ($IconFiles.Values | Sort-Object -Unique)) {
        $path = Join-Path $Directory $filename
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $missing.Add($filename)
        }
    }
    if ($missing.Count -gt 0) {
        throw "Missing icons in $Directory`: $($missing -join ', ')"
    }

    $icons = @{}
    $loadedFiles = New-Object System.Collections.Generic.List[object]
    foreach ($key in $IconFiles.Keys) {
        $path = Join-Path $Directory $IconFiles[$key]
        $dimensions = Get-PngDimensions -Path $path
        if ($dimensions.Width -lt 64 -or $dimensions.Height -lt 64) {
            throw "Icon is unexpectedly small: $path size=$($dimensions.Width)x$($dimensions.Height)"
        }
        if (($dimensions.Width -ne 400 -or $dimensions.Height -ne 400) -and -not $AllowNon400Icons) {
            throw "Icon must be exactly 400x400 pixels: $path size=$($dimensions.Width)x$($dimensions.Height). Use -AllowNon400 to permit this."
        }
        if ($dimensions.Width -ne 400 -or $dimensions.Height -ne 400) {
            Write-Warning "Icon is not 400x400: $path size=$($dimensions.Width)x$($dimensions.Height)"
        }
        $icons[$key] = [System.IO.File]::ReadAllBytes($path)
        $loadedFiles.Add([pscustomobject]@{
            Key    = $key
            File   = $IconFiles[$key]
            Width  = $dimensions.Width
            Height = $dimensions.Height
        })
    }

    $icons["__loadedFiles"] = $loadedFiles
    return $icons
}

function Get-OmeIconKey {
    param([Parameter(Mandatory = $true)][string]$FileName)

    $lower = $FileName.Replace("\", "/").ToLowerInvariant()
    if (-not $lower.EndsWith(".png")) { return $null }

    if ($lower.Contains("/conf/images/adapterkind/")) {
        return "adapter"
    }
    if ($lower.Contains("/conf/images/traversalspec/")) {
        return "relatives"
    }
    if ($lower.EndsWith("/default.png") -or $lower -eq "default.png" -or $lower.EndsWith("/pak-icon.png") -or $lower -eq "pak-icon.png") {
        return "default"
    }
    if (-not $lower.Contains("/conf/images/resourcekind/")) {
        return $null
    }

    if ($lower.EndsWith("_dell_cpu_socket.png")) { return "cpu_socket" }
    if ($lower.EndsWith("_dell_memory_dimm.png")) { return "memory_dimm" }
    if ($lower.EndsWith("_dell_storage_controller.png")) { return "storage_controller" }
    if ($lower.EndsWith("_dell_storage_drive.png")) { return "storage_drive" }
    if ($lower.EndsWith("_dell_power_supply.png")) { return "power_supply" }
    if ($lower.EndsWith("_dell_server_subsystem_health.png")) { return "subsystem_health" }
    if ($lower.EndsWith("_dell_ome_appliance.png")) { return "ome_appliance" }
    if ($lower.EndsWith("_dell_server.png")) { return "server" }
    if ($lower.EndsWith("_relatives.png")) { return "relatives" }
    if ($lower.EndsWith("_world.png")) { return "world" }

    if ($lower.EndsWith("mpb_dell_ome_restapi_community_management_pack.png")) {
        return "adapter"
    }

    return $null
}

function Update-InnerAdapterImages {
    param(
        [Parameter(Mandatory = $true)][byte[]]$InnerZipBytes,
        [Parameter(Mandatory = $true)][hashtable]$Icons
    )

    $replacements = New-Object System.Collections.Generic.List[object]
    $inputMemory = [System.IO.MemoryStream]::new($InnerZipBytes)
    $outputMemory = [System.IO.MemoryStream]::new()

    try {
        $source = [System.IO.Compression.ZipArchive]::new($inputMemory, [System.IO.Compression.ZipArchiveMode]::Read, $true)
        $target = [System.IO.Compression.ZipArchive]::new($outputMemory, [System.IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($entry in $source.Entries) {
                $data = Read-ZipEntryBytes -Entry $entry
                $replacementKey = Get-OmeIconKey -FileName $entry.FullName

                if ($replacementKey) {
                    $data = $Icons[$replacementKey]
                    $replacements.Add([pscustomobject]@{
                        Scope = "adapters.zip"
                        Entry = $entry.FullName
                        Icon  = $IconFiles[$replacementKey]
                    })
                }

                Write-ZipEntryBytes -Target $target -SourceEntry $entry -Data $data
            }
        }
        finally {
            $target.Dispose()
            $source.Dispose()
        }

        return [pscustomobject]@{
            Bytes        = $outputMemory.ToArray()
            Replacements = $replacements
        }
    }
    finally {
        $outputMemory.Dispose()
        $inputMemory.Dispose()
    }
}

function Test-PakContainsOmeAdapter {
    param([Parameter(Mandatory = $true)][System.IO.Compression.ZipArchive]$Pak)

    $manifestEntry = $Pak.Entries | Where-Object { $_.FullName -ieq "manifest.txt" } | Select-Object -First 1
    if (-not $manifestEntry) {
        return $false
    }

    $bytes = Read-ZipEntryBytes -Entry $manifestEntry
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    return $text -match "Dell OME RestAPI Community Management Pack" -or $text -match "mpb_dell_ome_restapi_community_management_pack"
}

function Invoke-PakPatch {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$PakFile,
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$OutputFile,
        [Parameter(Mandatory = $true)][string]$IconDirectory,
        [Parameter(Mandatory = $true)][bool]$AllowNon400Icons
    )

    $icons = Import-Icons -Directory $IconDirectory -AllowNon400Icons $AllowNon400Icons
    $replacements = New-Object System.Collections.Generic.List[object]

    $sourceStream = [System.IO.File]::OpenRead($PakFile.FullName)
    try {
        $pak = [System.IO.Compression.ZipArchive]::new($sourceStream, [System.IO.Compression.ZipArchiveMode]::Read, $true)
        try {
            if (-not (Test-PakContainsOmeAdapter -Pak $pak)) {
                throw "This does not look like a Dell OME RestAPI Community Management Pack PAK: $($PakFile.FullName)"
            }

            $adapterEntry = $pak.Entries | Where-Object { $_.FullName.EndsWith("adapters.zip", [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
            if (-not $adapterEntry) {
                throw "No adapters.zip found in $($PakFile.FullName)"
            }

            $patchedAdapter = Update-InnerAdapterImages -InnerZipBytes (Read-ZipEntryBytes -Entry $adapterEntry) -Icons $icons
            foreach ($replacement in $patchedAdapter.Replacements) {
                $replacements.Add($replacement)
            }

            $outputStream = [System.IO.File]::Open($OutputFile.FullName, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite)
            try {
                $outPak = [System.IO.Compression.ZipArchive]::new($outputStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
                try {
                    foreach ($entry in $pak.Entries) {
                        $data = Read-ZipEntryBytes -Entry $entry
                        $replacementKey = Get-OmeIconKey -FileName $entry.FullName
                        if ($entry.FullName -eq $adapterEntry.FullName) {
                            $data = $patchedAdapter.Bytes
                            $replacements.Add([pscustomobject]@{
                                Scope = "pak"
                                Entry = $entry.FullName
                                Icon  = "nested image assets"
                            })
                        }
                        elseif ($replacementKey) {
                            $data = $icons[$replacementKey]
                            $replacements.Add([pscustomobject]@{
                                Scope = "pak"
                                Entry = $entry.FullName
                                Icon  = $IconFiles[$replacementKey]
                            })
                        }

                        Write-ZipEntryBytes -Target $outPak -SourceEntry $entry -Data $data
                    }
                }
                finally {
                    $outPak.Dispose()
                }
            }
            finally {
                $outputStream.Dispose()
            }
        }
        finally {
            $pak.Dispose()
        }
    }
    finally {
        $sourceStream.Dispose()
    }

    return [pscustomobject]@{
        LoadedIcons  = $icons["__loadedFiles"]
        Replacements = $replacements
    }
}

function Test-PatchedPak {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$PakFile
    )

    $pngChecks = New-Object System.Collections.Generic.List[object]
    $pak = [System.IO.Compression.ZipFile]::OpenRead($PakFile.FullName)
    try {
        foreach ($entry in $pak.Entries) {
            if ($entry.FullName.EndsWith(".png", [System.StringComparison]::OrdinalIgnoreCase)) {
                $tmp = [System.IO.Path]::GetTempFileName()
                try {
                    [System.IO.File]::WriteAllBytes($tmp, (Read-ZipEntryBytes -Entry $entry))
                    $dimensions = Get-PngDimensions -Path $tmp
                    $pngChecks.Add([pscustomobject]@{
                        Scope  = "pak"
                        Entry  = $entry.FullName
                        Width  = $dimensions.Width
                        Height = $dimensions.Height
                    })
                }
                finally {
                    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                }
            }
            elseif ($entry.FullName.EndsWith("adapters.zip", [System.StringComparison]::OrdinalIgnoreCase)) {
                $adapterBytes = Read-ZipEntryBytes -Entry $entry
                $memory = [System.IO.MemoryStream]::new($adapterBytes)
                try {
                    $inner = [System.IO.Compression.ZipArchive]::new($memory, [System.IO.Compression.ZipArchiveMode]::Read, $true)
                    try {
                        foreach ($innerEntry in $inner.Entries) {
                            if ($innerEntry.FullName.EndsWith(".png", [System.StringComparison]::OrdinalIgnoreCase)) {
                                $tmp = [System.IO.Path]::GetTempFileName()
                                try {
                                    [System.IO.File]::WriteAllBytes($tmp, (Read-ZipEntryBytes -Entry $innerEntry))
                                    $dimensions = Get-PngDimensions -Path $tmp
                                    $pngChecks.Add([pscustomobject]@{
                                        Scope  = "adapters.zip"
                                        Entry  = $innerEntry.FullName
                                        Width  = $dimensions.Width
                                        Height = $dimensions.Height
                                    })
                                }
                                finally {
                                    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                                }
                            }
                        }
                    }
                    finally {
                        $inner.Dispose()
                    }
                }
                finally {
                    $memory.Dispose()
                }
            }
        }
    }
    finally {
        $pak.Dispose()
    }

    $belowMinimum = @($pngChecks | Where-Object { $_.Width -lt 64 -or $_.Height -lt 64 })
    if ($belowMinimum.Count -gt 0) {
        throw "Patched PAK contains icons below 64x64: $($belowMinimum.Entry -join ', ')"
    }

    return $pngChecks
}

$pakItem = Get-Item -LiteralPath $Pak
if (-not $pakItem.PSIsContainer) {
    $pakFile = [System.IO.FileInfo]$pakItem.FullName
}
else {
    throw "PAK path is a directory: $Pak"
}

$outputPath = if ([string]::IsNullOrWhiteSpace($Output)) {
    Get-DefaultOutputPath -PakFile $pakFile
}
else {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
}

$outputFile = [System.IO.FileInfo]$outputPath
if ($pakFile.FullName -eq $outputFile.FullName) {
    throw "Output path must be different from input path: $($pakFile.FullName)"
}

if (Test-Path -LiteralPath $outputFile.FullName) {
    if ($Force) {
        Remove-Item -LiteralPath $outputFile.FullName -Force
    }
    else {
        throw "Output already exists: $($outputFile.FullName). Use -Force to overwrite."
    }
}

$outputDirectory = Split-Path -Parent $outputFile.FullName
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

$iconDirectoryPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($IconsDir)
$result = Invoke-PakPatch -PakFile $pakFile -OutputFile $outputFile -IconDirectory $iconDirectoryPath -AllowNon400Icons ([bool]$AllowNon400)
$pngChecks = Test-PatchedPak -PakFile $outputFile

Write-Output "Wrote $($outputFile.FullName)"
Write-Output "Loaded icons from $iconDirectoryPath"
Write-Output "Dashboard content is not modified by this tool"
Write-Output "MP Builder design metadata is not modified by this tool"
Write-Output "Validated $($pngChecks.Count) PNG entries in the rebuilt PAK"
Write-Output "Replaced $($result.Replacements.Count) image entries"
foreach ($replacement in $result.Replacements) {
    Write-Output ("  {0} :: {1} <- {2}" -f $replacement.Scope, $replacement.Entry, $replacement.Icon)
}
