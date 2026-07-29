# Codex 桌面应用彻底卸载重装指南

> 本文档供 WorkBuddy/QoderWork 执行，按步骤操作即可完成 Codex 的干净卸载与重装。
> 执行前先通读全文，遇到与用户环境不符的情况需主动确认后再继续。

---

## 前置：环境探测

在执行任何操作之前，先收集以下信息，记录当前设备上的 Codex 实际状态：

### 1. 确认用户主目录

```
echo %USERPROFILE%
```

记录输出，后续所有路径中的 `{HOME}` 替换为此值。

### 2. 检查 Codex 安装方式

```powershell
Get-AppxPackage *OpenAI.Codex* | Format-List Name, PackageFamilyName, InstallLocation, Version
```

- **有输出** → Codex 是 Microsoft Store (UWP) 应用，记录 InstallLocation 和 PackageFullName
- **无输出** → 尝试查找 Win32 安装：

```
where codex 2>nul
dir /s /b "{HOME}\AppData\Local\OpenAI\Codex\*.exe" 2>nul
dir /s /b "{HOME}\AppData\Local\Programs\Codex\*.exe" 2>nul
```

### 3. 检查 Codex 进程是否运行

```powershell
Get-Process *codex* -ErrorAction SilentlyContinue | Format-Table Id, ProcessName, Path
```

- **有输出** → 需要先关闭进程（见步骤一）
- **无输出** → 可跳到步骤二

### 4. 扫描所有相关目录是否存在

逐一检查以下路径是否存在（存在则标记待清理）：

```
{HOME}\AppData\Local\OpenAI\Codex
{HOME}\AppData\Local\OpenAI
{HOME}\.codex
{HOME}\.cache\codex-runtimes
{HOME}\Documents\Codex
```

对每个存在的路径，执行以下命令判断是否为 junction（符号链接）：

```powershell
Get-Item "路径" | Select-Object FullName, Attributes, @{N='Target';E={$_.Target}}
```

如果 Attributes 包含 `ReparsePoint`，说明是 junction，需要同时记录 Target 指向的真实目录（该目录也需要清理）。

将探测结果汇总后告知用户，确认无误再继续。

---

## 步骤一：关闭 Codex 进程

```powershell
Get-Process *codex* -ErrorAction SilentlyContinue | Stop-Process -Force
```

验证：

```powershell
Get-Process *codex* -ErrorAction SilentlyContinue
```

无输出即表示已关闭。如果仍有残留，等待几秒后重试，或提示用户手动在任务管理器中结束。

---

## 步骤二：卸载应用

### 如果是 UWP（商店版）

```powershell
Get-AppxPackage *OpenAI.Codex* | Remove-AppxPackage
```

验证：

```powershell
Get-AppxPackage *OpenAI.Codex*
```

无输出即卸载成功。

### 如果是 Win32（传统安装）

查找卸载入口：

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Codex*" } | Select-Object DisplayName, UninstallString
```

执行返回的 UninstallString，或使用 `winget`：

```
winget uninstall --name "Codex"
```

---

## 步骤三：清理残留数据

按探测阶段标记的目录逐一清理。

### 3.1 如果是 junction，先解除再清理

对于每个 junction 类型的目录，需要先解除 junction 再分别清理：

```powershell
# 示例：{HOME}\.codex 是 junction，指向 D:\Tools\Codex&ChatGPT\Codex\.codex

# 先记录 junction 的目标路径，后面要清理真实目录
$target = (Get-Item "{HOME}\.codex").Target

# 删除 junction 本身（仅删除链接，不影响目标内容）
cmd /c rmdir "{HOME}\.codex"

