param(
  [string]$ResultsDir = "$PSScriptRoot\..\..\host-results",
  [string]$AppDataDir = "$env:APPDATA\Hiddify\hiddify",
  [string]$BuildDir = "$PSScriptRoot\..\..\build\windows\x64\runner\Debug",
  [switch]$IncludeRawSensitive
)

$ErrorActionPreference = "Continue"

function Resolve-OrNull([string]$Path) {
  try {
    return (Get-Item -LiteralPath $Path -ErrorAction Stop).FullName
  } catch {
    return $null
  }
}

function Write-Step([string]$Message) {
  $line = "$(Get-Date -Format o) $Message"
  Write-Host $line
  Add-Content -LiteralPath (Join-Path $script:RunDir "summary.log") -Value $line -Encoding UTF8
}

function Invoke-Capture([string]$Name, [scriptblock]$Block) {
  $path = Join-Path $script:RunDir $Name
  try {
    & $Block 2>&1 | Out-File -LiteralPath $path -Encoding UTF8 -Width 4096
  } catch {
    "ERROR: $($_.Exception.Message)" | Out-File -LiteralPath $path -Encoding UTF8
  }
}

function Redact-Text([string]$Text) {
  if ([string]::IsNullOrEmpty($Text)) {
    return $Text
  }

  $redacted = $Text
  $redacted = $redacted -replace '(?i)(https?://[^/\s]+/)[^/\s#?]+/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})([^\s]*)', '${1}<redacted-token>/<redacted-uuid>${3}'
  $redacted = $redacted -replace '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b', '<redacted-uuid>'
  $redacted = $redacted -replace '(?i)("?(password|passwd|uuid|id|token|access-token|access_token|license-key|license_key|private-key|private_key|short-id|short_id)"?\s*[:=]\s*")[^"]*(")', '$1<redacted>$3'
  $redacted = $redacted -replace '(?i)((password|passwd|uuid|token|access-token|access_token|license-key|license_key|private-key|private_key|short-id|short_id)=)[^\s&]+', '$1<redacted>'
  return $redacted
}

function Copy-RedactedFile([string]$Source, [string]$RelativeDestination) {
  if (-not (Test-Path -LiteralPath $Source)) {
    return
  }
  $dest = Join-Path $script:RunDir $RelativeDestination
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
  try {
    $content = Get-Content -Raw -LiteralPath $Source -ErrorAction Stop
    Redact-Text $content | Set-Content -LiteralPath $dest -Encoding UTF8
  } catch {
    "ERROR copying redacted file: $($_.Exception.Message)" | Set-Content -LiteralPath ($dest + ".error.txt") -Encoding UTF8
  }
}

function Copy-RedactedTail([string]$Source, [string]$RelativeDestination, [int]$Tail = 3000) {
  if (-not (Test-Path -LiteralPath $Source)) {
    return
  }
  $dest = Join-Path $script:RunDir $RelativeDestination
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
  try {
    $content = (Get-Content -LiteralPath $Source -Tail $Tail -ErrorAction Stop) -join [Environment]::NewLine
    Redact-Text $content | Set-Content -LiteralPath $dest -Encoding UTF8
  } catch {
    "ERROR copying redacted tail: $($_.Exception.Message)" | Set-Content -LiteralPath ($dest + ".error.txt") -Encoding UTF8
  }
}

function Invoke-CurlCheck([string]$Name, [string]$Url, [switch]$Proxy) {
  $line = "$(Get-Date -Format o) $Name proxy=$($Proxy.IsPresent) url=$Url "
  $args = @("--max-time", "12", "-L", "-k", "-sS", "-o", "NUL", "-w", "http=%{http_code} time=%{time_total} ip=%{remote_ip}")
  if ($Proxy) {
    $args += @("--proxy", "http://127.0.0.1:12334")
  }
  $args += $Url
  try {
    $output = & curl.exe @args 2>&1
    $exit = $LASTEXITCODE
    return "$line exit=$exit $output"
  } catch {
    return "$line ERROR=$($_.Exception.Message)"
  }
}

