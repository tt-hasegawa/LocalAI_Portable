# スタンドアロン閉域環境向け LocalAI Portable (VS Code Web + Continue + llama-server)

インターネット接続のない完全閉域網（オフライン環境）の社内開発サーバー（Windows Server 2016 / 2019 / 2022）で、GPU不要（CPU実行）で即座にAI支援開発を行うための自己完結型ポータブルパッケージです。

---

## 1. 特徴

- **Webブラウザのみで作業可能**: サーバー側で `code serve-web` をバックグラウンド実行し、自席PCや社内端末のブラウザから `http://<サーバーIP>:8000` で直接VS Codeを利用可能。
- **GPU不要・CPU最適化**: `llama.cpp` の AVX2 ビルドと `Qwen2.5-Coder-7B-Instruct-Q4_K_M`（約4.68GB）を組み合わせ、CPUのみのサーバーでも高速にコード生成・補完を実行。
- **完全自己完結型**: レジストリを汚さず、相対パス＆専用プロファイルで動作するため、フォルダごとコピー・移動するだけで動作。
- **AI実行用Python環境を内包（Excel/CSV/DB/ソース操作）**: AI（Qwen-Coder）が直接触れないファイルやDBを操作する「手足」として、ポータブルPython 3.11を同梱。Excel（.xlsx/.xls）、CSV（Shift_JIS自動判別）、Oracle（Instant Client不要のThinモード）、PostgreSQL（libpq内包）に即使えるライブラリがセットアップ済み。
- **ワンクリック起動・停止**: `start.bat` で llama-server と VS Code Web を連動起動、`stop.bat` で安全に一括停止。

---

## 2. フォルダ構成

```text
LocalAI_Portable/
│
├── start.bat                   # 起動バッチ（llama-server 起動 -> VS Code Web 起動）
├── stop.bat                    # 停止バッチ（各プロセスを安全に終了）
├── register_autostart.bat      # [管理者用] OS起動時の自動起動（常駐）登録バッチ
├── unregister_autostart.bat    # [管理者用] 自動起動登録の解除バッチ
├── config.env.bat              # 環境設定（ポート番号、HTTPS設定、モデル指定等）
├── install_extensions.bat      # VSIXオフライン一括インストールバッチ
├── download_assets.ps1         # [オンライン用] 資材一括ダウンロード＆自動セットアップ
├── download_assets_legacy.ps1  # [Win2016用] WinPTY対応レガシーVS Code(v1.108)一括ダウンロード
├── README.md                   # 本マニュアル
│
├── client_setup/               # クライアントPC向け簡単設定ツール一式
│   ├── enable_trusted_site.bat # [一般ユーザーOK] 信頼済みサイト1クリック登録バッチ
│   ├── install_server_cert.bat # 自己署名SSL証明書の1クリック信頼バッチ
│   └── README_client.txt       # クライアント配布用テキスト手順書
│
├── cert/                       # SSL証明書格納場所（server.pfx, LocalAI_Server.cer 等）
├── tools/                      # 内部ツール（https_proxy.js, generate_cert.ps1, setup_python.ps1 等）
│   └── scripts/                # AI・自動化用サンプルスクリプト（Excel/CSV, Oracle Thin, Postgres, Code）
├── bin/
│   ├── llama/                  # llama-server.exe 等のバイナリ一式
│   ├── vscode/                 # VS Code ポータブル版（code.cmd 等）
│   └── python/                 # ポータブルPython 3.11（Excel/CSV/DB/Code操作ライブラリ導入済）
│
├── data/                       # ポータブルデータ（全状態・設定をここに集約）
│   ├── profile/
│   │   └── .continue/          # Continue の設定（config.yaml, config.json）
│   ├── user-data/
│   │   └── User/settings.json  # VS Code オフライン・テレメトリ無効設定
│   └── extensions/             # インストール済み拡張機能
│
├── extensions_installer/       # オフラインインストール用 VSIX 格納場所
├── models/                     # GGUF モデル格納場所（1.5B, 3B 等）
└── logs/                       # 実行ログ
```

---

## 3. 作成・移行手順

### ステップ 1: オンライン環境での資材準備（インターネット接続PC）

