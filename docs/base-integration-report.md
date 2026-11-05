# PackerMOD Base統合の検証記録

2026-11-05 / Windows Luanti 5.16.1・WSL Ubuntu上のLuanti 5.16.1。
ゲーム0.1.0、API major 1。上流の固定コミットはゲーム内 `UPSTREAM.md` を参照。

## 実行結果

| 検証 | 結果 |
|---|---|
| `wsl -d Ubuntu --cd <repo> -- busted spec/` | 347成功、失敗・エラー・保留0 |
| `bash spec/e2e/run.sh` | 隔離ユーザーデータで実メニュー起動成功 |
| `bash scripts/test_base_game.sh` | APIの移行失敗非上書き・将来版拒否・計測、地形・メタデータ・MOD保存2起動成功 |
| 同テストの `packerbase_example` | 基盤を書き換えずイベント・保存・計測APIを利用。起動回数1→2を確認 |
| `scripts/test_installation.ps1` / `bash scripts/test_installation.sh` | 隔離導入・更新・旧版backup・配置検証・既存データ保護・未管理ゲーム拒否・ゲーム内world拒否成功 |
| `scripts/visual_tests.ps1 -View library` / `-View modal_create_game` | WSL＋Xvfbでメニュー2画面撮影成功 |
| `bash scripts/test_base_game_visual.sh` | 実クライアントで36 inventory・9 hotbarをassertし撮影成功 |
| `scripts/deploy_local.ps1` | 実Windowsユーザーデータに配置、全配置ハッシュと設定一致、保護データのハッシュ一致 |
| `scripts/windows_game_test.ps1 -GameId packerbase` | Pack作成・追加MOD・日本語world・プレイヤー36/9枠・API readyと保存・2起動・一時リンク復旧成功 |
| `scripts/windows_game_test.ps1 -GameId minetest` | 従来Minetest GameでもPack作成・2起動成功 |
| 同スクリプト `-GameId packerbase -StarterZip <starter.zip>` | ZIP Importと同梱サンプルMODの起動回数1→2、保存・2起動成功 |
| 実ユーザープロファイルでWindows Luanti再起動 | `PackerMOD: menu ready` を確認 |

実ユーザーデータは `%APPDATA%\Minetest`。
`main_menu_script` は同ディレクトリの `PackerMOD\mainmenu\init.lua`。
最終実配置backup: `PackerMOD\install-backups\20261105-165230-637`。
Windows検証ログ: `.screenshots/windows-game-20261105-165254-676.log`。
starter ZIP検証ログ: `.screenshots/windows-game-20261105-165554-358.log`。
実プロファイル起動ログ: `.screenshots/windows-installed-startup.log`。
実ユーザーのPack・ワールド・キャッシュには追加・移行を行わず、動作検証は一時profileで実施。

## 画面レビュー

design-reviewサブエージェントが画像を確認し、Pillowで直接ピクセル測定した。
`measure_ui.py` はnumpy未導入で利用不可だったため、同依存は追加していない。

- Base inventory: 9列×4行、36枠、枠内側53×53px。左右余白18px、下余白34px。
  全番号1〜36、HUD9枠を表示し、重なり・欠落・画面外クリップなし。
- Pack一覧: カード幅306px、間隔27px、操作ボタンの文字中心ずれ最大1px。
- ゲーム選択: 下部ボタン間隔14px以上、文字欠けなし。
  既存の「次へ：MOD選択」の字形中心ずれ右4pxは軽微な既存所見。

画像: `.screenshots/packerbase_inventory.png`、`library_1280x800.png`、`modal_create_game_1280x800.png`。

## 利用と配布

新規Pack作成で「PackerMOD Base」を選ぶ。
`scripts/build_release.ps1 -OutputDirectory dist/final` でエンジン非同梱のソースZIPと
starter ZIPを生成し、内外のSHA256SUMSで内容を検証できる。
starter ZIPには `manifest.yaml` とサンプルMODを同梱する。
YAML単体のImportでは同梱MODはコピーされないため、starterはZIPでImportする。

新規worldの `mod_storage_backend = sqlite3` は公式の
[database backends](https://docs.luanti.org/for-server-hosts/database-backends/)に基づく。
既存worldのbackendは変更しない。

## 制約

- Java版の加減速・ジャンプ・スプリント・戦闘・採掘等の一致は未検証・未実装。
- 箱・炉・bones画面のplayer欄は上流32枠表示を保持。追加4枠は個人inventoryで操作可能。
- `installed_id: packerbase` は厳密な版固定ではない。同じIDの更新は利用する全Packに影響する。
- 任意の計測基盤を追加した段階であり、FPSや処理時間の性能向上を実証したものではない。
- Luantiエンジンのバイナリは今回配布に含めない。
- 更新途中の全コンポーネント自動rollbackはなく、失敗時は保存したbackupから復元する。
