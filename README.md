# claude-code-statusline-windows

[Claude Code](https://claude.ai/code) 的 Windows 專用狀態列腳本，以純 PowerShell 撰寫，**零額外依賴**。

> 靈感來源：[isaacaudet/claude-code-statusline](https://github.com/isaacaudet/claude-code-statusline)（bash / macOS·Linux 版本）

---

## 顯示內容

![preview](preview.svg)

| 區段 | 說明 |
|------|------|
| `Sonnet 4.6` | 目前使用的模型 — Opus 為琥珀色、Sonnet 為藍色、Haiku 為青色 |
| `(◐ medium)` | Reasoning effort 等級,以暗色括號緊貼模型名稱。字符依強度填充 `○ low` `◐ medium` `● high` `◉ xhigh` `◈ max`,配色比照 Claude Code 設定畫面;`max` 以彩虹呈現。模型不支援 effort 時自動隱藏 |
| `my-project` | 目前工作目錄的資料夾名稱 |
| `⎇ main` | 目前工作目錄的 git 分支名稱 |
| `✔` / `✗` | 工作目錄乾淨 / 有未提交的變更 |
| `↑2 ↓1` | 與上游的差距（數量為零時自動隱藏） |
| `███░░░░░ 77k/200k 38%` | Context window 使用量進度條 |
| `◆ thinking` / `◇ thinking` | Extended thinking 開啟（◆）/ 關閉（◇） |
| `$55.66` | 本次工作階段累計費用 |
| `5h █████░ 89% ↺ 9:50pm` | 5 小時用量限制進度條與重置時刻（當天顯示時間，跨日顯示日期） |
| `7d ███░░░ 64% ↺ jun 23` | 7 天用量限制進度條與重置日期 |

---

## 安裝

**步驟一：下載 `statusline.ps1`，放到 `~\.claude\` 目錄下**

**步驟二：設定 `~\.claude\settings.json`**

```jsonc
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -File ~/.claude/statusline.ps1"
  }
}
```

**步驟三：重新啟動 Claude Code**

狀態列應立即出現在畫面底部。

---

## 響應式寬度

腳本會依據終端機寬度自動調整顯示內容，確保不換行。

| 寬度 | 顯示內容 |
|------|---------|
| ≥ 150 | 完整：effort、工作目錄、分支 ↑↓、tokens、thinking、費用、5h + 7d 用量 |
| 100–149 | effort、分支 ↑↓、tokens、thinking、費用、5h 用量（含重置時間） |
| 76–99 | effort、分支 ↑↓、tokens、thinking 符號、5h 進度條 |
| < 76 | 縮短模型名、effort（僅字符）、分支、tokens |

> effort 在所有寬度都顯示；窄寬度（< 76）僅保留字符（字符本身已編碼等級），其餘寬度顯示「字符 + 等級」。

Claude Code 從 v2.1.153 起會自動傳入 `$env:COLUMNS`，大多數情況下無須手動設定。
若需覆寫，可在 `command` 中加入：

```powershell -NoProfile -Command "$env:TERM_WIDTH=160; & '~/.claude/statusline.ps1'"```

---

## 設定選項

直接編輯 `statusline.ps1` 頂端的設定區塊：

```powershell
$SHOW_GIT         = $true   # git 分支、dirty、ahead/behind
$SHOW_TOKENS      = $true   # context window 進度條
$SHOW_EFFORT      = $true   # reasoning effort 等級(low/medium/high/xhigh/max)
$SHOW_THINKING    = $true   # extended thinking 指示器
$SHOW_RATE_LIMITS = $true   # 5h / 7d 用量限制
$BRANCH_MAX_LEN   = 28      # 分支名稱最大長度
$GIT_CACHE_SECS   = 10      # git 快取秒數（大型 repo 可調高）
$TOKEN_BAR_WIDTH  = 8       # 進度條寬度（full 模式）
```

---

## 用量限制

用量限制資訊（5h / 7d 進度條）直接由 Claude Code 透過 stdin JSON 傳入，**不需要打 API**，也不需要 OAuth token。

- 需要 **Claude Code v2.1.80 或更新版本**
- 若欄位不存在（版本過舊或方案不支援），該區段自動隱藏
- 不需要此功能可設定 `$SHOW_RATE_LIMITS = $false`

---

## 系統需求

- **Windows PowerShell 5.1+**（`powershell`）— Windows 內建，無需另外安裝
- **Windows Terminal**（建議）— 支援 ANSI 24-bit 色彩
- **git**（可選）— 顯示分支資訊需要
- **Claude Code v2.1.80+**（可選）— 顯示用量限制需要

---

## 手動測試

不啟動 Claude Code，直接在終端機測試輸出：

```powershell
'{"model":{"display_name":"Claude Sonnet 4.6"},"cwd":"C:/Users/user/project","cost":{"total_cost_usd":1.24},"effort":{"level":"high"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":45000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"rate_limits":{"five_hour":{"used_percentage":28,"resets_at":1750000000},"seven_day":{"used_percentage":61,"resets_at":1750500000}}}' | powershell -NoProfile -File statusline.ps1
```

---

## Credits

靈感來自 [isaacaudet/claude-code-statusline](https://github.com/isaacaudet/claude-code-statusline)。

---

## 授權

[MIT License](LICENSE)

英文說明請見 [README.en.md](README.en.md)。
