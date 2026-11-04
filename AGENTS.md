# PackerMOD の作業指示

- PackerMODを修正したら、テストと画面確認に加えて、このPCにインストールされているWindows版Luantiにも修正版を反映する。リポジトリの変更だけで完了にしない。
- 反映にはバックアップ・保護対象確認・配置ハッシュ検証を行う `scripts/deploy_local.ps1`（内部で `install/install.ps1 -Mode copy` を実行）を使用し、実際に使われているLuantiユーザーデータと `main_menu_script` を確認する。更新前のメニュー・テクスチャ・設定をバックアップし、Pack・ワールド・キャッシュは保持する。
- Windows版Luantiが起動中なら、変更を保存せずに強制終了しない。反映後は配置ファイルと設定を検証し、可能な場合はWindows版の起動も確認する。
- 見た目の通常確認には `scripts/visual_tests.ps1` によるWSL＋Xvfbの自動撮影を使う。
