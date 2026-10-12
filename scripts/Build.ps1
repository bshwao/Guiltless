$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    New-Item -ItemType Directory -Path build -Force | Out-Null
    & rojo build default.project.json --output build/Guiltless.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Rojo build failed.' }
    & rojo sourcemap default.project.json --include-non-scripts --output sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Rojo sourcemap generation failed.' }
}
finally {
    Pop-Location
}
