/// MeowX 壳的全部中文文案（与 iOS 端逐字一致；不走 intl 管线）。
class S {
  S._();

  // Tab
  static const home = '首页';
  static const proxies = '代理';
  static const connections = '连接';
  static const profiles = '配置';
  static const settings = '设置';

  // 首页
  static const upload = '上传';
  static const download = '下载';
  static const session = '会话';
  static const proxyConnections = '代理连接';
  static const viaNodeGroup = '经节点 / 代理组';
  static const directConnections = '直连连接';
  static const directBypass = 'DIRECT / 绕过代理';
  static const memory = '内存';
  static const coreMemory = '核心内存';
  static const dnsMode = 'DNS 模式';
  static const dnsFollow = '跟随订阅 · 点按切换';
  static const dnsFakeIp = 'Fake-IP';
  static const dnsRedirHost = 'Redir-Host';
  static const connected = '已连接';
  static const connecting = '连接中';
  static const disconnected = '未连接';
  static const running = '已运行';
  static const ready = '已就绪';
  static const notConfigured = '未配置';
  static const modeRule = '规则';
  static const modeDirect = '直连';
  static const modeGlobal = '全局';
  static const peak = '峰值';
  static const samplingPerSecond = '每秒采样';
  static const exitIp = '出口 IP';
  static const domesticDirect = '国内 · 直连出口';
  static const globalVia = '国际 · 经';
  static const querying = '查询中…';
  static const noSubscription = '还没有订阅';
  static const used = '已用';
  static const total = '总量';
  static const unlimited = '无限';

  // 代理页
  static String groupsAndNodes(int groups, int nodes) => '$groups 个代理组 · $nodes 个节点';
  static const testAll = '全部测速';
  static const testGroup = '测速本组';
  static const currentSelected = '当前选中';
  static const chooseGroup = '选择一个代理组';
  static const noConfig = '还没有配置';
  static const goImport = '去「配置」页导入订阅';
  static const cardCompact = '紧凑';
  static const cardStandard = '标准';
  static const cardLarge = '大';
  static const nodeView = '节点视图';
  static const layout = '布局';
  static const cardSize = '卡片尺寸';
  static const timeout = '超时';
  static const builtinDirect = '直连';
  static const builtinReject = '拒绝';
  static const builtinPass = '穿透';
  static const builtinGlobal = '全局';
  static const nestedGroup = '代理组';

  // 设置
  static const advanced = '高级';
  static const advancedDesc = 'Bettbox 提供的完整设置与工具';
  static const appearance = '外观';
  static const theme = '主题';
  static const themeSystem = '跟随系统';
  static const themeLight = '亮色';
  static const themeDark = '暗色';
  static const about = '关于';
  static const version = '版本';
  static const coreVersion = '核心版本';
  static const openSourceLicense = '开源许可';

  // 通用
  static const tunnelNotConnected = '隧道未连接';
}
