# 体脂拍照记录（ScaleReader）

为 **欧姆龙 HBF-701 体脂秤**（无蓝牙/无 WiFi，只能看屏幕）做的一个 iOS 小工具：

1. 用相机拍下体脂秤循环显示的读数屏幕（可拍多张）；
2. 调用**云端多模态大模型（AI）**识别照片里的数字，自动提取四项数据；
3. 你在 App 里**核对/修改**后保存；
4. 记录进本地历史 + **写入苹果健康（HealthKit）**。

> 免越狱、免开发者账号：CI 云端构建出**未签名 IPA**，用 **TrollStore（巨魔）** 直接安装。
> 部署目标 iOS 16+（TrollStore 支持的 iOS 14–17 也能跑，App 用的是 iOS16 API）。

---

## 记录的指标与“健康”写入规则

| 屏幕读数 | 含义 | 是否写入苹果健康 | 说明 |
|---|---|---|---|
| 体重 | kg | ✅ 写入“体重”(bodyMass) | 直接写 |
| 体脂肪率 | % | ✅ 写入“体脂肪率”(bodyFatPercentage) | 直接写 |
| 骨骼肌率 | % | ⚠️ 换算后写入 | 健康没有“骨骼肌率”百分比类型，按 **骨骼肌(kg) = 体重 × 骨骼肌率 ÷ 100** 换算后写入“去脂体重 / Lean Body Mass” |
| 皮下脂肪率 | % | ❌ 仅本地 | 健康无此类型，保留在本 App 的历史/趋势里 |

- 每一项是否写入健康可在 **设置 → 写入苹果健康** 里单独开关（默认全开）。
- 换算结果在保存前的确认页会显示出来（“骨骼肌（换算） xx kg”）。
- 写入采用逐项独立写入：某项失败只报那项，不影响其余项和本地记录。

---

## 目录结构

```
├── .github/workflows/build-ipa.yml   # GitHub Actions 云构建（生成 IPA）
├── project.yml                        # XcodeGen 工程描述（CI 用它生成 .xcodeproj）
├── ScaleReader.entitlements           # HealthKit / ad-hoc 签名 entitlement
├── scripts/make_icon.py               # 生成 App 图标（1024 PNG，构建前运行）
├── ScaleReader/
│   ├── Assets.xcassets/               # 图标 & 强调色
│   ├── Models/ScaleReading.swift      # 数据模型（含骨骼肌换算）
│   ├── Store/RecordStore.swift        # 本地 JSON 持久化
│   ├── Store/AppSettings.swift        # 设置（API 参数 + 健康开关）
│   ├── Services/AIService.swift       # 多图视觉识别（OpenAI 兼容接口）
│   ├── Services/HealthService.swift   # HealthKit 写入
│   ├── Support/…                      # Keychain、图片压缩
│   └── Views/…                        # SwiftUI 界面
```

---

## 快速开始（你没有 Mac，用 GitHub 云构建）

1. **新建一个 GitHub 仓库**（公开即可，Actions 免费额度够用；注意别把隐私写进仓库）。
2. 把本项目所有文件上传到仓库 `main` 分支（可以直接把 `scale-reader` 文件夹里的内容推上去）。
3. 打开仓库 **Actions** 页面 → 左侧选中 **Build IPA** → 点 **Run workflow**。
4. 等 3–6 分钟跑完，在本次运行结果页底部 **Artifacts** 下载 `ScaleReader-ipa.zip`，解压得到 `ScaleReader.ipa`。
5. 把 `ScaleReader.ipa` 发到你的 iPhone（隔空投送/文件 App/任意网盘），用 **TrollStore 打开并安装**。

> 以后每次改代码推送到 `main` 也会自动触发构建。仓库里**不要提交** `ScaleReader.xcodeproj`、`Info.plist`、`AppIcon.png`（.gitignore 已排除，CI 会自动生成）。

---

## 首次使用：配置 AI 识别

识别必须有一个**云端多模态（vision）大模型**的 API Key，进 App **设置**页填写（只存本机钥匙串）。

内置三个服务商预设（点一下自动填好地址和模型）：

