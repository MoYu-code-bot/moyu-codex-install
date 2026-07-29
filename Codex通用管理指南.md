# Codex 桌面应用通用管理指南（卸载/重装/迁移）

> 本文档供 WorkBuddy/QoderWork 在任意 Windows 设备上执行。
> 按交互流程引导用户，每步需确认后再继续，禁止自动跳过用户确认环节。

---

## 流程图概览

```
步骤一：检测 Codex
  ├── 未安装 → 询问是否安装
  │     ├── 否 → 结束
  │     └── 是 → 步骤二（安装） → 步骤三（询问迁移）
  └── 已安装 → 询问操作
        ├── 卸载重装 → 步骤四（卸载+清理）→ 步骤二（重装）→ 步骤三（询问迁移）
        ├── 仅迁移路径 → 步骤三（询问迁移）
        └── 不需要操作 → 结束
```

---

## 步骤一：检测本机 Codex 状态

### 1.1 确认用户主目录

```
echo %USERPROFILE%
```

记录输出，后续所有路径中的 `{HOME}` 替换为此值。

### 1.2 检测 Codex 安装情况

```powershell
# 检测 UWP（商店版）
Get-AppxPackage *OpenAI.Codex* | Format-List Name, PackageFamilyName, InstallLocation, Version
```

- **有输出** → Codex 已安装（UWP 版），记录信息，跳到 1.3
- **无输出** → 继续检测 Win32 版：

```
where codex 2>nul
dir /s /b "{HOME}\AppData\Local\OpenAI\Codex\*.exe" 2>nul
dir /s /b "{HOME}\AppData\Local\Programs\Codex\*.exe" 2>nul
```

- **有输出** → Codex 已安装（Win32 版），记录信息，跳到 1.3
- **无输出** → Codex 未安装，跳到 1.4

### 1.3 Codex 已安装 → 询问用户操作

向用户报告当前安装状态：

```
检测到本机已安装 Codex：
- 安装方式：{UWP/Win32}
- 版本号：{版本号}
- 安装路径：{路径}

请选择操作：
1. 卸载重装（彻底清理后重新安装）
2. 仅迁移数据路径（将 C 盘数据迁移到其他盘）
3. 不需要操作
```

**根据用户选择：**
- 选 1 → 进入 **步骤四**（卸载+清理）
- 选 2 → 进入 **步骤三**（询问迁移）
- 选 3 → 结束

### 1.4 Codex 未安装 → 询问是否安装

```
未检测到本机安装 Codex。
是否需要安装 Codex？
```

- 用户确认安装 → 进入 **步骤二**
- 用户不需要 → 结束

---

## 步骤二：安装 Codex

### 2.1 下载安装

从官方页面下载：

```
https://openai.com/zh-Hans-CN/codex/
```

使用浏览器自动化打开该链接，引导用户下载 Windows 版安装包并执行安装。

### 2.2 验证安装

```powershell
# 检测 UWP
Get-AppxPackage *OpenAI.Codex* | Format-List Name, Version, InstallLocation

# 或检测 Win32
where codex 2>nul
dir /s /b "{HOME}\AppData\Local\OpenAI\Codex\*.exe" 2>nul
```

有输出即安装成功，记录安装路径和版本号。

### 2.3 安装完成 → 进入步骤三

---

## 步骤三：询问是否迁移数据路径

**此步骤必须暂停，等待用户确认。**

### 3.1 扫描当前数据目录

检查以下目录是否存在及大小：

```powershell
$dirs = @(
    "$env:USERPROFILE\AppData\Local\OpenAI\Codex",
    "$env:USERPROFILE\.codex",
    "$env:USERPROFILE\.cache\codex-runtimes"
)
foreach ($d in $dirs) {
    if (Test-Path $d) {
        $size = (Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $sizeMB = if ($size) { '{0:N1}' -f ($size / 1MB) } else { '0' }
        Write-Host "$d  ($sizeMB MB)"
    }
}
```

### 3.2 向用户报告并询问

```
Codex 数据目录扫描结果：
{列出存在的目录及大小}

这些数据目前存储在 C 盘。是否需要迁移到其他盘以释放 C 盘空间？

默认迁移路径：D:\Codex\WorkSpace
如需使用其他路径，请告诉我。

回复"确认"使用默认路径迁移，或提供自定义路径，或回复"不迁移"跳过。
```

