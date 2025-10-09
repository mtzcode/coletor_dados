Param(
    [switch]$NoClean,
    [string]$OutputDir = "build\releases",
    [string]$AppName = "nymbus_coletor"
)

$ErrorActionPreference = 'Stop'

function Get-VersionInfo {
    param([string]$PubspecPath)
    $content = Get-Content -Raw -Path $PubspecPath
    $regex = [regex] 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)'
    $m = $regex.Match($content)
    if (-not $m.Success) { throw "Linha 'version:' não encontrada em $PubspecPath" }
    return [pscustomobject]@{
        Major = [int]$m.Groups[1].Value
        Minor = [int]$m.Groups[2].Value
        Patch = [int]$m.Groups[3].Value
        Build = [int]$m.Groups[4].Value
        Text = "$($m.Groups[1].Value).$($m.Groups[2].Value).$($m.Groups[3].Value)+$($m.Groups[4].Value)"
        Regex = $regex
        Raw = $content
    }
}

function Set-VersionInfo {
    param([string]$PubspecPath, [string]$NewVersionText, [regex]$Regex, [string]$Raw)
    $newContent = $Regex.Replace($Raw, "version: $NewVersionText")
    Set-Content -Path $PubspecPath -Value $newContent -Encoding UTF8
}

# Caminhos
$root = (Resolve-Path ".").Path
$pubspec = Join-Path $root 'pubspec.yaml'
$apkPath = Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk'

Write-Host "Projeto: $root"
Write-Host "Lendo versão do pubspec.yaml..."
$ver = Get-VersionInfo -PubspecPath $pubspec
Write-Host ("Versão atual: " + $ver.Text)

# Incrementa apenas o build number (versionCode)
$nextBuild = $ver.Build + 1
$newVersionText = "$($ver.Major).$($ver.Minor).$($ver.Patch)+$nextBuild"
Write-Host "Atualizando para: $newVersionText"
Set-VersionInfo -PubspecPath $pubspec -NewVersionText $newVersionText -Regex $ver.Regex -Raw $ver.Raw

# Dependências e build
if (-not $NoClean) {
    Write-Host "Executando flutter clean..."
    flutter clean
}
Write-Host "Executando flutter pub get..."
flutter pub get
Write-Host "Gerando APK de release..."
flutter build apk --release

if (-not (Test-Path $apkPath)) {
    throw "APK não encontrado em $apkPath"
}

# Copia para pasta de releases com nome versionado
$OutputDir = Join-Path $root $OutputDir
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$destName = "$AppName-$newVersionText.apk"
$destPath = Join-Path $OutputDir $destName
Copy-Item -Path $apkPath -Destination $destPath -Force

# Tamanho e resumo
$sizeMB = [Math]::Round((Get-Item $destPath).Length / 1MB, 2)
Write-Host ("APK criado: " + $destPath + " (" + $sizeMB + " MB)")

# Relatório de assinatura (opcional, se gradle estiver configurado)
try {
    Write-Host "Gerando relatório de assinatura (Gradle)..."
    & .\android\gradlew.bat -p android :app:signingReport | Out-Host
} catch {
    Write-Warning "Não foi possível gerar o signingReport: $($_.Exception.Message)"
}

Write-Host "Concluído. Para instalar como atualização, certifique-se de que o build number aumentou (versionCode)."