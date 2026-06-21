# 停車場控制面板

一款用於遠端管理多個停車場設備的 Flutter 行動應用程式。操作人員可透過單一介面控制入口柵欄機、重啟 IoT 周邊設備，以及管理繳費機。

## 功能

- **多站點支援** — 從中央 PostgreSQL 資料庫動態載入站點與設備清單
- **閘門控制** — 開關柵欄機，並可重啟 LPR 攝影機、MCU 連接的周邊設備（密碼機、刷卡機、LED）及現場電腦
- **繳費機（APM）管理** — 透過 SSH 遠端重啟服務或重開機
- **緊急模式** — 透過 AT 指令切換 MCU 裝置的緊急狀態
- **鍵盤密碼管理** — 透過 TCP 查詢與更新密碼機密碼
- **二次確認機制** — 所有高風險操作均需再次確認才會執行

## 技術架構

| | |
|---|---|
| 框架 | Flutter（Dart） |
| 資料庫 | PostgreSQL（`postgres` 套件） |
| 遠端控制 | SSH（`dartssh2`）、HTTP、TCP Socket |
| UI 設計 | Material Design 3 |
| 目標平台 | iOS、Android |

## 架構說明

應用程式採三層式資料流：

```
PostgreSQL 資料庫
    │
    ├── site_list        → 填充站點選單
    └── config.device    → 填充閘門 / 繳費機選單
                              │
                    裝置設定（JSON 格式）
                              │
              ┌───────────────┼───────────────┐
           HTTP              TCP             SSH
        （柵欄機、        （MCU /          （繳費機）
           LPR）           周邊設備）
```

所有應用程式狀態由單一 `StatefulWidget` 管理。設備 metadata 以顯示名稱為 key 儲存於 lookup map（`_gateLookup`、`_apmLookup`），並從資料庫回傳的巢狀 JSON `configs` 欄位解析而來。

## 開始使用

### 環境需求

- Flutter SDK ≥ 3.8.1
- 可存取 PostgreSQL 資料庫及設備所在網路

### 執行

```bash
flutter pub get
flutter run
```

### 建置

```bash
flutter build ios
flutter build apk
```
