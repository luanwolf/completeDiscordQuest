<#
    CompleteDiscordQuest - instalador Windows

    Encontra sozinho o Vencord de codigo fonte, instala o plugin, compila e injeta.
    Se nao achar, clona o Vencord. Instala Git/Node/pnpm se faltar.

    irm https://raw.githubusercontent.com/luanwolf/completeDiscordQuest/main/install.ps1 | iex

    .\install.ps1 -Yes
    $env:VENCORD_DIR='D:\Vencord'; irm ... | iex
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force } catch { }

$Yes = ($args -contains '-Yes') -or ($env:CDQ_YES -eq '1')
$Source = $env:VENCORD_DIR
$PluginRepo = 'https://github.com/luanwolf/completeDiscordQuest.git'
$PluginName = 'completeDiscordQuest'
$VencordGit = 'https://github.com/Vendicated/Vencord.git'
$DepsDir = Join-Path $env:LOCALAPPDATA 'completeDiscordQuest\deps'
$MinNodeMajor = 22
$Ua = @{ 'User-Agent' = 'completeDiscordQuest-installer' }
$DiscordNames = @('Discord', 'DiscordCanary', 'DiscordPTB')
$script:PnpmVersion = ''
$script:TuiBg = "$([char]27)[48;5;235m"
$script:TuiFg = "$([char]27)[38;5;252m"
$script:TuiAccent = "$([char]27)[38;5;75m"
$script:TuiOk = "$([char]27)[38;5;114m"
$script:TuiDim = "$([char]27)[38;5;240m"
$script:TuiBold = "$([char]27)[1m"
$script:TuiRset = "$([char]27)[0m"

function Write-Step($text) { Write-Host "  [*] $text" -ForegroundColor DarkGray }
function Write-Ok($text) { Write-Host "  [OK] $text" -ForegroundColor Green }
function Write-Warn($text) { Write-Host "  [!] $text" -ForegroundColor Yellow }
function Write-Err($text) { Write-Host "  [X] $text" -ForegroundColor Red }

function Show-Banner {
    Write-Host ''
    Write-Host '  CompleteDiscordQuest' -ForegroundColor Cyan
    Write-Host '  Completa missoes do Discord em segundo plano' -ForegroundColor DarkGray
    Write-Host '  https://github.com/luanwolf/completeDiscordQuest' -ForegroundColor DarkGray
    Write-Host ''
}

function Read-Escolha($prompt) {
    try { return (Read-Host $prompt) }
    catch { throw 'Este console nao aceita teclado. Abra um PowerShell normal e rode de novo.' }
}

function Test-JanelaTransitoria {
    try {
        $atual = Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction Stop
        $pai = Get-CimInstance Win32_Process -Filter "ProcessId=$($atual.ParentProcessId)" -ErrorAction Stop
        return $pai.Name -eq 'explorer.exe'
    } catch { return $false }
}

function Wait-AntesDeFechar {
    if ($Yes) { return }
    if (-not (Test-JanelaTransitoria)) { return }
    Write-Host ''
    Write-Host '  Pressione Enter para fechar esta janela.' -ForegroundColor DarkGray
    try { [void][Console]::ReadLine() } catch { }
}

function Confirm-Action($question) {
    if ($Yes) { return $true }
    return (Read-Escolha "  $question [S/n]") -notmatch '^[nN]'
}

function Test-TuiAnsi {
    try {
        if (-not ('Win32.CdqConsole' -as [type])) {
            Add-Type -Namespace Win32 -Name CdqConsole -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@ -ErrorAction Stop
        }
        $h = [Win32.CdqConsole]::GetStdHandle(-11)
        if ($h -eq [IntPtr]::Zero) { return $false }
        $mode = [uint32]0
        if (-not [Win32.CdqConsole]::GetConsoleMode($h, [ref]$mode)) { return $false }
        if (($mode -band 0x0004) -eq 0x0004) { return $true }
        [Win32.CdqConsole]::SetConsoleMode($h, ($mode -bor 0x0004)) | Out-Null
        return $true
    } catch { return $false }
}

function Test-TuiInteractive {
    if ($Yes) { return $false }
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return $false }
    return (Test-TuiAnsi)
}