# 然后清理真实目录 $target（见 3.2）
```

同理处理其他 junction：
- `{HOME}\AppData\Local\OpenAI\Codex` → `D:\Tools\Codex&ChatGPT\Codex`（根目录）
- `{HOME}\.cache\codex-runtimes` → `D:\Tools\Codex&ChatGPT\Codex\codex-runtimes`

**重要**：删除 junction 用 `rmdir`（不用 `rmdir /s /q`），这样只删链接不删内容。然后单独清理目标目录。

### 3.2 清理真实数据目录

对每个需要清理的**真实目录**（非 junction），使用安全删除（移到回收站）：

```powershell
Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory("目录路径", 'OnlyErrorDialogs', 'SendToRecycleBin')
```

需要清理的目录清单（根据探测结果选择性执行）：

| 路径 | 说明 |
|------|------|
| `{HOME}\AppData\Local\OpenAI\Codex` | 主程序数据 |
| `{HOME}\AppData\Local\OpenAI` | 如果目录下已无其他内容，一并清理 |
| `{HOME}\.codex` | 配置文件目录（含 config.toml） |
| `{HOME}\.cache\codex-runtimes` | 运行时缓存 |
| `D:\Tools\Codex&ChatGPT\Codex\.codex` | junction 目标：配置数据 |
| `D:\Tools\Codex&ChatGPT\Codex\codex-runtimes` | junction 目标：运行时缓存 |
| `D:\Tools\Codex&ChatGPT\Codex\bin` | junction 目标：二进制文件 |
| `D:\Tools\Codex&ChatGPT\Codex\runtimes` | junction 目标：运行时 |
| `D:\Tools\Codex&ChatGPT\Codex\chrome-native-hosts-v2.json` | Chrome 原生消息配置（如存在） |
| `D:\Tools\Codex&ChatGPT\Codex` | 以上全部清空后，删除根目录本身 |

### 3.3 清理项目工作目录

`{HOME}\Documents\Codex` 是 Codex 的项目工作空间（按日期存放编码项目文件）。**此目录必须保留在 C 盘，不能通过 junction 迁移**（Codex 会校验 reparse point 并报错 "Projectless thread directory must be a real directory"）。如果其中有用户需要保留的项目文件，**必须先询问用户**，确认后再删除。

### 3.4 清理商店缓存（可选）

```
wsreset.exe
```

### 3.5 全面验证：确认无残留

清理完成后，必须逐项检查以下内容，确保 Codex 的所有痕迹已彻底清除。**所有检查均无结果才算通过，任何一项有残留都需要返回步骤三继续清理。**

#### 3.5.1 文件系统扫描

逐一检查以下路径是否**不存在**：

```powershell
$paths = @(
    "$env:USERPROFILE\AppData\Local\OpenAI\Codex",
    "$env:USERPROFILE\AppData\Local\OpenAI",
    "$env:USERPROFILE\.codex",
    "$env:USERPROFILE\.cache\codex-runtimes",
    "$env:USERPROFILE\Documents\Codex"
)
foreach ($p in $paths) {
    if (Test-Path $p) { Write-Host "[残留] $p 仍然存在" }
}
```

如果用户之前有 junction 迁移，还需检查 D 盘目标目录 `D:\Tools\Codex&ChatGPT\Codex` 及其所有子目录（`.codex`、`bin`、`codex-runtimes`、`runtimes`）是否已清空。

同时搜索其他可能位置：

```powershell
Get-ChildItem "$env:USERPROFILE\AppData" -Directory -Recurse -Filter "*codex*" -ErrorAction SilentlyContinue | Select-Object FullName
Get-ChildItem "$env:USERPROFILE\AppData" -Directory -Recurse -Filter "*openai*" -ErrorAction SilentlyContinue | Select-Object FullName
Get-ChildItem "$env:LOCALAPPDATA" -Directory -Recurse -Filter "*codex*" -ErrorAction SilentlyContinue | Select-Object FullName
```

全部无输出才表示文件系统清理完成。

#### 3.5.2 注册表扫描

检查以下注册表位置是否有 Codex/OpenAI 相关条目：

```powershell
# 应用卸载信息
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
foreach ($rp in $regPaths) {
    Get-ItemProperty $rp -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Codex*" -or $_.DisplayName -like "*OpenAI*" } | Select-Object DisplayName, PSPath
}

# UWP 包注册信息
Get-ChildItem "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Packages" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*OpenAI*" -or $_.Name -like "*Codex*" } | Select-Object Name

