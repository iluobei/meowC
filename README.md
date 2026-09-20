# MeowX（Android / Windows）

MeowX 的 Android 与 Windows 客户端，基于 [Bettbox](https://github.com/appshubcc/Bettbox)（Flutter + [mihomo](https://github.com/MetaCubeX/mihomo) 内核）修改。界面复刻 MeowX iOS / iPad 版：手机端底部五个 Tab（首页 / 代理 / 连接 / 配置 / 设置），宽屏（Windows、平板横屏）左侧图标栏 + 两栏内容；Bettbox 的原有功能全部保留在「设置 → 高级」。

- 许可证：GPL-3.0（见 `LICENSE`、`NOTICE.md`、`CHANGES-FROM-BETTBOX.md`）
- 下载：[Releases](https://github.com/iluobei/meowC/releases)；开发中的构建在 [Actions](https://github.com/iluobei/meowC/actions/workflows/build.yaml) 的 artifacts 里
- 支持：Android 8.0+（arm64 / universal）、Windows 10+（x64）

## 使用

1. **导入订阅**：「配置」页粘贴订阅链接 → 导入订阅；或「账号登录」/ 手机「扫码登录」妙妙屋X 主控后，在「我的订阅」里点一条即下载并切换。也支持 `clash://install-config?url=…` 与 `miaomiaowu://login?host=…&code=…` 深链。
2. **连接**：首页电源键。Android 走 VPN（TUN），Windows 默认系统代理（TUN 需管理员，沿用 Bettbox 的 helper 服务流程）。
3. **代理**：代理页组卡默认收起，点名字展开、点闪电测速；「设置 → 测速方式」可切 HTTPS 延迟 / 真连接延迟 / TCPing。
4. **设置**：DNS 模式（跟随订阅 / Redir-Host / Fake-IP）、阻止 QUIC、DNS 劫持、绕过代理、本地代理端口与凭据、订阅同步间隔、日志开关、主题。

Windows 安装包未做代码签名，SmartScreen 提示时选「更多信息 → 仍要运行」。

## 构建

全部在 GitHub Actions 里构建（Flutter 3.44.9 / Go 1.25 / NDK 28.2 / Rust stable）：

- `ci.yaml`：push / PR 时 `flutter analyze` + `flutter test`（`lib/meowx/` 与 `test/meowx/` 以 `--fatal-warnings` 收紧）
- `build.yaml`：打 `v*` tag 自动出包并发布；Actions 页面也可手动触发（`gh workflow run build.yaml -f platform=all -f android_arch=arm64`）

本地构建与 Bettbox 相同：`flutter pub get` → `dart run build_runner build -d` → `dart setup.dart <android|windows> --arch <arm64|amd64>`（Android 需要 `ANDROID_NDK`；Windows 只能在 Windows 上构建，需要 Visual Studio、Inno Setup 6）。Go 核心可单独验证：`cd core && CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -tags with_gvisor .`。

## 目录

- `lib/meowx/` — MeowX 壳、页面、主题、面板协议（新增）
  - `app/` 壳与 Tab；`theme/` 颜色 token 与组件；`pages/` 五页；`state/` 设置 / 格式化 / 覆写校验；`config/` 对 mihomo 配置的补丁；`panel/` 妙妙屋X 主控（证书验签、加密 RPC、实时通道）
- `design/brand/` + `scripts/make-brand-assets.py` — 品牌源图与图标生成
- 其余目录 — Bettbox 原有代码（引擎、平台层、高级页面），改动清单见 `CHANGES-FROM-BETTBOX.md`