function Tui-HideCursor { Write-Host "$([char]27)[?25l" -NoNewline }
function Tui-ShowCursor { Write-Host "$([char]27)[?25h" -NoNewline }
function Tui-ClearBelow([int]$row) { Write-Host "$([char]27)[$row;0H$([char]27)[J" -NoNewline }

function Tui-GetKey {
    if ([Console]::KeyAvailable) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ([Console]::KeyAvailable -and $sw.ElapsedMilliseconds -lt 80) {
            [void][Console]::ReadKey($true)
        }
    }
    try {
        $k = [Console]::ReadKey($true)
        switch ($k.Key) {
            'UpArrow'   { return 'up' }
            'DownArrow' { return 'down' }
            'Enter'     { return 'enter' }
            'Escape'    { return 'esc' }
            default {
                if ($k.KeyChar -eq 'j') { return 'down' }
                if ($k.KeyChar -eq 'k') { return 'up' }
                if ($k.KeyChar -eq 'q') { return 'esc' }
                return 'other'
            }
        }
    } catch { return 'other' }
}

function Tui-Menu([string]$title, [string[]]$items) {
    if (-not (Test-TuiInteractive)) { return 0 }
    $sel = 0
    $n = $items.Count
    Tui-HideCursor
    try {
        while ($true) {
            Tui-ClearBelow 1
            Write-Host "`r" -NoNewline
            $w = 62
            $topDashes = [Math]::Max(1, $w - 5 - $title.Length)
            Write-Host "$($script:TuiBg)$($script:TuiRset)┌─ $($script:TuiAccent)$title$($script:TuiRset) $($script:TuiDim)$('─' * $topDashes)$($script:TuiRset)┐" -NoNewline
            Write-Host ''
            for ($i = 0; $i -lt $n; $i++) {
                $txt = $items[$i]
                $pad = ' ' * [Math]::Max(0, ($w - 6 - $txt.Length))
                if ($i -eq $sel) {
                    Write-Host "$($script:TuiBg)│ $($script:TuiAccent)●$($script:TuiRset) $($script:TuiBold)$txt$($script:TuiRset)$pad │$($script:TuiRset)" -NoNewline
                } else {
                    Write-Host "$($script:TuiBg)│ $($script:TuiDim)○$($script:TuiRset) $txt$pad │$($script:TuiRset)" -NoNewline
                }
                Write-Host ''
            }
            Write-Host "$($script:TuiBg)└$('─' * ($w - 2))┘$($script:TuiRset)" -NoNewline
            Write-Host ''
            Write-Host "  $($script:TuiDim)[↑↓] navegar  ·  [Enter] escolher  ·  [Esc] cancelar$($script:TuiRset)"
            $key = Tui-GetKey
            switch ($key) {
                'up'    { if ($sel -gt 0) { $sel-- } }
                'down'  { if ($sel -lt $n - 1) { $sel++ } }
                'enter' { break }
                'esc'   { $sel = -1; break }
            }
            if ($key -eq 'enter' -or $key -eq 'esc') { break }
        }
    } finally { Tui-ShowCursor }
    if ($sel -ge 0) { return $sel + 1 } else { return 0 }
}

function Has-Cmd([string]$Name) {
    $null -ne (Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    $env:Path = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
        [Environment]::GetEnvironmentVariable('Path', 'User')
    ) -join ';'
}

function Add-UserPath([string]$Dir) {
    if (-not (Test-Path -LiteralPath $Dir)) { return }
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $user) { $user = '' }
    $parts = $user -split ';' | Where-Object { $_ }
    if ($parts -notcontains $Dir) {
        [Environment]::SetEnvironmentVariable('Path', ($Dir + ';' + $user).TrimEnd(';'), 'User')
    }
    Refresh-Path
}

function Resolve-Native([string]$Name) {
    if ($Name -match '[\\/]' -or $Name -match '\.(cmd|exe|bat|mjs)$') { return $Name }
    foreach ($candidate in @("$Name.cmd", "$Name.exe", "$Name.bat", $Name)) {
        $hit = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit -and $hit.Source -notlike '*.ps1') { return $hit.Source }
    }
    throw "Comando nao encontrado: $Name"
}

