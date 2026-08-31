# Lightroom MCP＋RAW 挑圖調色 Skill v2

讓 Codex、Claude 等 AI client 透過 MCP 操作 Adobe Lightroom Classic，並保留可追蹤、可讀回、不覆寫的安全邊界。

## TL;DR

`lightroom-mcp` 是 Lightroom Classic 的本機整合層。它用 Node.js MCP server 連接 Lightroom Lua 外掛，提供 catalog 查詢、評分、關鍵字、Develop 設定、Virtual Copy、preset checkpoint 與匯出工具。這個 fork 也保留 `raw-photo-lightroom-preset` v2 skill，協助你先分群、再用代表照片逐步調色。它可以單獨使用，也能作為 [`photo-agent`](https://github.com/John-owo/photo-agent) 的 backend。

目前 server 有 20 個工具。版本化 checkpoint 的建立、讀回與匯出已在一個 Windows Lightroom Classic 環境完成實機驗證；匯出的 preset 仍需在你的 Lightroom 版本重新匯入並檢查畫面，才能確認相容性與風格。

## 目錄

- [功能總覽](#功能總覽)
- [架構與專案邊界](#架構與專案邊界)
- [名詞對照](#名詞對照)
- [快速開始](#快速開始)
- [環境需求](#環境需求)
- [Repository 內容](#repository-內容)
- [v2 挑圖流程](#v2-挑圖流程)
- [歷史色調迭代流程](#歷史色調迭代流程)
- [MCP 工具](#mcp-工具)
- [Windows 安裝](#windows-安裝)
- [安全邊界](#安全邊界)
- [已驗證範圍](#已驗證範圍)
- [進一步文件](#進一步文件)

## 功能總覽

| 功能 | 你可以做什麼 |
| --- | --- |
| Catalog 查詢 | 搜尋照片、讀取目前選取項目、metadata 與 Master／Virtual Copy 關係 |
| 整理照片 | 設定評分、關鍵字、collection，並匯入或匯出照片 |
| Develop 調整 | 讀取或套用 preset、複製設定、寫入 Lightroom SDK 支援的 Develop 欄位 |
| Workflow Copy | 依穩定 catalog ID、Master UUID 與 operation ID 建立或查核 Virtual Copy |
| 版本化 checkpoint | 建立、比較與匯出不覆寫舊版本的 plugin preset |
| RAW 挑圖與分群 | 用 bundled skill 配對 RAW／JPG、標記狀態，再按光線與用途分群 |
| Lightroom render | 由 Lightroom 輸出預覽或交付檔，讓 client 比較實際結果 |
| XMP fallback | MCP 無法使用時建立新的 sidecar；拒絕覆寫來源檔或既有 sidecar |

## 架構與專案邊界

```text
┌──────────────────────┐   MCP / stdio   ┌──────────────────────┐
│ Codex、Claude、PhotoAgent │ ◄────────────► │ Node.js MCP server   │
└──────────────────────┘                 └──────────┬───────────┘
                                                   │ localhost TCP
                                            :58763 │ request
                                            :58764 │ response
                                                   ▼
                                        ┌──────────────────────┐
                                        │ Lightroom Lua 外掛    │
                                        └──────────┬───────────┘
                                                   ▼
                                        Lightroom catalog／Develop
```

本 repository 負責 MCP server、Lua 外掛、catalog／Develop 操作、checkpoint 與 render／export transport。`photo-agent` 負責工作流程狀態、安全／恢復政策、closed-loop 評估、選片、場景分群與整場拍攝編排。依賴是單向的：`photo-agent -> lightroom-mcp`；本專案不依賴 PhotoAgent。

這個 fork 最初把 Lightroom MCP 與完整的 `raw-photo-lightroom-preset` v2 skill 放在同一個 repository。v0.1 之後，上層 workflow engine 已抽離至 [`John-owo/photo-agent`](https://github.com/John-owo/photo-agent)。repository 內的 skill 保留為可獨立使用的 client recipe 與歷史工作流程指引。

## 名詞對照

| 名詞 | 白話解釋 |
| --- | --- |
| MCP（Model Context Protocol） | 讓 AI client 呼叫外部工具的協定；本專案的 server 提供 Lightroom 工具 |
| XMP sidecar | 放在 RAW 旁邊、記錄調色設定的小檔案；它不改寫 RAW 內容 |
| checkpoint | 一份有版本名稱的 preset 存檔，用來保留每輪調整與比較差異 |
| Workflow Copy | 經身分驗證後供自動流程操作的 Lightroom Virtual Copy，Master 保持不動 |
| `REVIEW_REQUIRED` | 系統無法確認結果時主動停止，交給人檢查，不盲目重試 |
| closed loop | 每次調整後都由 Lightroom render 或讀回結果，再決定下一步 |

## 快速開始

1. 從 [`John-owo/lightroom-mcp`](https://github.com/John-owo/lightroom-mcp) clone `main`，在 `server/` 執行 `npm ci` 與 `npm run build`。
2. 執行 `node .\server\dist\index.js install-plugin`，完整重開 Lightroom Classic。
3. 到「檔案 → 增效模組管理員 → Lightroom MCP」按 **Start Server**。
4. 把 `server/dist/index.js` 加到 MCP client，重啟 client 後先試「列出我目前的 Lightroom collections」。

完整 PowerShell 指令與 Codex 設定在[Windows 安裝](#windows-安裝)。第一次測試請使用非關鍵照片，先做唯讀查詢。

## 環境需求

| 項目 | 要求 | 備註 |
| --- | --- | --- |
| Node.js | 18 以上 | 從原始碼建置 server；CI 目前使用 24.19 |
| Adobe Lightroom Classic | 可載入本專案 Lua 外掛的版本 | 專案尚未宣稱特定最低版本 |
| 作業系統 | Windows 或 macOS | 本 fork 的實機驗證紀錄來自 Windows |
| MCP client | Codex、Claude 或其他相容 client | PhotoAgent 不是必需安裝項目 |

本 fork 的 Lightroom／skill 歷史範圍涵蓋：

- RAW／JPG 配對與挑圖；
- 按光線場景分群；
- 讀取過往 Lightroom preset 的實際設定；
- 小步調整、輸出預覽、比較結果；
- 建立不覆寫舊版本的 preset checkpoint；
- 匯出 Lightroom 產生的 preset 檔案；
- MCP 不可用時的安全 XMP fallback。

上游專案仍保留為 [`Automaat/lightroom-mcp`](https://github.com/Automaat/lightroom-mcp)。使用 fork 而不是另開無關 repository，可以保留原始 commit、MIT 授權與未來同步 upstream 的能力；本機建議維持 `origin` 指向本 fork、`upstream` 指向原作者。

## Repository 內容

```text
plugin/LightroomMCP.lrplugin/       Lightroom Classic Lua 外掛
server/                             MCP server 與工具契約
skills/raw-photo-lightroom-preset/ 完整 v2 Codex skill
tests/e2e/                          Lightroom 實機驗證流程
```

Skill 目錄包含 `SKILL.md`、UI metadata、挑圖／調色／MCP 參考文件、風格資料、XMP 產生器及其測試；不含使用者照片、catalog、token 或本機絕對路徑。

## v2 挑圖流程

### 1. 先建立來源關係

每組 RAW／預覽至少記錄相對路徑、檔名 stem、拍攝時間、相機、尺寸與預覽產生方式。不同資料夾可能有相同檔名，所以不能只靠 basename 配對；缺漏或衝突項目標為 `未分類`，不繼承其他 JPG 的調色結論。

一般相機 JPG 可以先判斷構圖、對焦與表情；最終曝光、白平衡、色彩與 preset 方向必須用 Lightroom／Camera Raw 的 RAW render 判斷。

### 2. 三組狀態分開記錄

| 欄位 | 可用值 | 用途 |
|---|---|---|
| `selection_status` | `交付候選`、`保留`、`淘汰`、`待確認` | 構圖、焦點、表情與交付價值 |
| `edit_status` | `RAW 待檢`、`輕微全域調整`、`需局部調整`、`未知` | 後製工作量 |
| `style_status` | `已分類`、`未分類` | 是否已找到可靠的色調方向 |
| `confidence` | `high`、`medium`、`low` | 判斷可信度 |

不要自行把這些狀態映射成 Lightroom 星等或色標。若要映射，先由使用者明確定義，再把映射當成獨立欄位處理。

### 3. 按光線與用途分群

不要替整場活動硬套一個 preset。常見分群包括戶外陰影、室內暖／混合光、舞台光、逆光與高 ISO。每群先選一張代表 RAW，難處理的 outlier 保持獨立。

推薦的挑圖交付欄位：

```text
relative_raw_path, relative_preview_path, selection_status, edit_status,
style_status, lighting_cluster, confidence, notes
```

## 歷史色調迭代流程

1. 選一張不會破壞 master edit 的代表 RAW 或 virtual copy。
2. 讀取目前 metadata／Develop settings 與穩定 catalog ID/UUID、Master／Virtual Copy 關係，輸出一張 baseline JPEG。
3. 用 `get_develop_preset` 讀取已認可的歷史 preset；同名時用 UUID 或 folder／scope 消除歧義。
4. 每次只做一小段：技術校正、明暗形狀、色彩校正、創意風格、細節／降噪。
5. 每段都從 Lightroom 輸出新預覽並實際比較，不一次猜大量滑桿。
6. 用 `create_develop_preset` 建立唯一、版本化的 plugin checkpoint。
7. 用 `compare_develop_presets` 比較歷史版本與候選版本，保留設定差異紀錄。
8. 代表照片確認後，才用明確欄位清單把設定複製到同一光線群。
9. 用 `export_develop_preset` 匯出接受的 checkpoint；若目的檔已存在，工具會拒絕覆寫。
10. 在目標 Lightroom 版本匯入並檢查後，才能宣稱 preset 相容且視覺結果正確。

## MCP 工具

server 目前提供 20 個工具。完整清單與參數 schema 以 [`server/src/tool-contracts.ts`](server/src/tool-contracts.ts) 為準；下表列出本 fork v0.10.0 加入的 preset round-trip 工具：

| 工具 | 功能 |
|---|---|
| `get_develop_preset` | 讀取一個精確 preset 的 UUID、來源檔與完整可序列化設定 |
| `compare_develop_presets` | 產生 base／candidate 的逐設定差異 |
| `create_develop_preset` | 從代表照片選定欄位建立版本化 checkpoint |
| `export_develop_preset` | 複製 Lightroom preset backing file，永不覆寫既有檔案 |

既有的 `list_develop_presets` 與 `apply_develop_preset` 也支援 UUID、folder、scope；`set_develop_settings`、`copy_develop_settings` 與 checkpoint 建立支援主曲線及 RGB point-curve arrays。

Adobe SDK 建立的 plugin-managed checkpoint 不會出現在 Develop 面板。它仍可由 MCP 列出、套用與匯出；若需要面板內可見的正式 preset，請匯出後由 Lightroom UI 匯入，或在 Lightroom 內使用 Create Preset。

## Windows 安裝

### 1. 建置本 fork

```powershell
git clone https://github.com/John-owo/lightroom-mcp.git
Set-Location .\lightroom-mcp
Set-Location .\server
npm ci
npm run build
Set-Location ..
```

### 2. 安裝 Lightroom 外掛

```powershell
node .\server\dist\index.js install-plugin
```

完整關閉並重開 Lightroom Classic，再到「檔案 → 增效模組管理員 → Lightroom MCP」啟動 server。

### 3. 設定 Codex MCP

在 Codex 設定加入本機建置後的 `server/dist/index.js`；以下路徑請換成實際 clone 位置：

```toml
[mcp_servers.lightroom]
command = 'C:\Program Files\nodejs\node.exe'
args = ['D:\path\to\lightroom-mcp\server\dist\index.js']
startup_timeout_sec = 60
```

重新啟動 Codex，新的 task 才會載入 20 個工具。

### 4. 安裝 v2 skill

若已經有同名 skill，請先備份。接著在 repository 根目錄執行：

```powershell
$skillSource = Resolve-Path '.\skills\raw-photo-lightroom-preset'
$skillTarget = Join-Path $env:USERPROFILE '.codex\skills\raw-photo-lightroom-preset'
New-Item -ItemType Directory -Path $skillTarget -Force | Out-Null
Copy-Item -Path "$skillSource\*" -Destination $skillTarget -Recurse -Force
```

重新啟動 Codex 後，可使用：

```text
使用 $raw-photo-lightroom-preset 幫我挑這批 RAW，先分出交付候選與待確認，
再按光線分群。讀取我已認可的歷史 preset，只在代表照片上小步調整，
每輪輸出比較並建立不覆寫的版本化 checkpoint。
```

## 安全邊界

- 不移動、改名、刪除或覆寫原始照片。
- 不在未批准的 master edit 上測試。
- 不只看相機 JPG 就宣稱色彩或 preset 已完成。
- 不把 crop、白平衡、profile、鏡頭狀態或 detail 設定默默複製到整批。
- MCP 的 `create_virtual_copy` 只接受穩定 catalog ID、預期 Master UUID 與可重用的 operation ID，並以 identity readback 和 marker reconciliation 防止盲目重複建立；`reconcile_virtual_copy` 是只讀 recovery query，只掃描 exact marker、驗證 Master／Copy 關係，不改 selection 也不建立 Copy。兩者已有 contract、mock 與 transport integration 測試，但新的只讀 endpoint 尚未完成 Lightroom Classic 實機驗收。MCP 仍沒有 snapshot、undo 或完整局部工具；需要遮罩、修復、AI Denoise、Calibration、Color Grading 或 Point Color 時，交回 Lightroom 手動完成。
- MCP checkpoint 的 backing format 由 Lightroom 決定；內建 preset 若沒有 backing file，不能匯出。

## 已驗證範圍

- TypeScript：15 suites、175 tests 通過；type check、lint 與 build 也通過。
- Lua `HandlerDevelop`：28 個行為測試通過；Selene 0 errors／0 warnings／0 parse errors。
- Lightroom Classic 實機：建立 checkpoint、精確讀回、匯出 `.lrtemplate`、重複匯出拒絕且原檔 hash 不變，共 5／5 通過。
- XMP fallback generator：14 tests 通過，並具備副檔名、sidecar、覆寫、原子寫入、schema 與範圍保護。

實機測試沒有透過 Lightroom UI 再匯入匯出的 `.lrtemplate`，因此不把「目標 Lightroom 匯入相容」或「視覺風格正確」列為已通過；這兩項必須用實際照片與使用者確認。

## 進一步文件

- [v2 skill 主流程](skills/raw-photo-lightroom-preset/SKILL.md)
- [挑圖、分群與五階段調色](skills/raw-photo-lightroom-preset/references/workflow.md)
- [風格庫](skills/raw-photo-lightroom-preset/references/style-library.md)
- [Lightroom MCP 邊界與 closed loop](skills/raw-photo-lightroom-preset/references/lightroom-mcp.md)
- [英文 README](README.en.md)

授權沿用 repository 的 [MIT License](LICENSE)。
