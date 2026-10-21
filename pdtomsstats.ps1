# Authors: Subrata Paul and Kevin Cormier
$ErrorActionPreference = "Stop"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker was not found. Install Docker Desktop first."
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker is installed but the Docker engine is not running."
}

docker image inspect pdtomsstats:0.2.3 *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Downloading the PDtoMSstats environment for the first run..."
    docker pull ghcr.io/openomics/pdtomsstats:0.2.3
    if ($LASTEXITCODE -eq 0) {
        docker tag ghcr.io/openomics/pdtomsstats:0.2.3 pdtomsstats:0.2.3
    }
    else {
        Write-Host "The published image could not be downloaded; building it locally..."
        docker compose build
        if ($LASTEXITCODE -ne 0) {
            throw "The PDtoMSstats container could not be prepared."
        }
    }
}

docker compose run --rm pdtomsstats `
    Rscript scripts/pdtomsstats.R @args
exit $LASTEXITCODE
