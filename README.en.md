# claude-code-statusline-windows

A Windows-native status line script for [Claude Code](https://claude.ai/code), written in pure PowerShell with **zero extra dependencies**.

> Inspired by [isaacaudet/claude-code-statusline](https://github.com/isaacaudet/claude-code-statusline) (bash / macOS & Linux edition)

---

## What it shows

![preview](preview.svg)

| Section | Meaning |
|---------|---------|
| `Sonnet 4.6` | Current model — amber for Opus, blue for Sonnet, cyan for Haiku |
| `my-project` | Current working directory folder name |
| `⎇ main` | Git branch in the current working directory |
| `✔` / `✗` | Clean or dirty working tree |
| `↑2 ↓1` | Commits ahead / behind upstream (hidden when zero) |
| `███░░░░░ 77k/200k 38%` | Context window usage bar |
| `◆ thinking` / `◇ thinking` | Extended thinking on (◆) / off (◇) |
| `$55.66` | Running session cost |
| `5h █████░ 89% ↺ 9:50pm` | 5-hour rate limit bar with reset time (time if today, date if later) |
| `7d ███░░░ 64% ↺ jun 23` | 7-day rate limit bar with reset date |

---

## Install

**Step 1: Download `statusline.ps1` and place it in `~\.claude\`**

**Step 2: Add to `~\.claude\settings.json`**

```jsonc
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -File ~/.claude/statusline.ps1"
  }
}
```

**Step 3: Restart Claude Code**

The status line should appear at the bottom immediately.

---

## Responsive width

The script automatically adjusts what it shows based on terminal width so the line never wraps.

| Width | What's shown |
|-------|-------------|
| ≥ 150 | Everything: cwd, branch ↑↓, tokens, thinking, cost, 5h + 7d bars |
| 100–149 | Branch ↑↓, tokens, thinking, cost, 5h bar with reset time |
| 76–99 | Branch ↑↓, tokens, thinking symbol, 5h bar |
| < 76 | Short model name, branch, tokens |

Claude Code sets `$env:COLUMNS` automatically since v2.1.153, so width detection works out of the box.
To override manually:

```powershell -NoProfile -Command "$env:TERM_WIDTH=160; & '~/.claude/statusline.ps1'"```

---

## Configuration

Edit the config block at the top of `statusline.ps1`:

```powershell
$SHOW_GIT         = $true   # git branch, dirty, ahead/behind
$SHOW_TOKENS      = $true   # context window bar
$SHOW_THINKING    = $true   # extended thinking indicator
$SHOW_RATE_LIMITS = $true   # 5h / 7d usage bars
$BRANCH_MAX_LEN   = 28      # max branch name length before truncation
$GIT_CACHE_SECS   = 10      # git cache TTL (increase for large repos)
$TOKEN_BAR_WIDTH  = 8       # bar width in full-width mode
```

---

## Rate limits

Rate limit data (5h / 7d bars) comes directly from Claude Code via the stdin JSON — **no API call needed**, no OAuth token required.

- Requires **Claude Code v2.1.80 or later**
- If the field is absent (older version or unsupported plan), the section is silently hidden
- To disable: set `$SHOW_RATE_LIMITS = $false`

---

## Requirements

- **Windows PowerShell 5.1+** (`powershell`) — built-in on all Windows systems, no installation needed
- **Windows Terminal** (recommended) — required for ANSI 24-bit color rendering
- **git** (optional) — needed for branch display
- **Claude Code v2.1.80+** (optional) — needed for rate limit bars

---

## Manual test

Test output directly without launching Claude Code:

```powershell
'{"model":{"display_name":"Claude Sonnet 4.6"},"cwd":"C:/Users/user/project","cost":{"total_cost_usd":1.24},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":45000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"rate_limits":{"five_hour":{"used_percentage":28,"resets_at":1750000000},"seven_day":{"used_percentage":61,"resets_at":1750500000}}}' | powershell -NoProfile -File statusline.ps1
```

---

## Credits

Inspired by [isaacaudet/claude-code-statusline](https://github.com/isaacaudet/claude-code-statusline).

---

## License

[MIT License](LICENSE)

Chinese documentation: [README.md](README.md)
