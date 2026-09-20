# MeowX（Android / Windows）

MeowX 的 Android 与 Windows 客户端，基于 [Bettbox](https://github.com/appshubcc/Bettbox)（Flutter + [mihomo](https://github.com/MetaCubeX/mihomo) 内核）修改。界面复刻 MeowX iOS / iPad 版；Bettbox 的原有功能保留在「设置 → 高级」里。

- 许可证：GPL-3.0（见 `LICENSE`、`NOTICE.md`、`CHANGES-FROM-BETTBOX.md`）
- 下载：[Releases](https://github.com/iluobei/meowC/releases)
- 支持：Android 8.0+（arm64 / universal）、Windows 10+（x64）

## 构建

全部在 GitHub Actions 里构建（Flutter 3.44.9 / Go 1.25 / NDK 28.2 / Rust stable）：

- `ci.yaml`：push / PR 时 `flutter analyze` + `flutter test`
- `build.yaml`：打 `v*` tag 自动出包并发布；Actions 页面也可手动触发只构建某一端

本地构建与 Bettbox 相同：`flutter pub get` → `dart run build_runner build -d` → `dart setup.dart <android|windows> --arch <arm64|amd64>`（Android 需要 `ANDROID_NDK`；Windows 只能在 Windows 上构建，需要 Visual Studio、Inno Setup 6）。

## 目录

- `lib/meowx/` — MeowX 壳、页面、主题、面板协议（新增）
- 其余目录 — Bettbox 原有代码（引擎、平台层、高级页面）