**根据用户回复：**
- "不迁移" / "不需要" → 跳到 **步骤七**（更新 config.toml）
- "确认" → 使用默认路径 `D:\Codex\WorkSpace`，进入 **步骤五**
- 提供了自定义路径 → 记录路径，进入 **步骤五**

---

## 步骤四：卸载与彻底清理（仅"卸载重装"时执行）

### 4.1 关闭 Codex 进程

```powershell
Get-Process *codex* -ErrorAction SilentlyContinue | Stop-Process -Force
```

验证：

```powershell
Get-Process *codex* -ErrorAction SilentlyContinue
```

无输出即已关闭。

### 4.2 卸载应用

**UWP（商店版）：**

```powershell
Get-AppxPackage *OpenAI.Codex* | Remove-AppxPackage
```

**Win32（传统安装）：**

```powershell
# 查找卸载入口
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Codex*" } | Select-Object DisplayName, UninstallString
```

执行 UninstallString 或使用 winget：

```
winget uninstall --name "Codex"
```

### 4.3 解除已有 junction（如存在）

逐一检查以下路径是否为 junction：

```powershell
$junctionPaths = @(
    "$env:USERPROFILE\AppData\Local\OpenAI\Codex",
    "$env:USERPROFILE\.codex",
    "$env:USERPROFILE\.cache\codex-runtimes"
)
foreach ($p in $junctionPaths) {
    if (Test-Path -LiteralPath $p) {
        $item = Get-Item -LiteralPath $p -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Host "发现 junction: $p -> $($item.Target)"
            # 记录目标路径用于后续清理
            $target = $item.Target
            # 删除 junction（仅删链接）
            cmd /c "rmdir `"$p`""
            Write-Host "  junction 已解除，真实目录: $target"
        }
    }
}
```

### 4.4 清理残留数据

对每个需要清理的目录，使用安全删除（移到回收站）：

```powershell
Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory("目录路径", 'OnlyErrorDialogs', 'SendToRecycleBin')
```

需要清理的目录清单（根据实际存在情况选择性执行）：

| 路径 | 说明 |
|------|------|
| `{HOME}\AppData\Local\OpenAI\Codex` | 主程序数据 |
| `{HOME}\AppData\Local\OpenAI` | 如果目录下已无其他内容，一并清理 |
| `{HOME}\.codex` | 配置文件目录（含 config.toml） |
| `{HOME}\.cache\codex-runtimes` | 运行时缓存 |
| junction 指向的 D 盘真实目录 | junction 背后的实际数据 |

**关于 Documents\Codex**：此目录是 Codex 的项目工作空间，**必须询问用户是否有需要保留的文件**，确认后再清理。此目录不能通过 junction 迁移（Codex 会校验 reparse point 报错）。

### 4.5 清理商店缓存（可选）

```
wsreset.exe
```

### 4.6 全面验证：确认无残留

逐项检查以下内容，**全部无结果才算通过**：

#### 文件系统扫描

```powershell
$paths = @(
    "$env:USERPROFILE\AppData\Local\OpenAI\Codex",
    "$env:USERPROFILE\AppData\Local\OpenAI",
    "$env:USERPROFILE\.codex",
    "$env:USERPROFILE\.cache\codex-runtimes"
)
foreach ($p in $paths) {
    if (Test-Path $p) { Write-Host "[残留] $p 仍然存在" }
}
```

同时搜索其他可能位置：

```powershell
Get-ChildItem "$env:USERPROFILE\AppData" -Directory -Recurse -Filter "*codex*" -ErrorAction SilentlyContinue | Select-Object FullName
Get-ChildItem "$env:USERPROFILE\AppData" -Directory -Recurse -Filter "*openai*" -ErrorAction SilentlyContinue | Select-Object FullName
```

如果之前有 junction 迁移，还需检查 D 盘目标目录是否已清空。

#### 注册表扫描

```powershell
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
foreach ($rp in $regPaths) {
    Get-ItemProperty $rp -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Codex*" -or $_.DisplayName -like "*OpenAI*" } | Select-Object DisplayName, PSPath
}
Get-ChildItem "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Packages" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*OpenAI*" -or $_.Name -like "*Codex*" } | Select-Object Name
Get-ChildItem "HKCU:\SOFTWARE" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*OpenAI*" -or $_.Name -like "*Codex*" } | Select-Object Name
```

如发现残留，先导出备份再删除：

```powershell
reg export "键路径" "桌面\codex_reg_backup.reg" /y
Remove-Item "键路径" -Recurse -Force
```

#### 计划任务和服务

```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like "*Codex*" -or $_.TaskName -like "*OpenAI*" } | Select-Object TaskName, State
Get-Service | Where-Object { $_.Name -like "*Codex*" -or $_.DisplayName -like "*OpenAI*" } | Select-Object Name, DisplayName, Status
```

#### 环境变量

```powershell
[Environment]::GetEnvironmentVariable("Path", "User") -split ";" | Where-Object { $_ -like "*codex*" -or $_ -like "*openai*" }
```

#### 最终确认

汇总检查结果：

```
✓ 文件系统：无残留
✓ 注册表：无残留
✓ 计划任务：无残留
✓ Windows 服务：无残留
✓ 环境变量：无残留

