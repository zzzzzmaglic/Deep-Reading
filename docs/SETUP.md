# 本地运行

当前演示入口是 `ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj`，不是 `app/` 内的早期 Flutter 工程。以下命令均从仓库根目录运行。

## 1. 准备环境

- macOS 与支持 iOS 26 SDK 的 Xcode；安装至少一个 iOS 26 Simulator runtime。
- Docker Desktop，且已启动。
- Supabase CLI；确认 `supabase --version` 可执行。
- 使用 AI 功能时，准备自己的 DeepSeek API Key。后端模型固定为 `deepseek-flash`；账号需能够调用该模型。
- 可选：Deno，用于运行 Edge Function 单元测试；Node.js 用于重新编码提示词源文件。

项目锁定的 Swift Package 版本保存在 Xcode 工程的 `Package.resolved` 中，由 Xcode 自动解析。

## 2. 启动数据库与认证服务

```bash
supabase start
supabase status
```

新建本地环境会按 `supabase/config.toml` 加载迁移与 `seed.sql`。如需重建已有本地数据库，使用以下命令；它会删除该本地环境已有文章、笔记及账户数据，仅在可清空的本地开发环境执行：

```bash
supabase db reset --local
```

种子数据包含四篇文章及阅读报告全文；App 匿名登录后通过 `ensure_reading_report_demo_assets` 初始化该用户的演示笔记。无需手工创建用户。

## 3. 配置并启动 AI 服务

```bash
cp supabase/.env.example supabase/.env.local
```

在 `.env.local` 中填写 `DEEPSEEK_API_KEY`。该文件已被 Git 忽略。Supabase 本地 Edge Runtime 提供自身 URL 与服务端凭证，不要将 service-role key 放到 iOS 配置中。

```bash
supabase functions serve --no-verify-jwt --env-file supabase/.env.local
```

保持此终端运行。这里关闭的是本地网关的 JWT 预检查；两个函数内部仍会验证用户 token 和匿名身份。

缺少模型密钥时可以运行文章、笔记和知识库，AI 请求不能成功。AI 伴读的用量参数需要与数据库 `ai_usage_policy` 一致；示例环境文件使用初始迁移的默认数值。

## 4. 配置并运行 iOS App

```bash
cp ios_visual_prototype/DeepReadingVisualPrototype/Configuration/Debug.xcconfig.example \
  ios_visual_prototype/DeepReadingVisualPrototype/Configuration/Debug.xcconfig
```

编辑复制出的 `Debug.xcconfig`，使用 `supabase status` 显示的本地 API URL 和 anon key。原生 iOS Simulator 可通过 `127.0.0.1` 访问 Mac 上的本地服务。

```text
SUPABASE_URL = http:/$()/127.0.0.1:54321
SUPABASE_ANON_KEY = <本地 anon key>
```

`.xcconfig` 中的 `//` 会开始注释，因此 URL 使用 `/$()/` 写法。不要把示例文件中的 `#include? "Debug.xcconfig"` 再放进复制后的文件；配置文件只需保留以上两行。

打开 `ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj`，选择 `DeepReadingVisualPrototype` Scheme 和可用的 iOS 26 模拟器，按 Run。Debug 构建使用 Keychain，需在 Signing & Capabilities 中改为自己的 Team，不使用仓库原开发者的 Team。

### 无开发者签名的模拟器运行方式

可使用 Release simulator 内存会话路径，不依赖 Keychain 权限。先通过 `xcrun simctl list devices available` 查看设备，再启动所选模拟器。以下要求只有一个模拟器处于启动状态：

```bash
read -r -s SUPABASE_ANON_KEY
export SUPABASE_ANON_KEY
xcodebuild -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/native-demo \
  SUPABASE_URL=http://127.0.0.1:54321 \
  SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" CODE_SIGNING_ALLOWED=NO build
xcrun simctl install booted build/native-demo/Build/Products/Release-iphonesimulator/DeepReadingVisualPrototype.app
xcrun simctl launch booted com.deepreading.visualprototype
unset SUPABASE_ANON_KEY
```

执行 `read` 时粘贴本地 anon key 后回车，输入不显示。这里的 anon key 是客户端公开配置，不是服务端 secret key。无签名 Release 模拟器每次启动新进程会建立新的匿名会话。

## 5. 验证

先确认知识库显示四篇文章，进入任意文章，检查划线笔记、AI 伴读和完成阅读后的报告。

```bash
supabase test db
deno test supabase/functions/ai-companion/context_test.ts
deno test supabase/functions/reading-report/logic_test.ts supabase/functions/reading-report/pipeline_test.ts supabase/functions/reading-report/index_test.ts
```

XCTest 使用配置好签名的 Debug 工程：

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -destination 'platform=iOS Simulator,id=<你的模拟器 UUID>'
```

修改阅读报告提示词 Markdown 后，需要同步运行时内嵌内容：

```bash
node supabase/scripts/sync-reading-report-prompt-sources.mjs
```

## 常见问题

| 现象 | 检查方式 |
| --- | --- |
| 无法连接阅读服务 | 检查 Docker、`supabase status`、App 的 URL/anon key；无签名包使用 Release simulator 路径 |
| 知识库没有文章 | 确认使用的是加载了当前 seed 的本地数据库 |
| 报告或伴读失败 | 检查 functions serve 是否运行、模型密钥、模型访问权限及函数日志 |
| AI 伴读提示额度不足 | 查看 `ai_usage_policy` 与本地环境参数是否匹配；阅读报告与伴读的用量控制不同 |
| 提示词修改没有生效 | 运行同步脚本并重新启动函数服务 |

本说明按当前源码与配置整理。本轮文档整理未重新执行全新环境的完整安装验收；历史本机验收与问题记录保留在 `HANDOFF.md` 中。
