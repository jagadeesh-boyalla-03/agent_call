# VoicEra local development launcher.
# Starts supporting containers, then the API (8000), voice runtime (7860), and dashboard (3000).

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

function Import-EnvFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        return
    }

    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) {
            return
        }
        if ($line -match "^(?<name>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$") {
            $name = $Matches.name
            $value = $Matches.value.Trim()
            if ($value.Length -ge 2 -and (
                ($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))
            )) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

function Resolve-Python {
    $venvCandidates = @(
        (Join-Path $Root ".venv-runtime\\Scripts\\python.exe"),
        (Join-Path $Root ".venv\\Scripts\\python.exe")
    )

    foreach ($candidate in $venvCandidates) {
        if (Test-Path $candidate) {
            try {
                & $candidate --version *> $null
                if ($LASTEXITCODE -eq 0) {
                    return @{ FilePath = $candidate; Prefix = @() }
                }
            } catch {
                Write-Warning "Ignoring unusable Python environment at $candidate"
            }
        }
    }

    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        try {
            & $pyLauncher.Source -3.11 --version *> $null
            if ($LASTEXITCODE -eq 0) {
                return @{ FilePath = $pyLauncher.Source; Prefix = @("-3.11") }
            }
        } catch {
            Write-Warning "The Python launcher could not start Python 3.11"
        }
    }

    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCommand) {
        try {
            & $pythonCommand.Source --version *> $null
            if ($LASTEXITCODE -eq 0) {
                return @{ FilePath = $pythonCommand.Source; Prefix = @() }
            }
        } catch {
            Write-Warning "The python command is not usable"
        }
    }

    throw "Python 3.11 was not found. Create .venv-runtime with Python 3.11 and install apps/runtime/requirements.txt."
}

function Test-LocalPort {
    param([Parameter(Mandatory)][int]$Port)

    return Test-NetConnection -ComputerName "127.0.0.1" -Port $Port -InformationLevel Quiet
}

function Wait-ForHttpService {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url
    )

    foreach ($attempt in 1..30) {
        try {
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec 2 -UseBasicParsing
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                Write-Host "$Name is ready at $Url" -ForegroundColor Green
                return
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }

    throw "$Name did not become healthy at $Url. Check its terminal output before starting a browser test call."
}

function Start-PythonService {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Port,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string[]]$UvicornArguments
    )

    if (Test-LocalPort $Port) {
        Write-Host "$Name is already listening on port $Port" -ForegroundColor Yellow
        return
    }

    $arguments = @($script:PythonRuntime.Prefix) + @("-m", "uvicorn") + $UvicornArguments
    $process = Start-Process -FilePath $script:PythonRuntime.FilePath `
        -ArgumentList $arguments `
        -WorkingDirectory $WorkingDirectory `
        -PassThru
    Write-Host "Started $Name (PID $($process.Id))" -ForegroundColor Yellow
}

Write-Host "=== VoicEra Dev Startup ===" -ForegroundColor Cyan

# Runtime modules read environment variables directly, so load the shared root .env
# before launching child processes. This also makes provider keys available to Pipecat.
Import-EnvFile (Join-Path $Root ".env")
$env:PYTHONPATH = "$Root;$Root\\apps\\api" + $(if ($env:PYTHONPATH) { ";$($env:PYTHONPATH)" } else { "" })
$script:PythonRuntime = Resolve-Python

if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "[1/4] Starting infrastructure (FerretDB, Redis, MinIO)..." -ForegroundColor Yellow
    docker compose -f "$Root\\docker-compose.yaml" up -d postgres ferretdb redis minio minio-init
} else {
    Write-Host "[1/4] Docker not found. The API will use its local database fallback." -ForegroundColor Yellow
}

Write-Host "[2/4] Starting FastAPI backend..." -ForegroundColor Yellow
Start-PythonService -Name "API backend" -Port 8000 -WorkingDirectory (Join-Path $Root "apps\\api") `
    -UvicornArguments @("app.main:app", "--host", "127.0.0.1", "--port", "8000", "--reload")
Wait-ForHttpService -Name "API backend" -Url "http://127.0.0.1:8000/docs"

Write-Host "[3/4] Starting Voice Runtime..." -ForegroundColor Yellow
Start-PythonService -Name "Voice Runtime" -Port 7860 -WorkingDirectory $Root `
    -UvicornArguments @("apps.runtime.app:app", "--host", "127.0.0.1", "--port", "7860", "--reload")
Wait-ForHttpService -Name "Voice Runtime" -Url "http://127.0.0.1:7860/health"

Write-Host "[4/4] Starting dashboard..." -ForegroundColor Yellow
$frontendPath = Join-Path $Root "frontend"
if (-not (Test-Path $frontendPath)) {
    throw "Frontend directory not found at $frontendPath"
}
if (Test-LocalPort 3000) {
    Write-Host "Dashboard is already listening on port 3000" -ForegroundColor Yellow
} else {
    Start-Process -FilePath "npm" -ArgumentList @("run", "dev") -WorkingDirectory $frontendPath | Out-Null
}

Write-Host "All services are ready." -ForegroundColor Green
Write-Host "  Dashboard    : http://localhost:3000" -ForegroundColor Green
Write-Host "  API          : http://localhost:8000/docs" -ForegroundColor Green
Write-Host "  Voice runtime: http://localhost:7860/health" -ForegroundColor Green
