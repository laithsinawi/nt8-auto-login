<#
.SYNOPSIS
    Guards NinjaTrader 8 workspaces against chart windows that lose all
    their tabs. Run it while NinjaTrader is closed, before starting it.

.DESCRIPTION
    NT8 sometimes saves a chart window with an empty tab list. On the next
    start the window comes back as a blank "Chart" tab. NT closes a chart
    window when its last tab closes, so a saved chart window with no tabs
    is always damage, never a real layout.

    For each workspace in Documents\NinjaTrader 8\workspaces:
    - Healthy: kept as a dated snapshot in NinjaTrader 8\WorkspaceGuard\<name>\
      (only when it changed since the last snapshot). The newest 30 are kept.
    - Damaged: each emptied chart window is replaced with the same window
      (matched by window id) from the newest healthy snapshot that has it,
      so the other windows keep today's changes. The damaged file is kept
      as broken-<time>.xml next to the snapshots.

    Everything it does is written to WorkspaceGuard\guard.log.

.PARAMETER Keep
    How many healthy snapshots to keep per workspace.

.PARAMETER NinjaTraderDir
    The NinjaTrader 8 user folder. Defaults to Documents\NinjaTrader 8.
#>

param(
    [int]$Keep = 30,
    [string]$NinjaTraderDir = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'NinjaTrader 8')
)

$ErrorActionPreference = 'Stop'

$ntDir = $NinjaTraderDir
$wsDir = Join-Path $ntDir 'workspaces'
$guardDir = Join-Path $ntDir 'WorkspaceGuard'
$logFile = Join-Path $guardDir 'guard.log'

function Write-GuardLog([string]$message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $message
    Write-Host $line
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}

function Read-Workspace([string]$path) {
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($path)
    return $doc
}

# Names of chart windows whose TabControl holds no Tab-* entries.
function Get-EmptyChartWindows([System.Xml.XmlDocument]$doc) {
    $windows = $doc.SelectSingleNode('/NinjaTrader/NTWindows')
    if (-not $windows) { return @() }
    $empty = @()
    foreach ($w in $windows.ChildNodes) {
        if ($w.NodeType -ne 'Element' -or -not $w.Name.StartsWith('Chart-')) { continue }
        $tabControl = $w.SelectSingleNode('TabControl')
        $tabs = @()
        if ($tabControl) { $tabs = @($tabControl.ChildNodes | Where-Object { $_.NodeType -eq 'Element' -and $_.Name.StartsWith('Tab-') }) }
        if ($tabs.Count -eq 0) { $empty += $w.Name }
    }
    return $empty
}

if (Get-Process -Name NinjaTrader -ErrorAction SilentlyContinue) {
    Write-Host 'NinjaTrader is running; workspace guard skipped (NT would overwrite any fix on exit).'
    return
}
if (-not (Test-Path -LiteralPath $wsDir)) { return }
New-Item -ItemType Directory -Force -Path $guardDir | Out-Null

$stamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$checked = 0

foreach ($file in Get-ChildItem -LiteralPath $wsDir -Filter '*.xml' -File) {
    if ($file.Name -eq '_Workspaces.xml') { continue }
    $name = $file.BaseName
    $checked++
    $snapDir = Join-Path $guardDir $name
    New-Item -ItemType Directory -Force -Path $snapDir | Out-Null
    $snapshots = @(Get-ChildItem -LiteralPath $snapDir -Filter 'good-*.xml' -File | Sort-Object Name -Descending)

    try {
        $doc = Read-Workspace $file.FullName
        $empty = @(Get-EmptyChartWindows $doc)
    } catch {
        Write-GuardLog "$name`: could not read ($($_.Exception.Message)); left as is."
        continue
    }

    if ($empty.Count -eq 0) {
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $latestHash = if ($snapshots.Count) { (Get-FileHash -LiteralPath $snapshots[0].FullName -Algorithm SHA256).Hash } else { '' }
        if ($hash -ne $latestHash) {
            Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $snapDir "good-$stamp.xml")
            Write-GuardLog "$name`: healthy, snapshot saved."
            $snapshots = @(Get-ChildItem -LiteralPath $snapDir -Filter 'good-*.xml' -File | Sort-Object Name -Descending)
            $snapshots | Select-Object -Skip $Keep | Remove-Item -Force
        }
        continue
    }

    Write-GuardLog "$name`: $($empty.Count) chart window(s) saved with no tabs: $($empty -join ', ')"
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $snapDir "broken-$stamp.xml")

    $fixed = 0
    foreach ($windowName in $empty) {
        $source = $null
        foreach ($snap in $snapshots) {
            try {
                $snapDoc = Read-Workspace $snap.FullName
                $candidate = $snapDoc.SelectSingleNode("/NinjaTrader/NTWindows/$windowName")
                if ($candidate -and ((Get-EmptyChartWindows $snapDoc) -notcontains $windowName)) { $source = $candidate; $sourceFile = $snap.Name; break }
            } catch { }
        }
        if (-not $source) {
            Write-GuardLog "$name`: no healthy snapshot has $windowName; it stays empty."
            continue
        }
        $target = $doc.SelectSingleNode("/NinjaTrader/NTWindows/$windowName")
        $target.ParentNode.ReplaceChild($doc.ImportNode($source, $true), $target) | Out-Null
        Write-GuardLog "$name`: restored $windowName from $sourceFile."
        $fixed++
    }

    if ($fixed -gt 0) {
        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Encoding = New-Object System.Text.UTF8Encoding($true)
        $writer = [System.Xml.XmlWriter]::Create($file.FullName, $settings)
        try { $doc.Save($writer) } finally { $writer.Dispose() }
        Write-GuardLog "$name`: saved with $fixed window(s) restored."
    }
}

Write-GuardLog "Run complete: checked $checked workspace(s)."