# 搜索 OpenAI/Codex 相关的自定义注册表键
Get-ChildItem "HKCU:\SOFTWARE" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*OpenAI*" -or $_.Name -like "*Codex*" } | Select-Object Name
```

如果发现残留注册表项，使用 `Remove-Item` 删除（删除前先导出备份）：

```powershell
# 备份后删除示例
reg export "键路径" "C:\Users\123\Desktop\codex_reg_backup.reg" /y
Remove-Item "键路径" -Recurse -Force
```

#### 3.5.3 计划任务和服务检查

```powershell
# 检查是否有 Codex 相关的计划任务
Get-ScheduledTask | Where-Object { $_.TaskName -like "*Codex*" -or $_.TaskName -like "*OpenAI*" } | Select-Object TaskName, State

# 检查是否有相关 Windows 服务
Get-Service | Where-Object { $_.Name -like "*Codex*" -or $_.DisplayName -like "*OpenAI*" } | Select-Object Name, DisplayName, Status
```

无输出表示无残留任务或服务。

#### 3.5.4 环境变量检查

```powershell
# 检查用户环境变量中是否有 Codex 相关路径
[Environment]::GetEnvironmentVariable("Path", "User") -split ";" | Where-Object { $_ -like "*codex*" -or $_ -like "*openai*" }
```

无输出表示环境变量干净。

#### 3.5.5 最终确认

将以上所有检查结果汇总后告知用户，格式如下：

```
✓ 文件系统：无残留
✓ 注册表：无残留
✓ 计划任务：无残留
✓ Windows 服务：无残留
✓ 环境变量：无残留

Codex 已彻底卸载，可以开始重装。
```

**任何一项未通过都不能进入步骤四，必须先处理残留。**

---

## 步骤四：重装 Codex

从官方页面下载安装包：

```
https://openai.com/zh-Hans-CN/codex/
```

使用浏览器自动化或引导用户打开该链接，下载 Windows 版安装包并执行安装。

安装完成后验证：

```powershell
Get-AppxPackage *OpenAI.Codex* | Format-List Name, Version, InstallLocation
```

或通过查找可执行文件：

```
where codex 2>nul
dir /s /b "{HOME}\AppData\Local\OpenAI\Codex\*.exe" 2>nul
```

有输出即安装成功。

---

## 步骤五：安装确认（必须暂停）

**此步骤必须暂停，等待用户确认后再继续。**

安装完成后，向用户报告以下信息：

```
Codex 重装完成，当前状态：
- 安装路径：{实际安装路径}
- 版本号：{版本号}

接下来需要执行路径迁移操作（将 C 盘数据目录通过 junction 迁移到 D:\Tools\Codex&ChatGPT\Codex）。
迁移计划：
  1. AppData\Local\OpenAI\Codex → D:\Tools\Codex&ChatGPT\Codex（根目录）
  2. .codex → D:\Tools\Codex&ChatGPT\Codex\.codex
  3. .cache\codex-runtimes → D:\Tools\Codex&ChatGPT\Codex\codex-runtimes
  4. Documents\Codex 保留在 C 盘（Codex 校验 reparse point，不支持 junction 迁移）

请确认是否执行路径迁移？（回复"确认"继续，或告知其他需求）
```

**必须等到用户明确确认后，才能进入步骤六。** 如果用户选择不迁移，直接执行步骤 6.2 更新 config.toml 后进入 6.4 验证。

---

## 步骤六：路径迁移（用户确认后执行）

### 6.1 重新建立 junction 迁移

**重要：先不要启动 Codex**，否则它会在 C 盘生成新数据。

```powershell
# 迁移目标根目录
$base = "D:\Tools\Codex&ChatGPT\Codex"

# 确保目标根目录存在
if (-not (Test-Path -LiteralPath $base)) {
    New-Item -ItemType Directory -Path $base -Force | Out-Null
}

