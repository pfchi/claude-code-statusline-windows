# Claude Code Status Line — Windows / PowerShell Edition
# Windows port inspired by https://github.com/isaacaudet/claude-code-statusline
# MIT License — see LICENSE

# ===== config =====
$SHOW_GIT         = $true   # git branch, dirty state, ahead/behind
$SHOW_TOKENS      = $true   # context window usage bar
$SHOW_THINKING    = $true   # extended thinking indicator
$SHOW_RATE_LIMITS = $true   # 5h / 7d usage bars (requires Claude Code v2.1.80+)
$BRANCH_MAX_LEN   = 28      # max branch name display length
$GIT_CACHE_SECS   = 10      # git status cache TTL in seconds (increase for large repos)
$TOKEN_BAR_WIDTH  = 8       # bar width in full-width mode

# ===== read stdin =====
$raw = $input | Out-String
if ([string]::IsNullOrWhiteSpace($raw)) {
    [Console]::Write('Claude')
    exit 0
}

try {
    $json = $raw | ConvertFrom-Json
} catch {
    [Console]::Write('Claude')
    exit 0
}

# ===== terminal width =====
# Claude Code sets $env:COLUMNS since v2.1.153; override with $env:TERM_WIDTH in settings.json.
$TERM_WIDTH = 80
if (($env:TERM_WIDTH -as [int]) -gt 0)  { $TERM_WIDTH = [int]$env:TERM_WIDTH }
elseif (($env:COLUMNS -as [int]) -gt 0) { $TERM_WIDTH = [int]$env:COLUMNS }

# ===== colors (ANSI 24-bit true-color) =====
$ESC     = [char]27
$blue    = "$ESC[38;2;97;175;239m"
$orange  = "$ESC[38;2;255;176;85m"
$amber   = "$ESC[38;2;229;192;123m"
$green   = "$ESC[38;2;80;200;120m"
$cyan    = "$ESC[38;2;86;182;194m"
$red     = "$ESC[38;2;235;87;87m"
$yellow  = "$ESC[38;2;230;200;0m"
$white   = "$ESC[38;2;220;220;220m"
$magenta = "$ESC[38;2;198;120;221m"
$dim     = "$ESC[2m"
$reset   = "$ESC[0m"
$sep     = " ${dim}│${reset} "

# ===== helpers =====
$enUS = [System.Globalization.CultureInfo]::new('en-US')

function Format-Tokens([long]$n) {
    $ic = [System.Globalization.CultureInfo]::InvariantCulture
    if ($n -ge 1000000) { return ($n / 1000000.0).ToString('0.0', $ic) + 'm' }
    if ($n -ge 1000)    { return [string][Math]::Round($n / 1000.0) + 'k' }
    return "$n"
}

function Truncate-Str([string]$s, [int]$max) {
    if ($s.Length -gt $max) { return $s.Substring(0, $max - 1) + '…' }
    return $s
}

function Build-Bar([int]$pct, [int]$width) {
    $pct    = [Math]::Max(0, [Math]::Min(100, $pct))
    $filled = [int][Math]::Floor($pct * $width / 100)
    $empty  = $width - $filled
    $color  = if     ($pct -ge 90) { $red    }
              elseif ($pct -ge 70) { $yellow }
              elseif ($pct -ge 50) { $orange }
              else                 { $green  }
    return "${color}$('█' * $filled)${dim}$('░' * $empty)${reset}"
}

# Convert Unix epoch to reset time: "2:30pm" if today, "jun 8" if a future date
function Format-ResetTime([long]$epoch) {
    if (-not $epoch) { return $null }
    $reset = [DateTimeOffset]::FromUnixTimeSeconds($epoch).LocalDateTime
    if ($reset -le [DateTime]::Now) { return 'now' }
    if ($reset.Date -eq [DateTime]::Today) {
        return $reset.ToString('h:mmtt', $enUS).ToLower()
    }
    return $reset.ToString('MMM d', $enUS).ToLower()
}