Codex 已彻底卸载，可以开始重装。
```

**任何一项未通过都不能继续，必须先处理残留。**

### 4.7 卸载完成 → 进入步骤二（重装）

---

## 步骤五：数据路径迁移

**重要：先不要启动 Codex**，否则它会在 C 盘生成新数据。

### 5.1 确认迁移路径

默认迁移路径为 `D:\Codex\WorkSpace`，如果用户提供了自定义路径则使用用户路径。

记为 `$base`（后续所有命令中使用此变量）。

### 5.2 确保目标目录存在

```powershell
$base = "D:\Codex\WorkSpace"  # 或用户指定的路径

if (-not (Test-Path -LiteralPath $base)) {
    New-Item -ItemType Directory -Path $base -Force | Out-Null
    Write-Host "已创建迁移目标目录: $base"
}
```

### 5.3 执行迁移

```powershell
# 1. AppData\Local\OpenAI\Codex → 迁移根目录
#    注意：必须逐个移动子项而非整个目录，否则 Move-Item 会在已存在的目标内创建嵌套子目录
$src1 = "$env:USERPROFILE\AppData\Local\OpenAI\Codex"
if (Test-Path -LiteralPath $src1) {
    Get-ChildItem -LiteralPath $src1 -Force | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination (Join-Path $base $_.Name) -Force
    }
    Remove-Item -LiteralPath $src1 -Force
    New-Item -ItemType Junction -Path $src1 -Target $base | Out-Null
    Write-Host "1. AppData\Codex -> $base [OK]"
}

# 2. .codex → 迁移目录\.codex
$src2 = "$env:USERPROFILE\.codex"
$dst2 = "$base\.codex"
if (Test-Path -LiteralPath $src2) {
    Move-Item -LiteralPath $src2 -Destination $dst2 -Force
    New-Item -ItemType Junction -Path $src2 -Target $dst2 | Out-Null
    Write-Host "2. .codex -> $dst2 [OK]"
}

# 3. .cache\codex-runtimes → 迁移目录\codex-runtimes
$src3 = "$env:USERPROFILE\.cache\codex-runtimes"
$dst3 = "$base\codex-runtimes"
if (Test-Path -LiteralPath $src3) {
    Move-Item -LiteralPath $src3 -Destination $dst3 -Force
    New-Item -ItemType Junction -Path $src3 -Target $dst3 | Out-Null
    Write-Host "3. codex-runtimes -> $dst3 [OK]"
}

# Documents\Codex 不迁移（Codex 校验 reparse point，junction 会报错）
```

**注意**：路径中含特殊字符（如 `&`）时，bash 中需用引号包裹路径。

### 5.4 验证迁移结果

```powershell
# 验证 junction
$checks = @(
    "$env:USERPROFILE\AppData\Local\OpenAI\Codex",
    "$env:USERPROFILE\.codex",
    "$env:USERPROFILE\.cache\codex-runtimes"
)
foreach ($c in $checks) {
    if (Test-Path -LiteralPath $c) {
        $item = Get-Item -LiteralPath $c -Force
        $isJ = $item.Attributes -band [System.IO.FileAttributes]::ReparsePoint
        if ($isJ) { Write-Host "[OK] $c -> $($item.Target)" }
        else { Write-Host "[FAIL] $c 不是 junction" }
    }
}
```

同时验证通过 junction 可正常访问文件：

```powershell
Test-Path "$env:USERPROFILE\.codex\config.toml"
Test-Path "$env:USERPROFILE\AppData\Local\OpenAI\Codex"
```

---

## 步骤六：回滚方案（迁移失败时使用）

如果迁移后 Codex 报错或文件无法访问，执行回滚：

```powershell
$base = "迁移目标路径"  # 替换为实际使用的路径

