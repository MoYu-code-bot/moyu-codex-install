# Codex Windows 安装、重装与迁移

由技能执行检测、官方网页下载和验证；用户完成安装界面、UAC 和登录。优化技能不代表授权操作当前设备。

## 安装与重装

1. 检测 `Get-AppxPackage *OpenAI.Codex*` 及 HKCU/HKLM（含 WOW6432Node）的 Uninstall 记录，核对发布者、版本、安装目录。`Get-Command codex` 不能作为桌面应用已安装凭据。
2. 用户已确认安装或重装则继续，不逐步重复确认；已有安装但未要求重装时不擅自卸载。
3. 自动打开 https://openai.com/codex/ 并定位当前 Windows 官方下载入口。跟随官方链接，核对确为 Codex 桌面应用，不能以 ChatGPT 或 CLI 代替。产品名称变化或无法确认时停止说明。
4. 对官方 EXE 直链运行 `scripts/Get-CodexInstaller.ps1 -Url '<实际链接>'`。默认先保存临时目录；已有确认的 Download 目录时传 `-DownloadDirectory`。下载脚本验证 HTTPS 来源、有效 OpenAI 签名，返回路径及 SHA256。失败不得启动。通过后用 `Start-Process -FilePath '<返回路径>'` 打开安装器，指引用户完成安装，不猜测静默参数。
5. 若只有官方 Microsoft Store 链接，自动打开该入口，引导点击获取/安装；如实说明没有独立 EXE。其他安装包格式按官方说明处理，不传给 EXE 脚本。无网页工具时打开官方页面供用户操作，明确自动下载受阻，不伪报完成。
6. 重装必须先准备有效安装入口，再将真实配置、会话和应用数据备份到唯一命名目录；备份失败停止。记录 CODEX_HOME、真实路径及现有 junction，关闭应用后仅卸载核实的包或运行对应卸载程序，保留用户数据。不清空 .codex、项目、其他 OpenAI 应用、注册表、服务或计划任务。当前执行者运行在 Codex 内时，先保存阶段清单和外部继续步骤，交由外部助手或用户 PowerShell 执行，不能关闭自身后承诺继续。
7. 安装器退出不代表成功。重新检测目标桌面应用、版本和可执行文件，引导启动确认界面正常。取消、失败或检测不到则不进入迁移。

## 安装后询问迁移

验证成功后必须单独询问：是否将数据迁移到其他盘？默认根目录 `D:\Codex`，不存在自动创建，包含 WorkSpace、Download、Memory、Profile。可回复迁移、自定义根目录或不迁移。

未回答不迁移，不创建 D 盘目录。不迁移则保留原路径结束；不强制更新 config.toml。没有 D 盘则询问其他盘，不悄悄改用 C 盘。

## 四个默认目录

确认迁移后运行 `scripts/Initialize-CodexLayout.ps1 -Root 'D:\Codex'`。自定义根目录时四个子目录一起跟随。

| 目录 | 用途与生效方式 |
|---|---|
| WorkSpace | 默认新项目根目录；在应用添加项目/打开文件夹选择此处，并用新聊天确认实际工作路径。CLI 先 Set-Location。已有项目不自动移动。 |
| Download | 本技能管理的安装包及文件下载默认位置。应用有下载设置则配置，否则在 WorkSpace 的 AGENTS.md 添加下载约定并保留已有规则，明确不是全局应用设置。不修改 Windows/浏览器全局下载目录。 |
| Memory | 内置记忆实际存储位置，由 Codex home 的 memories junction 接入。不迁移 Obsidian Vault，不改写记忆内容。 |
| Profile | 迁移后的配置、会话及核实的应用数据，各来源使用独立子目录。 |

创建目录不等于应用设置生效。不杜撰 workspace、download_dir、memory_path 等 TOML 字段，不无条件修改模型提供商。已有 AGENTS.md 规则冲突时先说明，不覆盖。

## 数据迁移编排

关闭所有共享数据的 Codex 桌面、CLI 和后台进程，核实真实路径、目标文件系统支持 junction、剩余空间足够复制及保留备份。展示源→目标表，已确认默认方案不重复询问；已有重定向或目标冲突则停止该项并检查。

| 实际来源 | 默认目标 |
|---|---|
| 有效 CODEX_HOME，未设置时为用户目录 .codex | D:\Codex\Profile\.codex |
| 迁移后的 Profile\.codex\memories | D:\Codex\Memory |
| AppData\Local\OpenAI\Codex，仅确认是数据时 | D:\Codex\Profile\LocalData |
| .cache\codex-runtimes | D:\Codex\Profile\codex-runtimes |

仅处理存在的来源，使用 `scripts/Move-CodexDirectory.ps1 -Source '<绝对源路径>' -Destination '<绝对目标路径>'`。先迁移 Codex home，再迁移 memories。Memory 为预建空目录，调用前仅用 `[IO.Directory]::Delete('<Memory绝对路径>', $false)` 删除空壳；非空则停止，不合并。原 memories 不存在时在真实 Codex home 创建指向 Memory 的 junction。

脚本拒绝嵌套路径、链接和已有目标，复制后逐文件校验 SHA256，源改名为 `.before-migration-<唯一标识>` 备份，再创建 junction。链接失败恢复源名。失败保留复制目标供检查，不覆盖重试；逐项记录返回的 Backup。备份仍占原盘空间，验收后由用户决定删除时间。

已有 junction、非默认 CODEX_HOME 或商店额外数据先核实真实用途，不机械套用映射，不移动 WindowsApps 程序目录、整个商店包目录、现有项目，不改全局环境变量。初次临时下载的安装器复制到 Download 后校验哈希，不覆盖同名文件；后续技能下载直接使用 Download。

## 验收和回滚

检查四个目录、junction 类型/目标以及原路径文件访问；重启应用确认原配置和历史可读；打开 WorkSpace 新聊天验证路径；技能下载进入 Download。记忆功能开启时验证新记忆写入 Memory，未开启只报告路径接入。分别报告已设置、仅约定、未验证，并列出版本、安装器来源、目录映射和备份，不输出凭据内容。

回滚前关闭应用并保留迁移后新增/改变的数据，避免恢复旧备份丢失新会话。按相反顺序恢复，先 memories 再 Codex home。核实备份存在、链接类型及目标后，用 `[IO.Directory]::Delete('<链接绝对路径>', $false)` 仅移除链接，再将对应 Backup 改回原路径；保留目标数据。禁止递归删除链接或目标；任一步失败停止。

## 官方参考

- https://openai.com/codex/ （每次重新发现下载入口）
- https://developers.openai.com/codex/app/windows
- https://developers.openai.com/codex/config-advanced （CODEX_HOME 状态目录）
- https://developers.openai.com/codex/config-reference

官方页面、产品名称和路径能力可能变化，以现场验证为准。
