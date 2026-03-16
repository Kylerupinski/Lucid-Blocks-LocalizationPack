# Lucid Blocks Localization Pack 本地化语言包

这是一个可扩展的 Lucid Blocks 语言包。游戏会根据玩家的操作系统语言自动选择对应翻译。

This is an expandable Lucid Blocks language pack. The game will automatically select the corresponding translation based on the player's operating system language.


## 使用说明

1. 在游戏根目录手动创建 `mods` 文件夹。
2. 将 MOD 文件 `LocalizationPacks_1.0.0.pck` 放入 `mods` 文件夹。
3. 完整目录结构示例如下：

+ \lucid-blocks
  + \mods
    + LocalizationPacks_1.0.0.pck 🌟
  + libgdblocks.windows.template_release.double.x86_64.dll
  + libgodotsteam.windows.template_release.double.x86_64.dll
  + lucid-blocks.exe ← 游戏本体 ⭐
  + steam_api64.dll

## ⚠️ 覆盖说明（MOD 制作者请注意）

本语言包会覆盖以下原始游戏文件，可能影响其他 MOD 的兼容性：

+ theme.tres
+ main.gd
+ health_bulb.tscn
+ save_file_container.tscn

当前已验证兼容：

+ [@saucedheca](https://github.com/saucedheca) 的 [Save-Recipes](https://github.com/saucedheca/Lucid-Blocks-Save-Recipes-Mod) 和 [Recipes-browser](https://github.com/saucedheca/lucid-blocks-recipe-browser-mod)

## 📁 PCK 新增文件结构

+ \localization（语言包）
  + \tutorial_menu
+ zpix.ttf

~~## 自行打包（添加你的语言）

0. 使用 Godot Editor 打开 Lucid Blocks 项目（不展开说明游戏导出的流程）。

1. 下载 `localization_dict.csv`，用 VS Code 或 Excel 打开。
   在首行添加你的语言编号（如 `jp`、`ru`、`es`），并补全与 `id` 对应的译文。

2. 为 `theme.tres` 的默认字体添加 fallback（建议使用符合游戏像素风格的字体，字号推荐 `12 px`）。

3. 在 `res://` 下新建 `localization` 文件夹，并导入 `localization_dict.csv`。
   Godot 会自动生成翻译文件：`localization_dict.[你的语言编号].translation`。

4. 在 Godot Editor 中进入
   `Project > Project Settings > Localization > Translations`，
   添加上一步生成的 `localization_dict.[你的语言编号].translation`。

5. 在 `main.gd` 中加入本仓库 `main.gd` 的以下代码片段：
   `30~36` 行、`144~160` 行。

6. 调整 `health_bulb.tscn` 中生命值 Label 的偏移量。

7. 在 Godot 中进入 `Project > Export`，勾选上述修改文件并导出为 `.pck`。~~

## 更新日志

### 2026-03-15 - 1.0

- 新增中文字体 [zpix 像素字体](https://github.com/SolidZORO/zpix-pixel-font)
- 新增语言词典、中文翻译
  （来自 Discord 用户 [@milk_for_free](https://github.com/MILK-FOR-FREE)，感谢 TA 的无私贡献）
- 修正生命值显示错位问题
- 新增对 [@saucedheca](https://github.com/saucedheca) 的 MOD（Lucid-Blocks-Save-Recipes-Mod）兼容

### 2026-03-16 - 1.2

- 重做了翻译文件注册机制
- 动态处理游戏文本进行翻译

### 2026-03-16 - 1.3

- 修复了存档名和作者名不显示的问题

