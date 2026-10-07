<#
.SYNOPSIS
  Updates out of Date Chrome Browser
.DESCRIPTION
  This script checks for the installed version of Google Chrome and updates it if it is out of date.
.PARAMETER  logName
  Specifies the name of the log file to be created in the temporary directory. Default is "Update-GoogleChrome".
.OUTPUTS
  Log file containing the results of the script execution based on the specified log directory and name in variables $logDir and $logName.
.NOTES
  Version:        1.0
  Author:         Lewis Humphries
  Creation Date:  07/10/2026
  Purpose/Change:
    1.0 - Initial script to Install/update Google Chrome system-wide.
#>

#----------------------------------------------------------[Parameters]----------------------------------------------------------
  $logName = "Update-Browser_GoogleChrome"
#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Write-LogEntry {
  param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Value,
    [parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$FileName = "$logName.log",
    [switch]$Stamp,

    [ValidateSet("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")]
    [string]$ForegroundColor = "Yellow",

    [bool]$EnableDebug = $true
  )

  # Create log file and append the Date/Time
  $LogFile = Join-Path -Path $env:SystemRoot -ChildPath $("Temp\$FileName")
  $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), " ", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
  $Date = (Get-Date -Format "MM-dd-yyyy")

  If ($Stamp) {
    $LogText = "<$($Value)> <time=""$($Time)"" date=""$($Date)"">"
  }
  else {
    $LogText = "$($Value)"   
  }

  if ($EnableDebug) {
    Write-Host -ForegroundColor $ForegroundColor "$Value"
  }

  # Attempt to write the log entry
  Try {
    Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFile -ErrorAction Stop
  }
  Catch [System.Exception] {
    Write-Warning -Message "Unable to add log entry to $LogFile.log file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
  }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-LogEntry -Value "##################################"
Write-LogEntry -Stamp -Value "Starting Google Chrome Update Script"
Write-LogEntry -Value "##################################"
Write-LogEntry -Value "Script started at $(Get-Date -Format 'HH:mm:ss') on $(Get-Date -Format 'MM-dd-yyyy')"
Write-LogEntry -Value "Hostname: $($env:COMPUTERNAME)"

$scriptStartTime = Get-Date

Write-LogEntry -Value "Processor Architecture: $env:PROCESSOR_ARCHITECTURE"

#-----------------------------------------------------------
# Download Latest Installer
#-----------------------------------------------------------

$installerUrl = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"
$installerPath = "$env:TEMP\chrome_installer.exe"

Write-LogEntry -Value "Downloading latest Google Chrome installer..."

try {
  Invoke-WebRequest `
    -Uri $installerUrl `
    -OutFile $installerPath `
    -UseBasicParsing `
    -ErrorAction Stop

  Write-LogEntry -Value "Chrome installer downloaded successfully to $installerPath"
} Catch {
  Write-LogEntry -Value "Failed to download Chrome installer. Error: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

#-----------------------------------------------------------
# Install Chrome
#-----------------------------------------------------------

Write-LogEntry -Value "Starting Google Chrome installation..."
$process = Start-Process `
  -FilePath $installerPath `
  -ArgumentList "/silent /install --system-level" `
  -Wait `
  -PassThru

Write-LogEntry -Value "Chrome installer exit code: $($process.ExitCode)"
if ($process.ExitCode -ne 0) {
  Write-LogEntry -Value "Chrome installer returned a non-zero exit code." -ForegroundColor Red
  exit 1
}

#-----------------------------------------------------------
# Verify Installation
#-----------------------------------------------------------

$chromePaths = @(
  "C:\Program Files\Google\Chrome\Application\chrome.exe",
  "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
)

$timeout = 30
$chromePath = $null

while (-not $chromePath -and $timeout -gt 0) {
  $chromePath = $chromePaths |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

  if (-not $chromePath) {
    Start-Sleep -Seconds 1
    $timeout--
  }
}

if (-not $chromePath) {
  Write-LogEntry -Value "Google Chrome installation failed. Chrome executable not found after installation." -ForegroundColor Red
  exit 1
}

Write-LogEntry -Value "Google Chrome executable found at $chromePath"
try {
  $installedVersion = (Get-Item $chromePath).VersionInfo.ProductVersion
  Write-LogEntry -Value "Installed Chrome version: $installedVersion"
} catch {
  Write-LogEntry -Value "Unable to determine installed Chrome version." -ForegroundColor Red
}

#-----------------------------------------------------------
# Pending Restart Logic
#-----------------------------------------------------------

$pendingTag = "C:\ProgramData\ChromeUpdatePending.tag"

if (Get-Process chrome -ErrorAction SilentlyContinue) {
  Write-LogEntry -Value "Chrome process detected. Creating pending update marker."
  New-Item `
    -Path $pendingTag `
    -ItemType File `
    -Force | Out-Null
} else {
  Write-LogEntry -Value "Chrome is not running. No pending update marker required."
  if (Test-Path $pendingTag) {
      Remove-Item $pendingTag -Force -ErrorAction SilentlyContinue
  }
}

#-----------------------------------------------------------
# Cleanup
#-----------------------------------------------------------

if (Test-Path $installerPath) {
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    Write-LogEntry -Value "Installer file removed from $installerPath"
}

#-----------------------------------------------------------
# Completion
#-----------------------------------------------------------

Write-LogEntry -Value "###"

$scriptEndTime = Get-Date
$scriptDuration = $scriptEndTime - $scriptStartTime

Write-LogEntry -Value "Script completed at $($scriptEndTime.ToString('HH:mm:ss')) on $($scriptEndTime.ToString('MM-dd-yyyy'))"
Write-LogEntry -Value ("Execution Duration: {0} minutes, {1} seconds" -f $scriptDuration.Minutes, $scriptDuration.Seconds)

Write-LogEntry -Value "##################################"
Write-LogEntry -Stamp -Value "Script execution completed."
Write-LogEntry -Value "##################################"

exit 0