function Capture-HiddifyRuntimeSnapshot([string]$Prefix) {
  Invoke-Capture "$Prefix-processes-redacted.txt" {
    Get-CimInstance Win32_Process |
      Where-Object { $_.Name -match '(?i)hiddify|flutter|dart|sing|box' -or $_.CommandLine -match '(?i)hiddify|HiddifyCli|hiddify-core' } |
      Select-Object ProcessId, ParentProcessId, Name,
        @{Name = "WorkingSetMB"; Expression = { [math]::Round(($_.WorkingSetSize / 1MB), 2) } },
        @{Name = "PrivatePageMB"; Expression = { [math]::Round(($_.PrivatePageCount / 1MB), 2) } },
        HandleCount, ThreadCount, ExecutablePath,
        @{Name = "CommandLine"; Expression = { Redact-Text $_.CommandLine }} |
      Format-List
  }

  Invoke-Capture "$Prefix-ports.txt" {
    $ports = @(12334, 12335, 12336, 12337, 16756, 17078, 6756)
    Get-NetTCPConnection -LocalPort $ports -ErrorAction SilentlyContinue |
      Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess |
      Sort-Object LocalPort, State, RemoteAddress |
      Format-Table -AutoSize
  }

  Invoke-Capture "$Prefix-netstat-hiddify-ports.txt" {
    & netstat.exe -ano | Select-String -Pattern "12334|12335|12336|12337|16756|17078|6756"
  }

  Invoke-Capture "$Prefix-routes-ipv4.txt" {
    Get-NetRoute -AddressFamily IPv4 |
      Select-Object DestinationPrefix, NextHop, InterfaceAlias, InterfaceIndex, RouteMetric, ifMetric, PolicyStore |
      Sort-Object DestinationPrefix, RouteMetric |
      Format-Table -AutoSize
  }

  Invoke-Capture "$Prefix-route-print.txt" {
    & route.exe print
  }

  Invoke-Capture "$Prefix-system-proxy.txt" {
    Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" |
      Select-Object ProxyEnable, ProxyServer, AutoConfigURL, AutoDetect |
      Format-List
  }
}