function Invoke-Exe {
    param([Parameter(Mandatory)][string]$File, [string[]]$CmdArgs = @())
    $resolved = Resolve-Native $File
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $resolved @CmdArgs
        if ($LASTEXITCODE) { throw "$File $($CmdArgs -join ' ') falhou (codigo $LASTEXITCODE)" }
    } finally { $ErrorActionPreference = $old }
}

function Get-EffectiveLocalApp {
    if ($env:LOCALAPPDATA -and (Test-Path -LiteralPath $env:LOCALAPPDATA)) { return $env:LOCALAPPDATA }
    try {
        $shell = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
        if ($shell -and (Test-Path -LiteralPath $shell)) { return $shell }
    } catch { }
    if ($env:USERPROFILE) { return (Join-Path $env:USERPROFILE 'AppData\Local') }
    return $env:LOCALAPPDATA
}

function Test-VencordSource([string]$Dir) {
    if (-not $Dir -or -not (Test-Path -LiteralPath $Dir)) { return $false }
    if (-not (Test-Path -LiteralPath (Join-Path $Dir 'package.json'))) { return $false }
    if (-not (Test-Path -LiteralPath (Join-Path $Dir 'src\utils\types.ts'))) { return $false }
    $raw = Get-Content -LiteralPath (Join-Path $Dir 'package.json') -Raw -ErrorAction SilentlyContinue
    return [bool]($raw -match '"name"\s*:\s*"vencord"')
}

function Get-DiscordResources {
    $found = @()
    $localApp = Get-EffectiveLocalApp
    if (-not $localApp) { return $found }
    foreach ($name in $DiscordNames) {
        $root = Join-Path $localApp $name
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $apps = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^app-[0-9]' } |
            Sort-Object -Descending -Property @{ Expression = {
                try { [version]($_.Name -replace '^app-', '') } catch { [version]'0.0.0' }
            } }
        foreach ($app in $apps) {
            $resources = Join-Path $app.FullName 'resources'
            $asar = Join-Path $resources 'app.asar'
            $orig = Join-Path $resources '_app.asar'
            if ((Test-Path -LiteralPath $asar) -or (Test-Path -LiteralPath $orig)) { $found += $resources }
        }
    }
    return $found
}

