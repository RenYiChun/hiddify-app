param(
  [switch]$Remove,
  [switch]$Pause
)

$ErrorActionPreference = "Continue"

$Families = @("ipv4", "ipv6")
$Protocols = @("tcp", "udp")
$ReservedPorts = @(12334, 12335, 12336, 12337, 16756, 17078)

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PortRanges([int[]]$Ports) {
  $sorted = @($Ports | Sort-Object -Unique)
  $ranges = @()
  if ($sorted.Count -eq 0) {
    return $ranges
  }

  $start = [int]$sorted[0]
  $end = [int]$sorted[0]
  for ($i = 1; $i -lt $sorted.Count; $i++) {
    $port = [int]$sorted[$i]
    if ($port -eq ($end + 1)) {
      $end = $port
      continue
    }
    $ranges += [pscustomobject]@{ Start = $start; End = $end }
    $start = $port
    $end = $port
  }
  $ranges += [pscustomobject]@{ Start = $start; End = $end }
  return $ranges
}

function Get-ExcludedPortRanges([string]$Family, [string]$Protocol) {
  $output = & netsh.exe int $Family show excludedportrange protocol=$Protocol 2>&1
  $ranges = @()
  foreach ($line in $output) {
    if ($line -match '^\s*(\d+)\s+(\d+)\s*(\*)?') {
      $ranges += [pscustomobject]@{
        Start = [int]$matches[1]
        End = [int]$matches[2]
        Administered = -not [string]::IsNullOrWhiteSpace($matches[3])
      }
    }
  }
  return $ranges
}

function Get-UncoveredSegments([int]$Start, [int]$End, [object[]]$ExistingRanges) {
  $segments = @([pscustomobject]@{ Start = $Start; End = $End })
  foreach ($range in $ExistingRanges) {
    $next = @()
    foreach ($segment in $segments) {
      if ($range.End -lt $segment.Start -or $range.Start -gt $segment.End) {
        $next += $segment
        continue
      }
      if ($range.Start -gt $segment.Start) {
        $next += [pscustomobject]@{ Start = $segment.Start; End = ($range.Start - 1) }
      }
      if ($range.End -lt $segment.End) {
        $next += [pscustomobject]@{ Start = ($range.End + 1); End = $segment.End }
      }
    }
    $segments = $next
  }
  return $segments
}

function Invoke-Netsh([string[]]$Arguments) {
  Write-Host ("netsh " + ($Arguments -join " "))
  $output = & netsh.exe @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  if ($output) {
    $output | ForEach-Object { Write-Host $_ }
  }
  return $exitCode
}

function Add-PortRanges([string]$Family, [string]$Protocol, [int[]]$Ports) {
  $failed = $false
  $existing = @(Get-ExcludedPortRanges $Family $Protocol)
  foreach ($range in Get-PortRanges $Ports) {
    $segments = @(Get-UncoveredSegments $range.Start $range.End $existing)
    if ($segments.Count -eq 0) {
      Write-Host "$Family $Protocol $($range.Start)-$($range.End) already excluded."
      continue
    }

    foreach ($segment in $segments) {
      $count = $segment.End - $segment.Start + 1
      $code = Invoke-Netsh @(
        "int", $Family, "add", "excludedportrange",
        "protocol=$Protocol",
        "startport=$($segment.Start)",
        "numberofports=$count",
        "store=persistent"
      )
      if ($code -ne 0) {
        $failed = $true
      }
    }
  }
  return $failed
}

function Remove-PortRanges([string]$Family, [string]$Protocol, [int[]]$Ports) {
  $failed = $false
  foreach ($range in Get-PortRanges $Ports) {
    $count = $range.End - $range.Start + 1
    $code = Invoke-Netsh @(
      "int", $Family, "delete", "excludedportrange",
      "protocol=$Protocol",
      "startport=$($range.Start)",
      "numberofports=$count",
      "store=persistent"
    )
    if ($code -ne 0) {
      $failed = $true
    }
  }
  return $failed
}

try {
  if (-not (Test-IsAdmin)) {
    Write-Host "This script must be run as Administrator."
    Write-Host "Right-click reserve-hiddify-ports.bat and choose Run as administrator."
    exit 1
  }

  Write-Host "Hiddify fixed ports: $($ReservedPorts -join ', ')"
  Write-Host ""

  foreach ($family in $Families) {
    foreach ($protocol in $Protocols) {
      Write-Host "Current Windows $family $protocol dynamic port range:"
      & netsh.exe int $family show dynamicport $protocol
      Write-Host ""
    }
  }

  $failed = $false
  if ($Remove) {
    Write-Host "Removing Hiddify excluded port ranges..."
    foreach ($family in $Families) {
      foreach ($protocol in $Protocols) {
        $failed = (Remove-PortRanges $family $protocol $ReservedPorts) -or $failed
      }
    }
  } else {
    Write-Host "Adding Hiddify excluded port ranges..."
    foreach ($family in $Families) {
      foreach ($protocol in $Protocols) {
        $failed = (Add-PortRanges $family $protocol $ReservedPorts) -or $failed
      }
    }
  }

  Write-Host ""
  foreach ($family in $Families) {
    foreach ($protocol in $Protocols) {
      Write-Host "Final $family $protocol excluded ranges:"
      & netsh.exe int $family show excludedportrange protocol=$protocol
      Write-Host ""
    }
  }

  if ($failed) {
    Write-Host "Some ranges failed. If Hiddify is running, close it and run this script again as Administrator."
    exit 2
  }

  Write-Host "Done."
} finally {
  if ($Pause) {
    Read-Host "Press Enter to exit"
  }
}