New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
$results = (Get-Item -LiteralPath $ResultsDir).FullName
$script:RunDir = Join-Path $results ("runtime-diag-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Force -Path $script:RunDir | Out-Null

Start-Transcript -LiteralPath (Join-Path $script:RunDir "transcript.log") -Force | Out-Null
$script:TranscriptActive = $true

try {
  Write-Step "Runtime diagnostics collection started"
  Write-Step "RunDir=$script:RunDir"
  Write-Step "AppDataDir=$AppDataDir"
  Write-Step "BuildDir=$BuildDir"
  Write-Step "IncludeRawSensitive=$($IncludeRawSensitive.IsPresent)"

  Invoke-Capture "environment.txt" {
    [pscustomobject]@{
      Time = Get-Date -Format o
      User = [Environment]::UserName
      Computer = [Environment]::MachineName
      OS = (Get-CimInstance Win32_OperatingSystem).Caption
      OSVersion = (Get-CimInstance Win32_OperatingSystem).Version
      PowerShell = $PSVersionTable.PSVersion.ToString()
      CurrentDirectory = (Get-Location).Path
    } | Format-List
  }

  Invoke-Capture "build-hashes.txt" {
    $files = @(
      (Join-Path $BuildDir "Hiddify.exe"),
      (Join-Path $BuildDir "HiddifyCli.exe"),
      (Join-Path $BuildDir "hiddify-core.dll")
    ) | Where-Object { Test-Path -LiteralPath $_ }
    if ($files.Count -eq 0) {
      "No build files found."
    } else {
      Get-FileHash -Algorithm SHA256 -LiteralPath $files | Format-List
    }
  }

  Invoke-Capture "windows-events-hiddify.txt" {
    $since = (Get-Date).AddHours(-4)
    foreach ($logName in @("Application", "System")) {
      "===== $logName since $($since.ToString("o")) ====="
      Get-WinEvent -FilterHashtable @{ LogName = $logName; StartTime = $since } -ErrorAction SilentlyContinue |
        Where-Object {
          $_.ProviderName -match '(?i)application error|windows error reporting|application hang|hiddify|sing|box' -or
          $_.Message -match '(?i)Hiddify|HiddifyCli|hiddify-core|sing-box|libbox'
        } |
        Select-Object TimeCreated, Id, ProviderName, LevelDisplayName,
          @{Name = "Message"; Expression = { Redact-Text $_.Message }} |
        Format-List
    }
  }

  Capture-HiddifyRuntimeSnapshot "before-curl"

  Invoke-Capture "routes-ipv4.txt" {
    Get-NetRoute -AddressFamily IPv4 |
      Select-Object DestinationPrefix, NextHop, InterfaceAlias, InterfaceIndex, RouteMetric, ifMetric, PolicyStore |
      Sort-Object DestinationPrefix, RouteMetric |
      Format-Table -AutoSize
  }

  Invoke-Capture "routes-ipv6.txt" {
    Get-NetRoute -AddressFamily IPv6 |
      Select-Object DestinationPrefix, NextHop, InterfaceAlias, InterfaceIndex, RouteMetric, ifMetric, PolicyStore |
      Sort-Object DestinationPrefix, RouteMetric |
      Format-Table -AutoSize
  }

  Invoke-Capture "route-print.txt" {
    & route.exe print
  }

  Invoke-Capture "ipconfig-all.txt" {
    & ipconfig.exe /all
  }

  Invoke-Capture "net-adapters.txt" {
    Get-NetAdapter -IncludeHidden |
      Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed, ifIndex |
      Sort-Object Name |
      Format-Table -AutoSize
  }

  Invoke-Capture "ip-configuration.txt" {
    Get-NetIPConfiguration | Format-List
  }

  Invoke-Capture "dns-servers.txt" {
    Get-DnsClientServerAddress |
      Select-Object InterfaceAlias, AddressFamily, ServerAddresses |
      Sort-Object InterfaceAlias, AddressFamily |
      Format-Table -AutoSize
  }

  Invoke-Capture "system-proxy.txt" {
    Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" |
      Select-Object ProxyEnable, ProxyServer, AutoConfigURL, AutoDetect |
      Format-List
  }

  Invoke-Capture "firewall-hiddify.txt" {
    Get-NetFirewallRule -PolicyStore ActiveStore -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -match '(?i)hiddify|sing|box' } |
      Select-Object DisplayName, Enabled, Direction, Action, Profile |
      Format-Table -AutoSize
  }

  Invoke-Capture "dns-resolve.txt" {
    foreach ($name in @("google.com", "github.com", "raw.githubusercontent.com", "work.weixin.qq.com", "weixin.qq.com")) {
      "===== $name ====="
      Resolve-DnsName $name -ErrorAction Continue
    }
  }

  Invoke-Capture "tcp-checks.txt" {
    foreach ($target in @(
      @{ Host = "209.87.93.20"; Port = 443 },
      @{ Host = "209.87.93.20"; Port = 80 },
      @{ Host = "8.8.8.8"; Port = 53 },
      @{ Host = "223.5.5.5"; Port = 53 }
    )) {
      "===== $($target.Host):$($target.Port) ====="
      Test-NetConnection -ComputerName $target.Host -Port $target.Port -InformationLevel Detailed
    }
  }

  Invoke-Capture "curl-checks.txt" {
    Invoke-CurlCheck "direct-google" "https://www.google.com/"
    Invoke-CurlCheck "direct-github" "https://github.com/"
    Invoke-CurlCheck "direct-captive" "http://captive.apple.com/hotspot-detect.html"
    Invoke-CurlCheck "proxy-google" "https://www.google.com/" -Proxy
    Invoke-CurlCheck "proxy-github" "https://github.com/" -Proxy
    Invoke-CurlCheck "proxy-captive" "http://captive.apple.com/hotspot-detect.html" -Proxy
  }

  Capture-HiddifyRuntimeSnapshot "after-curl"

  $resolvedAppData = Resolve-OrNull $AppDataDir
  if ($resolvedAppData) {
    Invoke-Capture "appdata-file-list.txt" {
      Get-ChildItem -LiteralPath $resolvedAppData -Recurse -Force -ErrorAction SilentlyContinue |
        Select-Object FullName, Length, LastWriteTime |
        Sort-Object FullName |
        Format-Table -AutoSize
    }

    Copy-RedactedTail (Join-Path $resolvedAppData "app.log") "appdata\app.tail.redacted.log"
    Copy-RedactedTail (Join-Path $resolvedAppData "box.log") "appdata\box.tail.redacted.log"
    Copy-RedactedTail (Join-Path $resolvedAppData "data\box.log") "appdata\data\box.tail.redacted.log"
    Copy-RedactedFile (Join-Path $resolvedAppData "app.log") "appdata\app.redacted.log"
    Copy-RedactedFile (Join-Path $resolvedAppData "box.log") "appdata\box.redacted.log"
    Copy-RedactedFile (Join-Path $resolvedAppData "data\box.log") "appdata\data\box.redacted.log"
    Copy-RedactedFile (Join-Path $resolvedAppData "shared_preferences.json") "appdata\shared_preferences.redacted.json"
    Copy-RedactedFile (Join-Path $resolvedAppData "data\current-config.json") "appdata\data\current-config.redacted.json"
    Copy-RedactedTail (Join-Path $resolvedAppData "data\goroutine-start.log") "appdata\data\goroutine-start.tail.redacted.log" 12000
    Copy-RedactedTail (Join-Path $resolvedAppData "data\goroutine-start-hang.log") "appdata\data\goroutine-start-hang.tail.redacted.log" 12000

    foreach ($dirName in @("rules", "configs")) {
      $dir = Join-Path $resolvedAppData $dirName
      if (Test-Path -LiteralPath $dir) {
        Get-ChildItem -LiteralPath $dir -File -Recurse -ErrorAction SilentlyContinue |
          Where-Object { $_.Length -lt 5MB } |
          ForEach-Object {
            $relative = $_.FullName.Substring($resolvedAppData.Length).TrimStart("\")
            Copy-RedactedFile $_.FullName (Join-Path "appdata" ($relative + ".redacted.txt"))
          }
      }
    }

    if ($IncludeRawSensitive) {
      $rawDir = Join-Path $script:RunDir "raw-sensitive"
      New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
      foreach ($source in @(
        (Join-Path $resolvedAppData "app.log"),
        (Join-Path $resolvedAppData "box.log"),
        (Join-Path $resolvedAppData "data\box.log"),
        (Join-Path $resolvedAppData "shared_preferences.json"),
        (Join-Path $resolvedAppData "data\current-config.json")
      )) {
        if (Test-Path -LiteralPath $source) {
          Copy-Item -LiteralPath $source -Destination $rawDir -Force
        }
      }
      Write-Step "Raw sensitive files were copied because -IncludeRawSensitive was set"
    }
  } else {
    Write-Step "AppDataDir does not exist: $AppDataDir"
  }

  $zipPath = "$script:RunDir.zip"
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }
  Stop-Transcript | Out-Null
  $script:TranscriptActive = $false
  Compress-Archive -Path (Join-Path $script:RunDir "*") -DestinationPath $zipPath -Force
  if (Test-Path -LiteralPath $zipPath) {
    Write-Step "Zip created: $zipPath"
  } else {
    Write-Step "Zip was not created: $zipPath"
  }
  Write-Step "Runtime diagnostics collection finished"
} finally {
  if ($script:TranscriptActive) {
    Stop-Transcript | Out-Null
    $script:TranscriptActive = $false
  }
  Write-Host "RESULT_DIR=$script:RunDir"
  Write-Host "ZIP=$script:RunDir.zip"
}
