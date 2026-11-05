# PackerMOD Base

Minetest Gameを土台にした、PackerMOD用の独立ゲーム。ゲームの実体は
`games/packerbase`、初期独自バージョンは `0.1.0`、ゲームIDは `packerbase`。
VoxeLibreを土台とする以前の案は採用しない。

## 構成と境界

| 層 | 役割 | 配置 |
|---|---|---|
| PackerMOD | 起動メニュー、Pack・ゲーム・ワールド・MOD管理 | `mainmenu/` |
| PackerMOD Base | 操作・ゲームルール・拡張API・保存形式 | `games/packerbase/` |
| Luanti | 描画、入力、通信、ワールド基盤 | 別途インストールするエンジン |

利用者には一体として導入できる形にし、コード上はこの境界を維持する。
Java版の既存MODバイナリとの互換性は対象に含めず、Luanti用MODの拡張性を育てる。

## 上流の固定と互換性

Minetest Gameの特定コミットを取り込み、ゲーム内の上流記録を基準に管理する。
既存のMOD名・アイテム名を保持し、独自の基盤MOD `packer_core` を追加する。
上流更新は差分を確認して手動で取り込み、ゲーム版とエンジン版を分けて記録する。

現在の `packerbase` は開発用の安定したID。既存ワールドを新しいゲームIDへ
自動変更しない。複数ゲーム版の併存・Packごとの厳密なゲーム版固定は、既存の
ContentDBリリース管理と整合させる追加課題であり、このIDだけでは実現しない。

## 導入と選択

Windowsでは `scripts/deploy_local.ps1` を使用し、バックアップ・保護対象確認・
配置ハッシュ確認を行う。ゲームはLuantiユーザーデータの `games/packerbase` に配置する。
メニューの新規Pack作成からインストール済みゲームとして選択する。
既存Pack・ワールドは新しいゲームへ自動移行しない。

インストール済みゲーム指定のmanifest例:

```yaml
base_game:
  id: packerbase
  installed_id: packerbase
  title: PackerMOD Base
  version: installed
```

`version: installed` は版固定ではなく、現在配置されたゲームを使う指定。
同じIDの更新はそのIDを使うPackすべてに影響するため、正式配布前に版管理を整備する。

## ライセンス

ゲームコードはMinetest GameのLGPL-2.1-or-laterを維持する。
素材は各MODの通知を優先し、CC BY-SA、CC BY、CC0等を一括で再許諾しない。
独自メニューとゲームの同梱によって、第三者素材の条件が消えることはない。
詳細は [ライセンス確認記録](license-audit.md) とゲーム内の通知を参照。

開発項目・完了条件は [作業リスト](development-roadmap.md) に記録する。