function Get-GitInfo([string]$dir) {
    if (-not $dir -or -not (Test-Path $dir)) { return $null }

    $cacheDir = Join-Path $env:TEMP 'claude'
    $null = New-Item -ItemType Directory -Force -Path $cacheDir

    $bytes     = [System.Text.Encoding]::UTF8.GetBytes($dir)
    $hashBytes = [System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)
    $hashStr   = ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
    $cacheFile = Join-Path $cacheDir "git-$hashStr"

    $needsRefresh = $true
    if (Test-Path $cacheFile) {
        $age = (Get-Date) - (Get-Item $cacheFile).LastWriteTime
        if ($age.TotalSeconds -lt $GIT_CACHE_SECS) { $needsRefresh = $false }
    }

    if ($needsRefresh) {
        $branch = git -C $dir symbolic-ref --short HEAD 2>$null
        if (-not $branch) {
            $short = git -C $dir rev-parse --short HEAD 2>$null
            if (-not $short) {
                [IO.File]::WriteAllText($cacheFile, '')
                return $null
            }
            $branch = "($short)"
        }

        $dirty    = if (git -C $dir status --porcelain 2>$null) { 'dirty' } else { '' }
        $upstream = git -C $dir rev-parse --abbrev-ref '@{upstream}' 2>$null
        $ahead = 0; $behind = 0

        if ($upstream) {
            $ab = git -C $dir rev-list --left-right --count "HEAD...$upstream" 2>$null
            if ($ab -match '(\d+)\s+(\d+)') {
                $ahead  = [int]$Matches[1]
                $behind = [int]$Matches[2]
            }
        }

        [IO.File]::WriteAllText($cacheFile, "$branch`t$dirty`t$ahead`t$behind")
    }

    $content = Get-Content -Raw $cacheFile 2>$null
    if ([string]::IsNullOrWhiteSpace($content)) { return $null }
    return $content.TrimEnd()
}

# ===== parse JSON =====
$model_name   = if ($json.model.display_name) { [string]$json.model.display_name } else { 'Claude' }
$cwd          = [string]$json.cwd
$cost_usd     = $json.cost.total_cost_usd

$ctx          = $json.context_window
$size         = [long]($ctx.context_window_size -as [long])
if ($size -le 0) { $size = 200000 }
$input_tok    = [long]$ctx.current_usage.input_tokens
$cache_create = [long]$ctx.current_usage.cache_creation_input_tokens
$cache_read   = [long]$ctx.current_usage.cache_read_input_tokens
$current      = $input_tok + $cache_create + $cache_read
$pct_used     = if ($size -gt 0) { [int]($current * 100 / $size) } else { 0 }

# thinking: prefer stdin JSON, fall back to settings.json
$thinking_on = ($json.thinking.enabled -eq $true)
if (-not $thinking_on) {
    $settings_path = Join-Path $HOME '.claude/settings.json'
    if (Test-Path $settings_path) {
        try {
            $s = Get-Content -Raw $settings_path | ConvertFrom-Json
            if ($s.alwaysThinkingEnabled -eq $true) { $thinking_on = $true }
        } catch {}
    }
}

# ===== width tiers =====
#   full   (>=150): everything — cwd, branch, tokens, thinking, cost, 5h + 7d bars
#   wide   (100-149): branch, tokens, thinking, cost, 5h bar with reset time
#   split  (76-99): thinking symbol only, no cost
#   narrow (<76): short model name, branch, token bar
$width_tier = if    ($TERM_WIDTH -ge 150) { 'full'   }
              elseif ($TERM_WIDTH -ge 100) { 'wide'   }
              elseif ($TERM_WIDTH -ge 76)  { 'split'  }
              else                          { 'narrow' }

function Get-ShortModel([string]$name) {
    if ($name -match 'Opus')   { return 'Opus' }
    if ($name -match 'Sonnet') { return 'Sonnet' }
    if ($name -match 'Haiku')  { return 'Haiku' }
    return ($name -split '\s+')[-1]
}

# ===== build output =====
$out = ''

# model
$model_color = $blue
if ($model_name -match 'Opus')  { $model_color = $amber }
if ($model_name -match 'Haiku') { $model_color = $cyan  }

