param([switch]$RefreshTypes)

$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & stylua --check src scripts/StudioSmoke.luau
    if ($LASTEXITCODE -ne 0) { throw 'StyLua check failed. Run stylua src scripts/StudioSmoke.luau.' }

    & selene src
    if ($LASTEXITCODE -ne 0) { throw 'Selene check failed.' }

    & rojo sourcemap default.project.json --include-non-scripts --output sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Rojo sourcemap generation failed.' }

    $taskTypesPath = Join-Path (Get-Location) '.tools/globalTypes.None.d.luau'
    if ($RefreshTypes -or -not (Test-Path -LiteralPath $taskTypesPath)) {
        New-Item -ItemType Directory -Path .tools -Force | Out-Null
        Invoke-WebRequest -Uri 'https://luau-lsp.pages.dev/type-definitions/globalTypes.None.d.luau' -OutFile $taskTypesPath
    }

    & luau-lsp analyze --platform=roblox --definitions=$taskTypesPath --sourcemap=sourcemap.json src
    if ($LASTEXITCODE -ne 0) { throw 'Luau typecheck failed.' }
}
finally {
    Pop-Location
}
