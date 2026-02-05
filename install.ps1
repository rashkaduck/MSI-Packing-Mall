# install.ps1 - MSI-installationsmall
[CmdletBinding()]
param()

# =========================
# Konfiguration
# =========================
$ScriptDir = $PSScriptRoot
$SoftwareName = (Get-Item $ScriptDir).Name
$LogBasePath = "C:\InstallLogs"
$SoftwareLogPath = Join-Path $LogBasePath $SoftwareName

# =========================
# Skapa loggmappar
# =========================
if (-not (Test-Path $SoftwareLogPath)) {
    New-Item -Path $SoftwareLogPath -ItemType Directory -Force | Out-Null
}

$MainLogFile = Join-Path $SoftwareLogPath "install.log"
$SuccessFile = Join-Path $SoftwareLogPath "success.log"

# =========================
# Loggningsfunktion
# =========================
function Write-Log {
    param([Parameter(Mandatory)][string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp`t$Message" | Out-File -FilePath $MainLogFile -Append -Encoding UTF8
}

# =========================
# Starta installation
# =========================
Write-Log "=== Startar installation av $SoftwareName ==="
Write-Log "Skriptkatalog: $ScriptDir"

# =========================
# Hitta MSI-filer
# =========================
$MsiFiles = Get-ChildItem -Path $ScriptDir -Filter *.msi -File

if (-not $MsiFiles) {
    Write-Log "FEL: Inga MSI-filer hittades i $ScriptDir"
    exit 1
}

Write-Log "Hittade $($MsiFiles.Count) MSI-filer"
$MsiFiles | ForEach-Object { Write-Log "  - $($_.Name)" }

# =========================
# Installera varje MSI
# =========================
$AllSuccess = $true
$InstalledCount = 0

foreach ($Msi in $MsiFiles) {
    $MsiLog = Join-Path $SoftwareLogPath "msi_$($Msi.BaseName).log"
    
    Write-Log "--- Installerar: $($Msi.Name) ---"
    Write-Log "Loggfil: $MsiLog"
    
    $installArgs = @(
        "/i", "`"$($Msi.FullName)`"",
        "/qn",                     # Tyst installation
        "/norestart",              # Starta inte om automatiskt
        "/l*v", "`"$MsiLog`""      # Verbös loggning
    )
    
    Write-Log "Kör: msiexec.exe $($installArgs -join ' ')"
    
    try {
        $process = Start-Process -FilePath "msiexec.exe" `
                                 -ArgumentList $installArgs `
                                 -NoNewWindow `
                                 -Wait `
                                 -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Log "OK: $($Msi.Name) installerad"
            $InstalledCount++
        } elseif ($process.ExitCode -eq 3010) {
            Write-Log "VARNING: $($Msi.Name) kräver omstart (ExitCode 3010)"
            $InstalledCount++
        } else {
            Write-Log "FEL: $($Msi.Name) misslyckades med ExitCode $($process.ExitCode)"
            $AllSuccess = $false
        }
    }
    catch {
        Write-Log "UNDANTAG: $($Msi.Name) - $($_.Exception.Message)"
        $AllSuccess = $false
    }
}

# =========================
# Sammanställning
# =========================
Write-Log "=== Installation slutförd ==="
Write-Log "Installerade: $InstalledCount av $($MsiFiles.Count) MSI-filer"

if ($AllSuccess) {
    # Skapa success-fil med detaljer
    $successContent = @"
Installation lyckades: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Program: $SoftwareName
Antal MSI-filer: $($MsiFiles.Count)
Installerade: $InstalledCount
Sökväg: $ScriptDir
"@
    
    $successContent | Out-File -FilePath $SuccessFile -Encoding UTF8 -Force
    Write-Log "Successfil skapad: $SuccessFile"
    exit 0
}
else {
    Write-Log "VARNING: Några installationer misslyckades"
    exit 1
}