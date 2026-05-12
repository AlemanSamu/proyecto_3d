param(
    [string]$ApkName = "Captura 3D"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $projectRoot

try {
    flutter build apk --release

    $apkDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
    $sourceApk = Join-Path $apkDir "app-release.apk"
    if (-not (Test-Path -LiteralPath $sourceApk)) {
        throw "No se encontro el APK generado en: $sourceApk"
    }

    $targetApk = Join-Path $apkDir "$ApkName.apk"
    if (Test-Path -LiteralPath $targetApk) {
        Remove-Item -LiteralPath $targetApk -Force
    }
    Move-Item -LiteralPath $sourceApk -Destination $targetApk -Force

    $sourceSha = "$sourceApk.sha1"
    if (Test-Path -LiteralPath $sourceSha) {
        $targetSha = "$targetApk.sha1"
        if (Test-Path -LiteralPath $targetSha) {
            Remove-Item -LiteralPath $targetSha -Force
        }
        Move-Item -LiteralPath $sourceSha -Destination $targetSha -Force
    }

    Write-Host ""
    Write-Host "APK final:"
    Write-Host $targetApk
}
finally {
    Pop-Location
}