1. この `LocalAI_Portable` フォルダをインターネット接続のある作業PCに配置します。
2. PowerShell を管理者（または通常権限）で開き、以下のスクリプトを実行します:
   ```powershell
   cd LocalAI_Portable
   # 通常環境（Windows Server 2019/2022、Windows 10/11 等）:
   powershell -ExecutionPolicy Bypass -File .\download_assets.ps1

   # Windows Server 2016 環境（WinPTY対応レガシー VS Code v1.108 を使用する場合）:
   # ※VS Code v1.109以降はConPTY必須となりServer 2016でターミナルが起動しないため
   powershell -ExecutionPolicy Bypass -File .\download_assets_legacy.ps1
   ```
   *スクリプトが以下の作業を自動で行います:*
   - VS Code ポータブル版 zip のダウンロードと `bin\vscode` への展開
   - llama.cpp (AVX2 CPU版) のダウンロードと `bin\llama` への展開
   - Continue 拡張機能 (`continue.vsix`) と 日本語パックの取得
   - `Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf` (約4.68GB) のダウンロード
   - 拡張機能のポータブル環境への事前インストール (`install_extensions.bat` 自動実行)
   - ポータブルPython環境の構築と主要ライブラリ（openpyxl, pandas, oracledb, psycopg2-binary, sqlalchemy等）の事前導入 (`tools\setup_python.ps1` 自動実行)

> [!NOTE]
> 手動でダウンロードする場合は、各資材を上記のフォルダ構成図に合わせて配置してください。

### ステップ 2: アーカイブ化と閉域サーバーへの持ち込み

1. `LocalAI_Portable` フォルダ全体を zip または 7z 形式で圧縮します。
   *(モデルファイルを含めると圧縮後で約 5〜6 GB 程度になります)*
2. 社内のセキュリティ規定（USBメモリ、共有ファイルサーバ、CD-R搬入等）に従って、閉域の社内開発サーバーへ持ち込みます。
3. サーバー上の任意のドライブ・フォルダ（例: `D:\LocalAI_Portable`）に展開します。

---

## 4. 起動と利用方法（閉域サーバー上）

### 起動方法
1. 閉域サーバー上で `start.bat` をダブルクリック（またはコマンドプロンプトから実行）します。
2. 以下の順序で自動起動します:
   - `llama-server` が最小化ウィンドウで起動し、Qwen2.5-Coder モデルのロードを開始。
   - ポート 58080 の疎通（モデルロード完了）を自動ポーリングで待機。
   - モデル準備完了後、VS Code Web (`code serve-web`) が自動起動。
   - コンソール画面に、アクセス用URL（例: `http://192.168.x.x:8000/`）が表示されます。

### クライアント端末からのアクセス
1. 自席のPCや開発端末のブラウザ（Google Chrome、Microsoft Edge 等）を開きます。
2. `start.bat` に表示されたURL（例: `http://<社内サーバーIP>:8000/`）にアクセスします。
   - **特定のプロジェクトフォルダを直接開きたい場合**:
     URL末尾に `?folder=<サーバー上の絶対パス>` を付与してアクセスできます。
     ```text
     http://<社内サーバーIP>:8000/?folder=C:/source/my_project
     ```
     *(※パスの区切り文字はスラッシュ `/` を推奨)*
   - **ワークスペースファイルを開く場合**:
     ```text
     http://<社内サーバーIP>:8000/?workspace=C:/source/my_project.code-workspace
     ```
3. ブラウザ上に VS Code が表示され、左側サイドバーに **Continue** アイコン（または `Ctrl+L`）が表示されます。
4. チャット欄で質問やコード生成を依頼すると、サーバー上の `llama-server` を経由して即座に回答が得られます。

### コマンドライン引数でのフォルダ指定（任意）
`start.bat` に直接フォルダパスを渡して起動することも可能です：
```cmd
start.bat C:\source\my_project
```
または `config.env.bat` の `DEFAULT_FOLDER` にパスを設定しておくと、URLパラメータなしでアクセスした際も自動的にそのフォルダが開きます。

### 停止方法
- サーバー上で `stop.bat` を実行するか、`start.bat` のコンソールで `Ctrl+C` を押してください。
- 関連プロセス（`llama-server.exe` および VS Code Web プロセス）が安全に終了します。

---

## 5. 設定のカスタマイズ (`config.env.bat`)

必要に応じて、メモ帳等で `config.env.bat` を編集してパラメータを調整できます。