function Get-InjectedPath($resources) {
    if (-not $resources) { return $null }
    $candidates = @()
    $stub = Join-Path $resources 'app.asar'
    if (Test-Path -LiteralPath $stub) {
        $item = Get-Item -LiteralPath $stub
        if ($item -is [IO.FileInfo] -and $item.Length -lt 65536) {
            $candidates += [IO.File]::ReadAllText($stub)
        }
    }
    $index = Join-Path $resources 'app\index.js'
    if (Test-Path -LiteralPath $index) {
        $candidates += Get-Content -LiteralPath $index -Raw -ErrorAction SilentlyContinue
    }
    foreach ($text in $candidates) {
        if (-not $text) { continue }
        $match = [regex]::Match($text, 'require\("(.+?)"\)')
        if ($match.Success) { return $match.Groups[1].Value -replace '\\\\', '\' }
    }
    return $null
}

function Find-CheckoutFromInjection {
    foreach ($resources in Get-DiscordResources) {
        $injected = Get-InjectedPath $resources
        if (-not $injected) { continue }
        $parent1 = Split-Path -Parent $injected
        if (-not $parent1) { continue }
        $root = Split-Path -Parent $parent1
        if ($root -and (Test-VencordSource $root)) { return $root }
    }
    return $null
}

function Find-CheckoutOnDisk {
    $fallback = Join-Path $env:USERPROFILE 'Vencord'
    $hits = @()
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $desktop = [Environment]::GetFolderPath('Desktop')
    foreach ($dir in @(
            $Source
            $fallback
            (Join-Path $docs 'Vencord')
            (Join-Path $desktop 'Vencord')
            (Join-Path $env:USERPROFILE 'Downloads\Vencord')
            (Join-Path $env:USERPROFILE 'source\Vencord')
            (Join-Path $env:USERPROFILE 'src\Vencord')
            (Join-Path $env:USERPROFILE 'dev\Vencord')
            (Join-Path $env:USERPROFILE 'Projects\Vencord')
            (Join-Path $env:USERPROFILE 'git\Vencord')
        )) {
        if ((Test-VencordSource $dir) -and ($hits -notcontains $dir)) { $hits += $dir }
    }

    $roots = @($env:USERPROFILE, $docs, $desktop)
    foreach ($sub in @('Documents', 'Desktop', 'Downloads', 'dev', 'repos', 'projects', 'git', 'source')) {
        $roots += (Join-Path $env:USERPROFILE $sub)
    }
    $roots = $roots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
    foreach ($root in $roots) {
        $found = @(Get-ChildItem -LiteralPath $root -Directory -Filter 'Vencord' -ErrorAction SilentlyContinue)
        foreach ($item in $found) {
            if ($item.FullName -match '\\AppData\\') { continue }
            if ((Test-VencordSource $item.FullName) -and ($hits -notcontains $item.FullName)) {
                $hits += $item.FullName
            }
        }
    }

    if ($hits.Count -eq 0) { return $null }
    $withPlugin = $hits | Where-Object {
        Test-Path -LiteralPath (Join-Path $_ "src\userplugins\$PluginName")
    } | Select-Object -First 1
    if ($withPlugin) { return $withPlugin }
    return $hits[0]
}

function Find-VencordSource {
    if ($Source) {
        if (Test-VencordSource $Source) { return $Source }
        if (-not (Test-Path -LiteralPath $Source)) { return $Source }
        throw "VENCORD_DIR nao e um Vencord de codigo fonte: $Source"
    }
    $fromDiscord = Find-CheckoutFromInjection
    if ($fromDiscord) { return $fromDiscord }
    return (Find-CheckoutOnDisk)
}

function Show-Status($root) {
    $discord = @(Get-DiscordResources).Count
    $vesktop = Test-Path -LiteralPath (Join-Path (Get-EffectiveLocalApp) 'vesktop')

    Write-Host '  Detectado:' -ForegroundColor White
    if ($discord -gt 0) { Write-Host "    Discord   instalado ($discord versao(oes))" -ForegroundColor DarkGray }
    elseif ($vesktop) { Write-Host '    Discord   Vesktop' -ForegroundColor DarkGray }
    else { Write-Host '    Discord   nao encontrado' -ForegroundColor Yellow }

    if ($root) {
        Write-Host "    Fonte     $root" -ForegroundColor DarkGray
        $plugin = Join-Path $root "src\userplugins\$PluginName"
        if (Test-Path -LiteralPath $plugin) { Write-Host '    Plugin    ja instalado' -ForegroundColor Green }
        else { Write-Host '    Plugin    nao instalado' -ForegroundColor DarkGray }
    } else {
        Write-Host '    Fonte     nao encontrado (vou clonar o Vencord)' -ForegroundColor DarkGray
    }
    Write-Host ''
}

function Get-NodeMajor {
    if (-not (Has-Cmd node)) { return 0 }
    $raw = & (Resolve-Native 'node') -v 2>$null
    if ($raw -match 'v(\d+)') { return [int]$Matches[1] }
    return 0
}

function Test-Pnpm {
    if (-not (Has-Cmd pnpm)) { return $false }
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $found = & (Resolve-Native 'pnpm') --version 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }
        $script:PnpmVersion = ($found | Select-Object -First 1)
        return $true
    } catch { return $false }
    finally { $ErrorActionPreference = $old }
}

function Install-Winget([string]$Id) {
    if (-not (Has-Cmd winget)) { return $false }
    Write-Step "winget install $Id"
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & winget install -e --id $Id --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
        Refresh-Path
        foreach ($extra in @('C:\Program Files\nodejs', 'C:\Program Files\Git\cmd')) {
            if ((Test-Path -LiteralPath $extra) -and ($env:Path -notlike "*$extra*")) {
                $env:Path = "$extra;$env:Path"
            }
        }
        return $true
    } catch { return $false }
    finally { $ErrorActionPreference = $old }
}

