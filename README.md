# Suzuka‘s EMS boos v1.0.9

轨道 EMS 攻击：两轮、每轮四枚，`area_size=15`，轮间隔 3 秒，同轮弹间隔 0.25 秒。发射高度从 3000 降至 2700；单枚弹的全局速度和 `spawn_time` 不变。

依赖 Bingus Shared Loader API 1。关闭游戏后，用 `Suzukas-EMS-boos-v1.0.9.zip` 替换旧 EMS 预览包并重新部署。沿用原模组 GUID，同一时间只能启用一个版本。新版 BSL 资源名为 `mods/suzuka/ems_boost`，日志为 `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\SuzukaEMSBoost.log`。

运行时会核对当前 `game.dll`、完整 EMS 组件映射与整条原始记录，写后回读，正常退出时有条件恢复。`STATUS=APPLIED_ALL` 表示字段写入完成；实际落点与飞行时间仍需游戏内确认。

## 从源码构建

构建前需自行用 FileDiver 从游戏提取对应的 `generated_entities.20260922.dl_bin.gz`，放在本目录。该参考样本不随源码仓库发布。然后运行 `python build.py`。构建脚本会核对参考样本和本机 `game.dll` 的 SHA-256；当前仅支持已验证的 DLL `2e2c3b7c2500646dadd5f2b4c6e0504dbb7e7896139f64cddc0d1813c718f51e`。游戏更新后需要重新提取并核对字段，不能只修改哈希值。`component_patch.lua`、`windows_api.lua` 和 `archive.py` 是本项目使用的构建与运行时辅助代码。

本版修改 EMS 弹幕记录的每轮弹数、弹间隔、轮数、轮间隔、范围和发射高度。`spawn_time` 试验未能缩短实际等待，本版不包含该写入。