| パラメータ | 初期値 | 説明 |
| :--- | :--- | :--- |
| `VSCODE_PORT` | `8000` | Webアクセス用のポート番号（HTTP直接アクセス用） |
| `ENABLE_HTTPS` | `0` | 内蔵 HTTPS リバースプロキシの有効化（`1` で有効、`0` で無効） |
| `HTTPS_PORT` | `8443` | HTTPS アクセス用ポート（SSL有効時の接続先） |
| `LLAMA_PORT` | `58080` | llama-server 内部APIポート（競合防止のため動的ポート範囲 58080 を使用） |
| `CPU_THREADS` | `0` (自動) | 推論に使用するCPUコア数。`0` の場合はサーバーの物理コア数を自動判別 |
| `CTX_SIZE` | `16384` | コンテキスト長（トークン数）。初期値 `16384`（約40〜50KBのコード読込可能）。RAM節約時は `8192` や `4096` に設定 |
| `MODEL_NAME` | `Qwen2.5-Coder-3B-...` | `models` フォルダ内の使用するモデルファイル名（1.5B も選択可能） |
| `DEFAULT_FOLDER` | (空欄) | 起動時にデフォルトで開く作業ディレクトリ（例: `C:\source`） |

> [!NOTE]
> `config.env.bat` で `LLAMA_PORT` や `CTX_SIZE` を変更した場合、次回 `start.bat` 実行時に Continue 側の設定ファイル（`config.yaml`）へ自動的に同期反映されます。個別に編集する必要はありません。

---

## 6. 推奨モデル一覧とスペック別選び方

サーバーの搭載RAMやCPUスペックに応じて、最適なモデルサイズを選択できます。
モデルファイルを `models/` フォルダに配置し、`config.env.bat` の `MODEL_NAME` を書き換えるだけで即座に切り替え可能です。

| モデル名 | パラメータ | GGUFファイル名 / サイズ | 推論時RAM目安<br>*(4K文脈含む)* | 特徴・CPU速度感 |
| :--- | :---: | :---: | :---: | :--- |
| **Qwen2.5-Coder-3B**<br>⭐ **本パッケージ標準** | 30億 | `Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf`<br>(約 1.96 GB) | **約 2.5 〜 3.5 GB** | **省メモリと実用精度の最良バランス**。CPUでの回答生成が7Bの約1.5〜2倍高速。日本語のコード解説・生成も高品質 |
| **Qwen2.5-Coder-1.5B**<br>🚀 **超軽量・極限環境用** | 15億 | `Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf`<br>(約 1.04 GB) | **約 1.5 〜 2.0 GB** | **最軽量**。RAM 4GB〜8GBの仮想サーバーでも余裕で動作。単純なスクリプト生成や関数補完に向く |
| **Qwen2.5-Coder-7B**<br>🧠 **高精度（余裕がある場合）** | 70億 | `Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf`<br>(約 4.68 GB) | **約 6.0 〜 7.5 GB** | 最も賢く複雑なロジックに対応可能だが、CPU負荷とメモリ消費が大きいため、RAM 16GB以上推奨 |

### 各モデルのダウンロード先（オンライン環境）
- **3B (標準)**:
  `https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf`
- **1.5B**:
  `https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf`
- **7B**:
  `https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf`

---

## 7. よくある質問・トラブルシューティング

### Q1. クライアントPCのブラウザからアクセスできない（接続エラー）
- **ファイアウォール設定**: Windows Server側の Windows Defender ファイアウォールで、ポート `8000`（または設定した `VSCODE_PORT`）の受信規則（Inbound Rule）を許可してください。
  ```cmd
  netsh advfirewall firewall add rule name="VSCodeWeb" dir=in action=allow protocol=TCP localport=8000
  ```

### Q2. CPU使用率が高く、サーバーが重くなる
- `config.env.bat` の `CPU_THREADS` をサーバーの物理コア数より少ない値（例: 全体8コアなら `4` など）に設定することで、他の業務プロセスへの影響を抑えられます。

### Q3. Windows Server 2016 で起動時に curl のエラーが出るか？
- 本パッケージの `start.bat` は Windows Server 2016 互換のため、`curl` に依存せず PowerShell ソケット接続によりヘルスチェックを行うよう設計されています。安心してお使いいただけます。

---

## 8. サーバー常駐化・OS起動時の自動起動（サービス化）

