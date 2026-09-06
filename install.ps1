# CompleteDiscordQuest — instalador Windows
# irm https://raw.githubusercontent.com/luanwolf/completeDiscordQuest/main/install.ps1 | iex
#
# ponytail: Node/Git portateis so x64. ARM usa emulacao. Vesktop nao tem inject —
# depois do build, em Configuracoes do Vesktop > Vencord Location, aponte para <Vencord>\dist.
# Trocar a pasta: $env:VENCORD_DIR='D:\Vencord'

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$VencordDir = if ($env:VENCORD_DIR) { $env:VENCORD_DIR } else { Join-Path $env:USERPROFILE 'Vencord' }
$PluginRepo = 'https://github.com/luanwolf/completeDiscordQuest.git'
$PluginName = 'completeDiscordQuest'
$DepsDir = Join-Path $env:LOCALAPPDATA 'completeDiscordQuest\deps'
$MinNodeMajor = 22
$Ua = @{ 'User-Agent' = 'completeDiscordQuest-installer' }

function Write-Step([string]$Msg) { Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Die([string]$Msg) { Write-Host "`nERRO: $Msg" -ForegroundColor Red; exit 1 }
function Has-Cmd([string]$Name) { $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

function Refresh-Path {
    $env:Path = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
        [Environment]::GetEnvironmentVariable('Path', 'User')
    ) -join ';'
}

function Add-UserPath([string]$Dir) {
    if (-not (Test-Path $Dir)) { return }
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $user) { $user = '' }
    $parts = $user -split ';' | Where-Object { $_ }
    if ($parts -notcontains $Dir) {
        [Environment]::SetEnvironmentVariable('Path', ($Dir + ';' + $user).TrimEnd(';'), 'User')
    }
    Refresh-Path
}

function Invoke-Exe {
    param(
        [Parameter(Mandatory)][string]$File,
        [string[]]$CmdArgs = @()
    )
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $File @CmdArgs
        if ($LASTEXITCODE) { Die "$File $($CmdArgs -join ' ') falhou (codigo $LASTEXITCODE)" }
    } finally {
        $ErrorActionPreference = $old
    }
}

function Get-NodeMajor {
    if (-not (Has-Cmd node)) { return 0 }
    $raw = & node -v 2>$null
    if ($raw -match 'v(\d+)') { return [int]$Matches[1] }
    return 0
}

function Install-Winget([string]$Id) {
    if (-not (Has-Cmd winget)) { return $false }
    Write-Host "    winget $Id"
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & winget install -e --id $Id --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
        Refresh-Path
        $pfNode = 'C:\Program Files\nodejs'
        if ((Test-Path (Join-Path $pfNode 'node.exe')) -and ($env:Path -notlike "*$pfNode*")) {
            $env:Path = "$pfNode;$env:Path"
        }
        $gitCmd = 'C:\Program Files\Git\cmd'
        if ((Test-Path (Join-Path $gitCmd 'git.exe')) -and ($env:Path -notlike "*$gitCmd*")) {
            $env:Path = "$gitCmd;$env:Path"
        }
        return $true
    } catch {
        return $false
    } finally {
        $ErrorActionPreference = $old
    }
}

function Install-PortableNode {
    Write-Host '    baixando Node portatil (nodejs.org)'
    $idx = Invoke-RestMethod 'https://nodejs.org/dist/index.json'
    $rel = $idx | Where-Object { $_.lts } | Select-Object -First 1
    if (-not $rel) { Die 'Nao achei um Node LTS em nodejs.org' }
    $ver = $rel.version
    $zipName = "node-$ver-win-x64.zip"
    $zip = Join-Path $env:TEMP $zipName
    Invoke-WebRequest "https://nodejs.org/dist/$ver/$zipName" -OutFile $zip -UseBasicParsing
    $dest = Join-Path $DepsDir 'node'
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $DepsDir | Out-Null
    $extracted = Join-Path $DepsDir "node-$ver-win-x64"
    if (Test-Path $extracted) { Remove-Item $extracted -Recurse -Force }
    Expand-Archive $zip -DestinationPath $DepsDir -Force
    Rename-Item $extracted 'node'
    Remove-Item $zip -Force
    Add-UserPath $dest
}

function Install-PortableGit {
    Write-Host '    baixando MinGit (git-for-windows)'
    $rel = Invoke-RestMethod 'https://api.github.com/repos/git-for-windows/git/releases/latest' -Headers $Ua
    $asset = $rel.assets | Where-Object { $_.name -match '^MinGit-.*-64-bit\.zip$' -and $_.name -notmatch 'busybox' } | Select-Object -First 1
    if (-not $asset) { Die 'Nao achei MinGit na release do git-for-windows' }
    $zip = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing -Headers $Ua
    $dest = Join-Path $DepsDir 'git'
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Expand-Archive $zip -DestinationPath $dest -Force
    Remove-Item $zip -Force
    Add-UserPath (Join-Path $dest 'cmd')
}