| 服务商 | 模型 | 说明 |
|---|---|---|
| **硅基流动 SiliconFlow**（默认） | `Qwen/Qwen2.5-VL-7B-Instruct` | 国内直连；去 siliconflow.cn 注册实名，送免费/低价额度，OpenAI 兼容 |
| **智谱 GLM-4V-Flash** | `glm-4v-flash` | 国内直连；open.bigmodel.cn 有免费档（有速率限制） |
| **OpenAI** | `gpt-4o-mini` | 需海外网络与绑卡 |

也可以填**任意 OpenAI 兼容**的接口（地址 + 模型名 + Key），App 会拼 `{BaseURL}/chat/completions` 调用。

**获取 Key 示例（硅基流动）**：注册 → 实名认证 → 左侧“API 密钥”新建密钥 → 把 `sk-…` 粘进 App。充值与否看免费额度，识别一次大约消耗几 KB~几十 KB token，非常便宜。

---

## 日常使用流程

1. 站上 HBF-701 完成测量，屏幕开始**循环显示**各项读数；
2. 在 App「拍照记录」页，**每个读数画面拍一张**（体重 / 体脂肪率 / 骨骼肌率 / 皮下脂肪率，共 4 项，一次拍 1–6 张都行），也可以从相册选旧照片测试；
3. 点「开始 AI 识别」（提示：保持画面清晰、避免反光，识别率更高）；
4. 在「确认读数」页**核对/手改**每个数字，确认「骨骼肌（换算）」无误后点保存；
5. 保存同时写入苹果健康。在「健康」App 的“身体测量”里能看到：体重、体脂肪率、去脂体重。

- 不想用 AI 时：历史页右上角 **＋** 手动添加一条。
- 历史页带四项指标的趋势图，左滑可删除记录。

---

## 在 Mac 上本地构建（可选）

如果你以后拿到 Mac，也可以本地构建（无需开发者账号）：

```bash
brew install xcodegen
python3 -m pip install pillow && python3 scripts/make_icon.py
xcodegen generate
xcodebuild -project ScaleReader.xcodeproj -scheme ScaleReader \
  -configuration Release -sdk iphoneos -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
APP="build/Build/Products/Release-iphoneos/ScaleReader.app"
codesign --force --sign - --entitlements ScaleReader.entitlements "$APP"
mkdir -p Payload && cp -R "$APP" Payload/
zip -qry ScaleReader.ipa Payload
```

---

## 常见问题

- **App 图标是空白的？** 图标由 `scripts/make_icon.py` 在 CI 里生成；本地构建前务必先跑该脚本。
- **识别报错/结果字段全空？** ① 确认 Key 有效、余额/额度足够；② 确认服务商的模型支持图片输入（vision）；③ 换预设试试；④ 仍不行就手动填写，不影响记录。
- **保存时“健康”授权失败/写不进？** TrollStore/侧载环境极少数据写不进的先例；先去系统「健康 → 数据来源与访问」确认 App 被允许写入。即便健康写不进，**本地记录不受影响**。
- **想让“健康”里的体脂率按某个体重出现？** 健康按日期存样本，本 App 保存时使用确认页上的“测量时间”。
- **骨骼肌换算口径**：健康里的“去脂体重”包含骨骼肌以外成分，与秤上标注的“骨骼肌”存在口径差异，这是健康数据模型所限，换算值仅供趋势参考。

---

## 不想用命令行？网页/桌面端上传一样可以

- **纯网页**：登录 GitHub → New repository（名称如 `scale-reader`，选 **Public**，不要勾选"初始化 README/.gitignore"）→ Create → 在仓库页点 **Add file → Upload files**，把解压后的全部内容拖进上传区（保持 `.github`、`ScaleReader`、`scripts` 等子文件夹结构）→ **Commit changes**。
- **GitHub Desktop（图形化，推荐新手）**：下载安装 desktop.github.com → 登录 → **File → Add local repository** → 选择本工程文件夹 → 提示没有 git 历史时直接点 **Publish repository**（仓库名自动取文件夹名，Public）。
- 之后回到该仓库 **Actions** 页运行 **Build IPA**，几分钟后下载 Artifacts 中的 IPA。

---

## 隐私与免责

- 照片只会上传给你在设置里填写的那个 AI 服务商，用于当次识别；App 本身不上传任何数据、无广告、无统计。
- API Key 仅存本机钥匙串。
- 本工具仅供个人健康数据记录，不构成医疗建议。
- 与欧姆龙公司无任何关联。