function Install-PortableNode {
    Write-Step 'baixando Node portatil (nodejs.org)'
    $idx = Invoke-RestMethod 'https://nodejs.org/dist/index.json'
    $rel = $idx | Where-Object { $_.lts } | Select-Object -First 1
    if (-not $rel) { throw 'Nao achei um Node LTS em nodejs.org' }
    $ver = $rel.version
    $zipName = "node-$ver-win-x64.zip"
    $zip = Join-Path $env:TEMP $zipName
    Invoke-WebRequest "https://nodejs.org/dist/$ver/$zipName" -OutFile $zip -UseBasicParsing
    $dest = Join-Path $DepsDir 'node'
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $DepsDir | Out-Null
    $extracted = Join-Path $DepsDir "node-$ver-win-x64"
    if (Test-Path -LiteralPath $extracted) { Remove-Item -LiteralPath $extracted -Recurse -Force }
    Expand-Archive $zip -DestinationPath $DepsDir -Force
    Rename-Item $extracted 'node'
    Remove-Item -LiteralPath $zip -Force
    Add-UserPath $dest
}

function Install-PortableGit {
    Write-Step 'baixando MinGit (git-for-windows)'
    $rel = Invoke-RestMethod 'https://api.github.com/repos/git-for-windows/git/releases/latest' -Headers $Ua
    $asset = $rel.assets | Where-Object { $_.name -match '^MinGit-.*-64-bit\.zip$' -and $_.name -notmatch 'busybox' } | Select-Object -First 1
    if (-not $asset) { throw 'Nao achei MinGit na release do git-for-windows' }
    $zip = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing -Headers $Ua
    $dest = Join-Path $DepsDir 'git'
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Expand-Archive $zip -DestinationPath $dest -Force
    Remove-Item -LiteralPath $zip -Force
    Add-UserPath (Join-Path $dest 'cmd')
}

function Install-Toolchain {
    if (-not (Has-Cmd git)) {
        Write-Warn 'Git nao esta no PATH'
        [void](Install-Winget 'Git.Git')
        if (-not (Has-Cmd git)) { Install-PortableGit }
        if (-not (Has-Cmd git)) { throw 'Instale o Git em https://git-scm.com/download/win e rode de novo.' }
        Write-Ok 'Git pronto'
    }

    if ((Get-NodeMajor) -lt $MinNodeMajor) {
        Write-Warn "Node $MinNodeMajor+ nao esta no PATH"
        [void](Install-Winget 'OpenJS.NodeJS.LTS')
        if ((Get-NodeMajor) -lt $MinNodeMajor) { Install-PortableNode }
        if ((Get-NodeMajor) -lt $MinNodeMajor) { throw "Instale Node $MinNodeMajor+ em https://nodejs.org/ e rode de novo." }
        Write-Ok "Node $(Get-NodeMajor) pronto"
    }

    if (-not (Test-Pnpm)) {
        Write-Step 'preparando pnpm'
        if (Has-Cmd corepack) {
            $old = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $corepack = Get-Command corepack.cmd -CommandType Application -ErrorAction SilentlyContinue
                if ($corepack) { & $corepack.Source disable pnpm 2>$null | Out-Null }
            } catch { }
            $ErrorActionPreference = $old
            Refresh-Path
        }
        if (-not (Test-Pnpm)) {
            $pnpmRoot = Join-Path $DepsDir 'pnpm'
            New-Item -ItemType Directory -Force -Path $pnpmRoot | Out-Null
            Invoke-Exe -File npm -CmdArgs @('install', '--prefix', $pnpmRoot, 'pnpm')
            Add-UserPath (Join-Path $pnpmRoot 'node_modules\.bin')
        }
        if (-not (Test-Pnpm)) { throw 'Nao consegui deixar o pnpm funcionando. Rode: npm install -g pnpm' }
    }
    Write-Ok "pnpm $script:PnpmVersion"
}

function Test-GitDirty([string]$Dest) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & (Resolve-Native 'git') -C $Dest status --porcelain 2>$null
        return [bool]$out
    } catch { return $true }
    finally { $ErrorActionPreference = $old }
}