function Ensure-Git {
    if (Has-Cmd git) { return }
    Write-Step 'Git nao encontrado — instalando'
    [void](Install-Winget 'Git.Git')
    if (Has-Cmd git) { return }
    Install-PortableGit
    if (-not (Has-Cmd git)) { Die 'Nao consegui instalar o Git. Instale de https://git-scm.com/download/win e rode de novo.' }
}

function Ensure-Node {
    if ((Get-NodeMajor) -ge $MinNodeMajor) { return }
    Write-Step "Node $($MinNodeMajor)+ nao encontrado — instalando"
    [void](Install-Winget 'OpenJS.NodeJS.LTS')
    if ((Get-NodeMajor) -ge $MinNodeMajor) { return }
    Install-PortableNode
    if ((Get-NodeMajor) -lt $MinNodeMajor) {
        Die "Precisa de Node $MinNodeMajor+. Instale em https://nodejs.org/ e rode de novo."
    }
}

function Ensure-Pnpm {
    if (Has-Cmd pnpm) { return }
    Write-Step 'pnpm nao encontrado — instalando'
    if (Has-Cmd corepack) {
        $old = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { & corepack enable | Out-Null } catch { }
        $ErrorActionPreference = $old
        Refresh-Path
        if (Has-Cmd pnpm) { return }
    }
    $pnpmRoot = Join-Path $DepsDir 'pnpm'
    New-Item -ItemType Directory -Force -Path $pnpmRoot | Out-Null
    Invoke-Exe -File npm -CmdArgs @('install', '--prefix', $pnpmRoot, 'pnpm')
    Add-UserPath (Join-Path $pnpmRoot 'node_modules\.bin')
    if (-not (Has-Cmd pnpm)) { Die 'Nao consegui instalar pnpm.' }
}

function Ensure-Repo([string]$Url, [string]$Dest) {
    if (Test-Path (Join-Path $Dest '.git')) {
        Write-Host "    atualizando $Dest"
        Invoke-Exe -File git -CmdArgs @('-C', $Dest, 'pull', '--ff-only')
        return
    }
    if (Test-Path $Dest) {
        Write-Host "    ja existe (sem git): $Dest"
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $Dest) | Out-Null
    Invoke-Exe -File git -CmdArgs @('clone', '--depth', '1', $Url, $Dest)
}

$admin = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if ($admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Die 'Nao rode como Administrador. Abra o PowerShell normal (sem "Executar como administrador").'
}

$discordRoot = @(
    'Discord', 'DiscordCanary', 'DiscordPTB' |
        ForEach-Object { Join-Path $env:LOCALAPPDATA $_ } |
        Where-Object { Test-Path $_ }
)
$vesktop = Test-Path (Join-Path $env:LOCALAPPDATA 'vesktop')
if ($discordRoot.Count -eq 0 -and -not $vesktop) {
    Die 'Discord (ou Vesktop) nao encontrado. Instale o Discord e rode o script de novo.'
}

Write-Host ''
Write-Host 'CompleteDiscordQuest — instalador' -ForegroundColor Magenta
Write-Host '  1. Git e Node 22+ se faltar'
Write-Host "  2. Vencord em $VencordDir"
Write-Host '  3. plugin em src\userplugins'
Write-Host '  4. pnpm build + inject no Discord'
Write-Host ''
$ans = Read-Host 'Continuar? [S/n]'
if ($ans -match '^[nN]') { Write-Host 'Cancelado.'; exit 0 }

Ensure-Git
Ensure-Node
Ensure-Pnpm

Write-Step "Vencord em $VencordDir"
Ensure-Repo 'https://github.com/Vendicated/Vencord.git' $VencordDir

$pluginDest = Join-Path $VencordDir "src\userplugins\$PluginName"
Write-Step "plugin em $pluginDest"
Ensure-Repo $PluginRepo $pluginDest

Push-Location $VencordDir
try {
    Write-Step 'pnpm install'
    Invoke-Exe -File pnpm -CmdArgs @('install', '--frozen-lockfile')

    Write-Step 'pnpm build'
    Invoke-Exe -File pnpm -CmdArgs @('build')

    if ($discordRoot.Count -gt 0) {
        Write-Step 'inject no Discord (--branch auto)'
        Invoke-Exe -File node -CmdArgs @('scripts/runInstaller.mjs', '--', '--install', '--branch', 'auto')
    } else {
        Write-Host ''
        Write-Host 'Vesktop: nao tem inject automatico.' -ForegroundColor Yellow
        Write-Host "Abra o Vesktop > Configuracoes > Vencord Location e escolha:"
        Write-Host "  $(Join-Path $VencordDir 'dist')"
    }
} finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Pronto.' -ForegroundColor Green
Write-Host '1. Feche o Discord pela bandeja (icone) e abra de novo.'
Write-Host '2. Configuracoes > Vencord > Plugins > CompleteDiscordQuest > ligue.'
Write-Host 'Na primeira vez aparece um aviso de risco.'
