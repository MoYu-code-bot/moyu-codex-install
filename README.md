# moyu-codex-install

Windows Codex 安装、卸载重装和数据迁移技能，入口为 [SKILL.md](SKILL.md)，流程见 [Codex通用管理指南.md](Codex通用管理指南.md)。

确认安装后自动发现官方下载入口、下载验证并打开安装界面，用户完成安装、UAC 和登录；安装验证后单独询问迁移。

默认根目录 `D:\Codex`，自动创建 WorkSpace（新项目）、Download（技能下载）、Memory（内置记忆）、Profile（迁移数据）。支持其他根目录。

工作目录需在应用添加项目；Download 不等于 Windows/浏览器的全局下载设置。迁移保留备份并逐文件校验，拒绝覆盖目标，不清空用户数据，不强制修改模型提供商。

scripts 提供目录创建、官方 EXE 下载验证和单目录迁移工具，由技能按指南编排。桌面仓库不会自动注册技能；使用时放入宿主支持的技能目录或显式读取 SKILL.md。

## 使用方式

向支持技能的助手提供本仓库的 `SKILL.md`，例如：

> 读取本仓库的 SKILL.md，帮我安装 Codex。

也可以请求“卸载重装 Codex”或“迁移 Codex 数据”。助手先检测实际安装状态，用户确认对应操作后继续。安装验证成功后再询问迁移，不会因安装授权自动迁移数据。

## 默认目录结构

```text
D:\Codex\
├── WorkSpace\   默认新项目工作目录
├── Download\    本技能管理的下载文件
├── Memory\      内置记忆实际存储目录
└── Profile\     迁移后的配置、会话及应用数据
```

用户确认迁移后自动创建目录；没有 D 盘时询问其他盘。Profile 下按来源分开保存，通过 junction 保持原路径可访问；Memory 通过 Codex home 的 memories 链接接入。

## 辅助脚本

| 文件 | 作用 |
|---|---|
| `scripts/Initialize-CodexLayout.ps1` | 创建四个子目录，可重复执行 |
| `scripts/Get-CodexInstaller.ps1` | 下载官方 EXE，验证 OpenAI 签名并输出 SHA256 |
| `scripts/Move-CodexDirectory.ps1` | 单目录复制、哈希校验、保留源备份并创建 junction |
| `scripts/Test-CodexHelpers.ps1` | 在独立临时目录检查目录创建、迁移、冲突拒绝和回滚 |

脚本由技能按指南编排，不应直接对正在运行的 Codex 执行迁移。安装链接每次从官方页面发现；只有 Microsoft Store 入口时引导商店安装，不宣称已下载独立 EXE。

## 验证与限制

在 PowerShell 中运行本地自检：

```powershell
& '.\scripts\Test-CodexHelpers.ps1'
```

自检保留临时测试目录，并输出其路径，不修改真实 Codex 数据。已验证脚本语法和临时目录迁移流程；真实下载安装、应用中的路径生效情况仍需在目标设备验收。

迁移保留的源备份仍占原盘空间，验收后由用户决定何时删除。下载目录是本技能约定，不保证应用所有下载行为都遵循该目录。重装时若助手运行在将被关闭的 Codex 内，需要由外部助手或用户 PowerShell 继续。