サーバー再起動時に手動でログインして `start.bat` を叩かなくても、**OS起動と同時にバックグラウンドで自動起動・常駐** させることができます。

### 自動起動の登録（推奨・最も手軽）

追加ツールの導入やダウンロードは一切不要です（Windows標準のタスクスケジューラ機能を使用）。

1. `register_autostart.bat` を右クリックし、**「管理者として実行」** を選択します。
2. Windows のタスクスケジューラに `LocalAI_Portable` タスクが登録されます。
   - **トリガー**: システム起動時（ブート時）
   - **実行権限**: `SYSTEM` アカウント（ログイン不要で動作、無期限実行）
   - **画面表示**: セッション0（完全バックグラウンド）で起動するため、黒いコマンド画面は表示されず静かに常駐します。
3. 登録完了後、そのまま即座に起動するか確認されるので、`Y` を押すとバックグラウンドで即時開始されます。

### 自動起動の解除
- `unregister_autostart.bat` を右クリックして **「管理者として実行」** すると、自動起動タスクの登録が解除され、実行中のプロセスも停止します。

### 管理と手動制御
- 通常のタスクスケジューラ GUI（`taskschd.msc`）の「タスク スケジューラ ライブラリ」にも `LocalAI_Portable` として登録されているため、右クリックから「実行」「終了」「無効化」などの管理も可能です。
- 一時的に停止したい場合は通常通り `stop.bat` を実行してください。

> [!NOTE]
> **Windows サービス（`services.msc`）への登録について**
> 社内監査規定などで「タスクスケジューラではなく、どうしても `services.msc` のサービス一覧に登録したい」という場合は、Windows サービス専用ラッパー（`WinSW-x64.exe`）を `bin/` に配置することで対応可能です。通常の利用目的であれば、OS標準機能のみで完結する本自動起動スクリプト（タスクスケジューラ方式）を強く推奨します。

---

## 9. クライアントPCのブラウザ設定・SSL（HTTPS）起動ガイド

VS Code Web 上で Continue 拡張機能のチャット画面を動かすには、ブラウザのセキュリティ仕様（W3C Secure Contexts）により、アクセス元が「安全なコンテキスト（HTTPS または localhost）」と認識されている必要があります。

本パッケージでは、運用環境に合わせて **2つの解決策** を用意しています。

### 【方法 1】クライアント側 1クリック登録バッチ（一番手軽・今すぐ全員使える）★推奨

各利用者が `chrome://flags` を開いて手入力する代わりに、ワンクリックで登録できるバッチファイルを配布できます。

1. `client_setup` フォルダを社内共有フォルダに配置するか、利用者に配布します。
2. 利用者は自席PCで `client_setup\enable_trusted_site.bat` をダブルクリックします（**管理者権限不要**）。
3. サーバーのURL（例: `http://omecvsv01386:8000`）を入力してEnterキーを押します。
4. Chrome および Edge のポリシーレジストリ（`HKCU`）に自動登録され、ブラウザ再起動後は常に安全なサイトとして認識されます。

### 【方法 2】サーバー側で SSL（HTTPS）起動する（完全な HTTPS 化）

通信自体を HTTPS（暗号化）にし、ポート `8443` で待ち受ける機能です。同梱されている `node.exe` による内蔵リバースプロキシが動作するため、追加ソフトのダウンロードは不要です。

1. `config.env.bat` を開き、`ENABLE_HTTPS=1` に設定します。
2. `start.bat` を実行します。
   - `cert\server.pfx` が存在しない場合、PowerShell が自動的に 5 年有効な自己署名 SSL 証明書を生成します。
   - HTTPS プロキシがポート `8443` で起動し、VS Code Web に接続を中継します。
