# 发布检查清单

每次 release 打 tag 前逐项确认。**不允许跳项**——「这次应该没问题」是发布事故最常见的开场白。

复制本文件到 release issue 中，逐条勾选并附证据（截图 / CI 链接 / 命令输出）。

---

## 一、代码与版本

- [ ] `release/vX.Y` 分支已从 `main` 切出，且只含 bugfix
- [ ] 版本号在以下位置**全部一致**：
  - [ ] `apps/mistream/pubspec.yaml`
  - [ ] Windows 安装包元数据（MSIX manifest）
  - [ ] macOS `Info.plist`
  - [ ] Linux AppImage 元数据
  - [ ] 应用内「关于」页
- [ ] CHANGELOG 已从 Conventional Commits 生成，并**人工润色**（自动生成的条目对用户不可读）
- [ ] 所有 `BREAKING CHANGE` 在 CHANGELOG 中显著标注，并附迁移指引
- [ ] 无遗留的 `TODO(release)` / `FIXME(blocker)` 标记

## 二、CI 与测试

- [ ] `release/*` 分支 CI 全绿（lint / commitlint / license / test / golden / build-check）
- [ ] 三平台构建产物均已生成
- [ ] 兼容性测试集（drpy 宿主 API）**全绿**，用例数不少于上一版本
- [ ] 沙箱逃逸测试全部被拦截
- [ ] RPC 分帧模糊测试通过
- [ ] 集成测试（mock 源服务）端到端通过

## 三、数据与兼容

- [ ] 数据库迁移已测试：**从上一个 release 版本的真实库升级**（不是从空库）
- [ ] 迁移失败的回滚路径已验证（人为制造失败）
- [ ] 若 `schemaVersion` 有变更，[compatibility.md](../compatibility.md) 矩阵已更新
- [ ] 若 `protocolVersion` / `manifestVersion` 有变更，同上，且弃用流程已走完
- [ ] 上一版本导出的备份文件能在本版本正确导入

## 四、播放回归

见 [playback-regression.md](playback-regression.md)，需全部通过。

- [ ] 播放回归清单已执行并归档结果

## 五、更新链路

- [ ] 从上一个正式版本自动更新成功
- [ ] 更新失败时能正确回滚到旧版本（模拟下载损坏 / 校验失败 / 替换失败三种）
- [ ] 更新提示中的 changelog 显示正常
- [ ] 用户选择「稍后」后，当前版本功能不受任何影响
- [ ] beta 渠道与 stable 渠道的 feed 各自正确

## 六、安装与卸载

三平台各自验证：

- [ ] Windows MSIX 安装 → 启动 → 卸载，无残留（注册表、`%APPDATA%` 按预期处理）
- [ ] Windows 便携版 zip 解压即用，不写系统目录
- [ ] macOS DMG 安装 → 启动 → 公证验证通过（`spctl -a -v`）
- [ ] Linux AppImage 直接可执行
- [ ] 卸载时**询问**是否删除用户数据，默认保留
- [ ] 全新安装（无历史数据）能正常走完首启引导

## 七、合规（发布门禁）

- [ ] **自动扫描：安装包内不含任何源配置、订阅地址、解析接口**（脚本在 CI 中执行，非人工检查）
- [ ] 首启引导中的免责声明存在且需用户勾选确认
- [ ] README 与「关于」页的合规声明文案一致
- [ ] 开源许可清单已更新，含 **libmpv 与 ffmpeg 的完整许可证文本**
- [ ] libmpv 使用的是 **LGPL 构建产物**且为动态链接（`ldd` / `otool -L` 验证）
- [ ] ffmpeg 未启用 GPL-only 组件
- [ ] 依赖 license 扫描无 AGPL / SSPL
- [ ] 源码获取途径在「关于」页可见（LGPL 要求）

## 八、安全

- [ ] 无硬编码密钥（扫描工具确认）
- [ ] 日志脱敏路径已验证：token、Cookie、Authorization 在日志中确为打码状态
- [ ] 「复制诊断信息」生成的报告已人工检查，无敏感数据泄漏
- [ ] 遥测/崩溃上报**默认关闭**
- [ ] 代码签名完成：Windows Authenticode / macOS 公证
- [ ] `SHA256SUMS` 已生成并签名

## 九、文档

- [ ] `docs/` 中与本次变更相关的部分已更新
- [ ] 新增/变更的 ADR 已提交
- [ ] 若有 API 变更，`sdk/` 下的源作者文档已同步
- [ ] 发布说明中的已知问题列表已更新

## 十、发布

- [ ] GitHub Release 草稿内容检查完毕
- [ ] 产物齐全：MSIX / zip / DMG / AppImage / tar.gz / SHA256SUMS / SHA256SUMS.asc
- [ ] 更新 feed（`latest.json`）在**产物确认可下载后**才更新（顺序不能反）
- [ ] tag 已推送且与 release 对应
- [ ] `release/*` 分支已合回 `main`

---

## 发布后

- [ ] 监控崩溃率 48 小时（目标 < 0.5%）
- [ ] 关注 `source-compat` 类 issue 是否激增（可能意味着兼容层回归）
- [ ] 若发现 P0 问题：**先从 feed 撤下该版本**，再走 hotfix 流程

## 回滚预案

发现严重问题时：

1. 立即把 `latest.json` 回退到上一版本（阻止新用户升级）
2. 在 Release 页标注「已知问题」并说明影响范围
3. 从 release tag 切 `hotfix/vX.Y.Z` 分支修复
4. 修复后同时合回 `release/*` 与 `main`
5. 已升级的用户通过 hotfix 版本前滚，**不提供降级**（数据库不支持降级，见 [compatibility.md](../compatibility.md) §4）