# 1. AppData\Local\OpenAI\Codex → D:\Tools\Codex&ChatGPT\Codex（根目录）
#    注意：必须逐个移动子项而非整个目录，否则 Move-Item 会在已存在的目标内创建嵌套子目录
$src1 = "$env:USERPROFILE\AppData\Local\OpenAI\Codex"
Get-ChildItem -LiteralPath $src1 -Force | ForEach-Object {
    Move-Item -LiteralPath $_.FullName -Destination (Join-Path $base $_.Name) -Force
}
Remove-Item -LiteralPath $src1 -Force
New-Item -ItemType Junction -Path $src1 -Target $base | Out-Null

# 2. .codex → D:\Tools\Codex&ChatGPT\Codex\.codex
Move-Item -LiteralPath "$env:USERPROFILE\.codex" -Destination "$base\.codex" -Force
New-Item -ItemType Junction -Path "$env:USERPROFILE\.codex" -Target "$base\.codex" | Out-Null

# 3. .cache\codex-runtimes → D:\Tools\Codex&ChatGPT\Codex\codex-runtimes
Move-Item -LiteralPath "$env:USERPROFILE\.cache\codex-runtimes" -Destination "$base\codex-runtimes" -Force
New-Item -ItemType Junction -Path "$env:USERPROFILE\.cache\codex-runtimes" -Target "$base\codex-runtimes" | Out-Null

# 4. Documents\Codex 不迁移，保留在 C 盘
#    原因：Codex 会校验工作目录是否为真实目录（非 reparse point），
#    junction 迁移后报错 "Projectless thread directory must be a real directory"
```

**注意**：路径中含 `&` 符号时，bash 中需用引号包裹路径。

### 6.2 更新 config.toml

安装完成后需要修改 Codex 配置文件，添加 HTTPS 轮询模式（WebSocket 不稳定时的回退方案）。

配置文件路径（根据是否执行了 junction 迁移）：

- **已迁移**：`D:\Tools\Codex&ChatGPT\Codex\.codex\config.toml`（或通过 junction 访问 `{HOME}\.codex\config.toml`）
- **未迁移**：`{HOME}\.codex\config.toml`

用 Python 脚本自动修改（幂等操作，重复执行安全）：

```python
import re, sys

config_path = sys.argv[1]

with open(config_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 顶部增加或修改 model_provider
if re.search(r'^model_provider\s*=', content, re.MULTILINE):
    content = re.sub(r'^model_provider\s*=.*', 'model_provider = "openai_https"', content, flags=re.MULTILINE)
else:
    content = 'model_provider = "openai_https"\n' + content

# 2. 末尾增加 model_providers 配置（如已存在则跳过）
provider_block = '''
[model_providers.openai_https]
name = "OpenAI"
wire_api = "responses"
requires_openai_auth = true
supports_websockets = false
'''
if '[model_providers.openai_https]' not in content:
    content = content.rstrip() + '\n' + provider_block

with open(config_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("config.toml 已更新")
```

执行：

```powershell
python -c "上面的脚本内容" "{config.toml 的实际路径}"
```

修改后验证：

```powershell
type "{config.toml 路径}"
```

确认输出包含：
- 顶部有 `model_provider = "openai_https"`
- 末尾有 `[model_providers.openai_https]` 区块及其四个字段

### 6.3 恢复其他配置

如果有其他自定义配置（如之前的 config.toml 备份），在此步骤合并。注意不要覆盖 6.2 中已设置的 `model_provider` 相关字段。

### 6.4 验证

启动 Codex，确认应用正常运行。如果设置了 junction，检查 D 盘目标目录是否有新文件写入，确认 junction 生效。

---

## 异常处理

| 情况 | 处理方式 |
|------|---------|
| 进程无法关闭 | 等待后重试，或引导用户在任务管理器手动结束 |
| `Remove-AppxPackage` 报错 | 检查是否有其他用户也安装了该应用，尝试加 `-AllUsers` 参数 |
| 目录删除报"被占用" | 确认进程已关闭，重启资源管理器（`taskkill /f /im explorer.exe && start explorer.exe`）后重试 |
| 商店安装失败 | 执行 `wsreset.exe` 清理缓存后重试，或检查网络连接 |
| junction 创建失败 | 确认目标路径已存在且 junction 路径不存在，路径含特殊字符时用 PowerShell 而非 cmd |