3. **ブラウザでのアクセス**:
   - `https://<サーバー名>:8443/` にアクセスします。
   - **自己署名証明書の場合**: 初回はブラウザの赤い警告が出ます。公開証明書 `cert\LocalAI_Server.cer` をクライアントPCに配布し、`client_setup\install_server_cert.bat` を管理者実行して「信頼されたルート証明機関」に登録すれば、警告が消えて緑の鍵マークになります。
   - **社内CA発行の証明書がある場合**: 会社の公式証明書（`server.crt` + `server.key`、または `server.pfx`）を `cert\` フォルダに配置するだけで、全社内PCから警告なしで即座にアクセスできます。

---

## 10. AI実行用ポータブルPython環境（手足としてのスクリプト実行）

AI（Qwen-Coder）はLLMであるため、ファイルシステムやデータベースを直接操作できません。
そこで、**AIにPythonスクリプトを生成させ、サーバー上のポータブルPythonで実行させることで「手足」として機能** させます。

本パッケージには、閉域環境のサーバー上にPythonやDBドライバが存在しなくても動作するよう、**自己完結型のポータブルPython 3.11** と主要ライブラリ群（約230MB）が `bin/python` に標準バンドルされています。

### 同梱ライブラリ一覧

| 対象カテゴリ | 導入済みライブラリ | 特徴・メリット |
| :--- | :--- | :--- |
| **Excel 操作** | `openpyxl`, `pandas`, `xlrd`, `xlsxwriter` | `.xlsx`（書式・数式対応）およびレガシーな `.xls` の読み込み、高速出力に対応。 |
| **CSV / テキスト** | `pandas`, `chardet`, `charset-normalizer` | 日本の社内システム特有の **Shift_JIS (CP932)** と **UTF-8** を自動判別し、文字化けなく読み書き可能。 |
| **ソースコード処理** | `pygments`, `rich`, `re`, `pathlib`, `ast` | 複数言語（Java, C#, C++, SQL, JS等）のコード解析、シンタックス処理、コンソール整形表示。 |
| **Oracle Database** | `oracledb` | **Thinモード対応（重要）**。**Oracle Instant Client や Oracle Client のインストールが一切不要**！純粋なネットワーク通信だけで Oracle 12c〜23c に即座に接続可能。 |
| **PostgreSQL** | `psycopg2-binary` | PostgreSQL接続ドライバ。libpq等もバイナリ内包済みで、追加のDLL導入なしに即動作。 |
| **共通DB / ORM** | `sqlalchemy` | Oracle, PostgreSQL, SQLite 等を共通のSQL構文やORMで抽象化。`df.to_sql()` や `pd.read_sql()` でExcel/CSVとの相互変換が数行で完結。 |

### 使い方・AI（Continue）との連携

1. **Continue チャットでの指示**:
   - チャット欄でスラッシュコマンド `/script` を入力するか、通常プロンプトで「○○のExcelからデータを取り出してPostgreSQLに格納するPythonコードを書いて」と依頼します。
   - Continue側には本環境のライブラリ（`openpyxl`, `oracledb` Thinモード, `psycopg2` 等）を前提としたプロンプトテンプレートが事前登録されているため、環境に完全に合致したスクリプトが生成されます。

2. **ターミナルでの即座実行**:
   - `start.bat` 起動時に `bin/python` が環境変数 `PATH` に自動追加されるため、VS Code Web 下部のターミナルから以下のようにそのまま実行できます:
     ```bash
     python myscript.py
     ```

### 同梱サンプルスクリプト（`tools/scripts/`）

AIへのプロンプト指示の参考や、単体CLIツールとして活用できるベストプラクティス実装を同梱しています:

- `excel_csv_tool.py`:
  - Excel ⇄ CSV 相互変換、文字コード自動判別（CP932 / UTF-8）、先頭行プレビュー表示
  ```bash
  python tools/scripts/excel_csv_tool.py input.xlsx output.csv
  python tools/scripts/excel_csv_tool.py data.csv --preview
  ```
- `oracle_thin_query.py`:
  - **Oracle Client 不要** で Oracle DB に接続し、SQLクエリ結果を CSV や Excel にエクスポート
  ```bash
  python tools/scripts/oracle_thin_query.py --host 192.168.1.50 --service ORCLPDB1 --user scott --password tiger --sql "SELECT * FROM emp" --output emp.xlsx
  ```
- `postgres_query.py`:
  - PostgreSQL に接続し、SQLクエリ結果を CSV や Excel にエクスポート
  ```bash
  python tools/scripts/postgres_query.py --host 192.168.1.50 --dbname mydb --user postgres --password secret --sql "SELECT * FROM users" --output users.csv
  ```
- `code_search_replace.py`:
  - 複数言語のソースコードファイルを再帰探索し、文字コードを保持しながら一括検索・置換
  ```bash
  python tools/scripts/code_search_replace.py C:\source\myproject --search "oldApi()" --replace "newApi()" --ext .java .cs
  ```