function Get-GitHead([string]$Dest, [string]$Rev = 'HEAD') {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $h = & (Resolve-Native 'git') -C $Dest rev-parse $Rev 2>$null
        if ($LASTEXITCODE) { return '' }
        return ("$h").Trim()
    } catch { return '' }
    finally { $ErrorActionPreference = $old }
}

function Save-InstallState([string]$Root, [string]$PluginDest) {
    $dir = Join-Path $env:LOCALAPPDATA 'completeDiscordQuest'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Save-Text (Join-Path $dir 'vencord-root.txt') $Root
    $sha = Get-GitHead $PluginDest
    if ($sha) { Save-Text (Join-Path $dir 'installed-sha.txt') $sha }
}

function Ensure-Repo([string]$Url, [string]$Dest, [switch]$NoPull) {
    $git = Resolve-Native 'git'
    if (Test-Path -LiteralPath (Join-Path $Dest '.git')) {
        if ($NoPull) {
            Write-Ok 'reusando checkout (sem git pull)'
            return
        }
        if (Test-GitDirty $Dest) {
            Write-Warn "checkout com mudancas locais — alinhando com o GitHub"
        }
        Write-Step "atualizando $Dest"
        $before = Get-GitHead $Dest
        $old = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $git -C $Dest fetch --depth 1 origin main
            if ($LASTEXITCODE) {
                Write-Warn "git fetch falhou — reusando o que ja esta em $Dest"
                return
            }
            $resetOk = $false
            foreach ($try in 1..3) {
                & $git -C $Dest reset --hard FETCH_HEAD
                if (-not $LASTEXITCODE) { $resetOk = $true; break }
                Start-Sleep -Milliseconds 400
            }
            if (-not $resetOk) {
                Write-Warn "git reset falhou — overlay a partir de clone temporario"
                $tmp = Join-Path $env:TEMP ("cdq-overlay-" + [guid]::NewGuid().ToString('N'))
                try {
                    & $git clone --depth 1 $Url $tmp
                    if ($LASTEXITCODE) {
                        Write-Warn "overlay falhou — reusando o que ja esta em $Dest"
                        return
                    }
                    $robo = Join-Path $env:SystemRoot 'System32\robocopy.exe'
                    if (-not (Test-Path -LiteralPath $robo)) { $robo = 'robocopy' }
                    & $robo $tmp $Dest /E /XD .git /R:1 /W:1 /NFL /NDL /NJH /NJS /NC /NS /NP
                    if ($LASTEXITCODE -ge 8) { Write-Warn "overlay parcial — alguns arquivos nao copiaram" }
                    & $git -C $Dest update-ref HEAD FETCH_HEAD
                } finally {
                    if (Test-Path -LiteralPath $tmp) {
                        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            } else {
                & $git -C $Dest clean -fd
            }
        } finally { $ErrorActionPreference = $old }
        $after = Get-GitHead $Dest
        $want = Get-GitHead $Dest 'FETCH_HEAD'
        if (-not $want) { $want = Get-GitHead $Dest 'origin/main' }
        if ($before -ne $after -or ($after -and $want -and $after -ne $want)) { $script:RepoUpdated = $true }
        Write-Ok 'repositorio atualizado'
        return
    }
    if (Test-Path -LiteralPath $Dest) {
        if ($NoPull) {
            Write-Ok "ja existe (sem git): $Dest"
            return
        }
        Write-Warn "pasta sem git — clonando de novo em $Dest"
        Remove-Item -LiteralPath $Dest -Recurse -Force
    }
    $parent = Split-Path $Dest
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Write-Step "git clone $Url"
    Invoke-Exe -File git -CmdArgs @('clone', '--depth', '1', $Url, $Dest)
    $script:RepoUpdated = $true
    Write-Ok "clonado em $Dest"
}

function Save-Text($path, $text) {
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Set-PluginEnabled([string]$root) {
    $files = @()
    if ($env:APPDATA) { $files += (Join-Path $env:APPDATA 'Vencord\settings\settings.json') }
    if ($root -and (Test-Path -LiteralPath (Join-Path $root 'settings'))) {
        $files += (Join-Path $root 'settings\settings.json')
    }
    if ($env:APPDATA -and (Test-Path -LiteralPath (Join-Path $env:APPDATA 'vesktop'))) {
        $files += (Join-Path $env:APPDATA 'vesktop\settings\settings.json')
    }

    foreach ($file in ($files | Select-Object -Unique)) {
        $settings = $null
        if (Test-Path -LiteralPath $file) {
            try { $settings = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json } catch { $settings = 'ilegivel' }
        }
        if ($settings -is [string]) {
            Write-Warn "Nao consegui ler $file, nao mexi nele."
            continue
        }
        if ($null -eq $settings) { $settings = [pscustomobject]@{} }
        if (-not $settings.PSObject.Properties['plugins']) {
            $settings | Add-Member -NotePropertyName plugins -NotePropertyValue ([pscustomobject]@{}) -Force
        }
        $existing = $settings.plugins.PSObject.Properties['CompleteDiscordQuest']
        $plugin = if ($existing) { $existing.Value } else { [pscustomobject]@{} }
        $plugin | Add-Member -NotePropertyName enabled -NotePropertyValue $true -Force
        $settings.plugins | Add-Member -NotePropertyName CompleteDiscordQuest -NotePropertyValue $plugin -Force
        Save-Text $file ($settings | ConvertTo-Json -Depth 10)
        Write-Ok "plugin ativado em $file"
    }
}

function Stop-Discord {
    if (-not (Get-Process -Name $DiscordNames -ErrorAction SilentlyContinue)) { return }
    Write-Step 'Fechando o Discord'
    Get-Process -Name $DiscordNames -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 300
        if (-not (Get-Process -Name $DiscordNames -ErrorAction SilentlyContinue)) { return }
    }
    throw 'O Discord nao fechou. Feche pelo icone na bandeja e rode de novo.'
}

function Start-Discord {
    $localApp = Get-EffectiveLocalApp
    foreach ($name in $DiscordNames) {
        $exe = Join-Path $localApp "$name\Update.exe"
        if (Test-Path -LiteralPath $exe) {
            Start-Process -FilePath $exe -ArgumentList '--processStart', "$name.exe"
            Write-Ok "Discord reaberto ($name)"
            return
        }
    }
}

function Select-Target($found) {
    $fallback = Join-Path $env:USERPROFILE 'Vencord'
    if ($Source) { return $Source }
    if (-not $found) { return $fallback }
    if ($Yes) { return $found }

    $name = Split-Path -Leaf $found
    if (Test-TuiInteractive) {
        $tui = Tui-Menu 'Onde instalar?' @(
            "Usar o $name que ja esta aqui"
            'Baixar um Vencord novo em %USERPROFILE%\Vencord'
        )
        if ($tui -eq 2) { return $fallback }
        if ($tui -eq 1) { return $found }
        throw 'Cancelado.'
    }

    Write-Host '  Onde instalar?' -ForegroundColor White
    Write-Host ''
    Write-Host "    [1] Usar o $name que ja esta aqui" -ForegroundColor Green
    Write-Host "        $found" -ForegroundColor DarkGray
    Write-Host '    [2] Baixar um Vencord novo' -ForegroundColor Cyan
    Write-Host "        $fallback" -ForegroundColor DarkGray
    Write-Host ''
    if ((Read-Escolha '  Escolha') -eq '2') { return $fallback }
    return $found
}

function Invoke-Install {
    $admin = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Nao rode como Administrador. Abra o PowerShell normal (sem "Executar como administrador").'
    }

    $localApp = Get-EffectiveLocalApp
    $discordRoot = @(Get-DiscordResources)
    $vesktop = Test-Path -LiteralPath (Join-Path $localApp 'vesktop')
    if ($discordRoot.Count -eq 0 -and -not $vesktop) {
        throw 'Nao achei nenhum Discord instalado. Instale o Discord e rode de novo.'
    }

    $found = Find-VencordSource
    Show-Status $found
    $root = Select-Target $found

    Write-Host '  Vou fazer:' -ForegroundColor White
    Write-Host '    1. Git e Node 22+ se faltar' -ForegroundColor DarkGray
    if (Test-VencordSource $root) {
        Write-Host "    2. Reusar o Vencord em $root" -ForegroundColor DarkGray
    } else {
        Write-Host "    2. Clonar o Vencord em $root" -ForegroundColor DarkGray
    }
    Write-Host '    3. Atualizar o plugin em src\userplugins a partir do GitHub' -ForegroundColor DarkGray
    Write-Host '    4. Compilar e injetar no Discord' -ForegroundColor DarkGray
    Write-Host '    5. Ativar o plugin e reabrir o Discord' -ForegroundColor DarkGray
    Write-Host ''
    if (-not (Confirm-Action 'Pode seguir?')) { throw 'Cancelado.' }

    if ($Yes) {
        Write-Step 'Fechando o Discord para atualizar'
        Stop-Discord
    }

    Refresh-Path
    $gitCmd = Join-Path $env:ProgramFiles 'Git\cmd'
    if ($gitCmd -and (Test-Path -LiteralPath $gitCmd)) { $env:Path = "$gitCmd;$env:Path" }

    $script:RepoUpdated = $false
    Write-Step "Vencord em $root"
    if (Test-VencordSource $root) { Write-Ok 'reusando pasta existente' }
    Ensure-Repo $VencordGit $root -NoPull

    $pluginDest = Join-Path $root "src\userplugins\$PluginName"
    Write-Step "plugin em $pluginDest"
    Ensure-Repo $PluginRepo $pluginDest

    $dist = Join-Path $root 'dist\vencordDesktopRenderer.js'
    $localSha = Get-GitHead $pluginDest
    $wantSha = Get-GitHead $pluginDest 'FETCH_HEAD'
    if (-not $wantSha) { $wantSha = Get-GitHead $pluginDest 'origin/main' }
    if (-not $script:RepoUpdated -and $localSha -and $wantSha -and $localSha -eq $wantSha -and (Test-Path -LiteralPath $dist)) {
        Save-InstallState $root $pluginDest
        Set-PluginEnabled $root
        Write-Ok 'plugin ja esta na versao do GitHub'
        Write-Host ''
        Write-Ok 'Pronto. Nada novo pra instalar.'
        if ($Yes) { Start-Discord }
        return
    }

    Push-Location -LiteralPath $root
    try {
        Write-Step 'Instalando dependencias (na primeira vez demora alguns minutos)'
        Invoke-Exe -File pnpm -CmdArgs @('install', '--frozen-lockfile')
        Write-Ok 'dependencias ok'

        Write-Step 'Compilando'
        Invoke-Exe -File pnpm -CmdArgs @('build')
        Write-Ok 'build ok'

        if ($discordRoot.Count -gt 0) {
            Write-Step 'Injetando no Discord (--branch auto)'
            Invoke-Exe -File node -CmdArgs @('scripts/runInstaller.mjs', '--', '--install', '--branch', 'auto')
            Write-Ok 'inject ok'
        } else {
            Write-Warn 'Vesktop: nao tem inject automatico.'
            Write-Host "  Em Configuracoes > Vencord Location, escolha:" -ForegroundColor DarkGray
            Write-Host "  $(Join-Path $root 'dist')" -ForegroundColor White
        }
    } finally { Pop-Location }

    Stop-Discord
    Write-Step 'Ativando o plugin'
    Set-PluginEnabled $root
    Start-Discord

    Write-Host ''
    Write-Ok 'Pronto. O plugin ja vem ligado.'
    Write-Host '  Na primeira vez aparece um aviso de risco. OK liga a automacao.' -ForegroundColor DarkGray
}

Show-Banner
if ($Yes) {
    $logDir = Join-Path $env:LOCALAPPDATA 'completeDiscordQuest'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    try { Start-Transcript -Path (Join-Path $logDir 'update.log') -Append | Out-Null } catch { }
}
try {
    Invoke-Install
} catch {
    Write-Host ''
    Write-Err $_.Exception.Message
    $info = $_.InvocationInfo
    if ($info -and $info.ScriptLineNumber) {
        Write-Host "      linha $($info.ScriptLineNumber): $($info.Line.Trim())" -ForegroundColor DarkGray
    }
    Wait-AntesDeFechar
    exit 1
}

Write-Host ''
Wait-AntesDeFechar