$display_model = if ($width_tier -eq 'narrow') { Get-ShortModel $model_name } else { $model_name }
$out += "${model_color}${display_model}${reset}"

# cwd (full width only)
if ($width_tier -eq 'full' -and $cwd) {
    $out += "${sep}${dim}$(Split-Path $cwd -Leaf)${reset}"
}

# git branch
if ($SHOW_GIT -and $cwd) {
    $git_info = Get-GitInfo $cwd
    if ($git_info) {
        $parts    = $git_info -split "`t"
        $g_branch = $parts[0]
        $g_dirty  = $parts[1]
        $g_ahead  = [int]$parts[2]
        $g_behind = [int]$parts[3]

        $local_max = switch ($width_tier) {
            'wide'   { 24 }
            'split'  { 18 }
            'narrow' { 12 }
            default  { $BRANCH_MAX_LEN }
        }

        $out += "${sep}${dim}⎇${reset} ${magenta}$(Truncate-Str $g_branch $local_max)${reset}"
        $out += if ($g_dirty -eq 'dirty') { " ${red}✗${reset}" } else { " ${green}✔${reset}" }

        if ($width_tier -ne 'narrow') {
            if ($g_ahead  -gt 0) { $out += " ${green}↑${g_ahead}${reset}" }
            if ($g_behind -gt 0) { $out += " ${orange}↓${g_behind}${reset}" }
        }
    }
}

# token bar
if ($SHOW_TOKENS) {
    $bar_w = switch ($width_tier) {
        'wide'   { 6 }
        'split'  { 5 }
        'narrow' { 4 }
        default  { $TOKEN_BAR_WIDTH }
    }
    $out += "${sep}$(Build-Bar $pct_used $bar_w) ${orange}$(Format-Tokens $current)${dim}/${reset}${white}$(Format-Tokens $size)${reset} ${dim}${pct_used}%${reset}"
}

# thinking indicator
if ($SHOW_THINKING -and $width_tier -ne 'narrow') {
    $out += $sep
    if ($thinking_on) {
        $out += if ($width_tier -eq 'split') { "${amber}◆${reset}" } else { "${amber}◆ thinking${reset}" }
    } else {
        $out += if ($width_tier -eq 'split') { "${dim}◇${reset}"   } else { "${dim}◇ thinking${reset}" }
    }
}

# cost (wide / full)
if ($null -ne $cost_usd -and ($width_tier -eq 'wide' -or $width_tier -eq 'full')) {
    $ic = [System.Globalization.CultureInfo]::InvariantCulture
    $out += "${sep}${dim}`$$( ([double]$cost_usd).ToString('0.00', $ic) )${reset}"
}

# rate limits
# rate_limits field available since Claude Code v2.1.80 (Pro / Max subscription).
# If absent (older version or known Max 20x issue), show a notice instead.
if ($SHOW_RATE_LIMITS -and $width_tier -ne 'narrow') {
    $rl = $json.rate_limits
    if ($rl) {
        $bar_w = if ($width_tier -eq 'split') { 4 } else { 6 }

        # 5-hour limit
        $five_pct = [int]$rl.five_hour.used_percentage
        $out += "${sep}${dim}5h${reset} $(Build-Bar $five_pct $bar_w) ${cyan}${five_pct}%${reset}"

        if ($width_tier -ne 'split') {
            $cd = Format-ResetTime ([long]$rl.five_hour.resets_at)
            if ($cd) { $out += " ${dim}↺ ${cd}${reset}" }
        }

        # 7-day limit (full width only)
        if ($width_tier -eq 'full') {
            $seven_pct = [int]$rl.seven_day.used_percentage
            $out += "${sep}${dim}7d${reset} $(Build-Bar $seven_pct $bar_w) ${cyan}${seven_pct}%${reset}"

            $cd = Format-ResetTime ([long]$rl.seven_day.resets_at)
            if ($cd) { $out += " ${dim}↺ ${cd}${reset}" }
        }
    }
}

# ===== output =====
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::Write($out)