# 1. 解除 junction
$junctions = @(
    "$env:USERPROFILE\AppData\Local\OpenAI\Codex",
    "$env:USERPROFILE\.codex",
    "$env:USERPROFILE\.cache\codex-runtimes"
)
foreach ($j in $junctions) {
    if (Test-Path -LiteralPath $j) {
        $item = Get-Item -LiteralPath $j -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            cmd /c "rmdir `"$j`""
        }
    }
}

# 2. 从迁移目标拷回 C 盘
if (Test-Path -LiteralPath $base) {
    Copy-Item -LiteralPath $base -Destination "$env:USERPROFILE\AppData\Local\OpenAI\Codex" -Recurse -Force
}
$codexCfg = "$base\.codex"
if (Test-Path -LiteralPath $codexCfg) {
    Copy-Item -LiteralPath $codexCfg -Destination "$env:USERPROFILE\.codex" -Recurse -Force
}
$codexRT = "$base\codex-runtimes"
if (Test-Path -LiteralPath $codexRT) {
    New-Item -ItemType Directory -Path "$env:USERPROFILE\.cache" -Force -ErrorAction SilentlyContinue | Out-Null
    Copy-Item -LiteralPath $codexRT -Destination "$env:USERPROFILE\.cache\codex-runtimes" -Recurse -Force
}

Write-Host "回滚完成，数据已恢复到 C 盘原始位置"
```

---

## 步骤七：更新 config.toml

无论是否执行了路径迁移，安装/重装后都需要更新配置文件。

### 7.1 定位 config.toml

```powershell
$cfgPath = "$env:USERPROFILE\.codex\config.toml"
if (-not (Test-Path $cfgPath)) {
    Write-Host "config.toml 不存在，Codex 首次启动后会自动生成"
    Write-Host "请先启动一次 Codex，然后重新执行此步骤"
}
```

### 7.2 添加 HTTPS 轮询配置

用 Python 脚本自动修改（幂等操作）：

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

### 7.3 验证

```powershell
type "{config.toml 路径}"
```

确认输出包含：
- 顶部有 `model_provider = "openai_https"`
- 末尾有 `[model_providers.openai_https]` 区块及其四个字段

---

## 步骤八：最终验证

### 8.1 启动 Codex

引导用户启动 Codex，确认应用正常运行。

### 8.2 如果执行了迁移

检查迁移目标目录是否有新文件写入，确认 junction 生效：

```powershell
Get-ChildItem $base -Force | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

### 8.3 向用户报告最终结果

```
Codex 管理操作完成！
- 安装版本：{版本号}
- 安装路径：{路径}
- 数据迁移：{已迁移至 D:\Codex\WorkSpace / 未迁移，保留 C 盘}
- config.toml：{已更新 HTTPS 轮询配置 / 首次启动后需手动配置}

如有问题请随时反馈。
```

---

## 异常处理

| 情况 | 处理方式 |
|------|---------|
| 进程无法关闭 | 等待后重试，或引导用户在任务管理器手动结束 |
| `Remove-AppxPackage` 报错 | 检查是否有其他用户也安装了该应用，尝试加 `-AllUsers` 参数 |
| 目录删除报"被占用" | 确认进程已关闭，重启资源管理器后重试 |
| 安装失败 | 检查网络连接，执行 `wsreset.exe` 清理商店缓存后重试 |
| junction 创建失败 | 确认源路径不存在且目标路径已存在，路径含特殊字符时用 PowerShell |
| Move-Item 导致嵌套目录 | 使用 `Get-ChildItem + ForEach-Object + Move-Item` 逐个移动子项 |
| config.toml 不存在 | 先启动一次 Codex 让其自动生成，再执行配置更新 |
| 迁移后 Codex 报错 | 执行步骤六回滚方案，恢复 C 盘原始路径 |
