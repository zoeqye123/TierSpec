# Draft: Open Source Promotion Automation System

## Project Context
- **Main Project**: TierSpec - AI-driven project management tool for Harness/Spec Engineers
- **GitHub**: https://github.com/zoeqye123/TierSpec.git
- **Tech Stack**: TypeScript MCP Server + Swift Mac Client
- **Current State**: Active development, recent commits show workflow and type refinements

## User's Goal (Initial Request)
用户希望创建一个自动化推广系统，利用 Jobs（定时任务）和 Agents（智能体）来推广开源项目到多个渠道。

## User's Vision (Shared Ideas)
用户分享了一个非常完整的愿景，包含四个维度：

### 1. 智能内容生成 (Content Generation Agent)
- 版本发布"故事化"：Twitter/X版、Reddit/HN版、Dev.to/Medium博客版
- 代码片段转Demo动图/卡片
- "竞品"对比生成器

### 2. 多渠道精准分发 (Multi-channel Distribution Jobs)
- 智能时区调度
- Reddit/技术社区"潜伏"投递
- Discord/Slack社区定时播报

### 3. 社区互动与拉新 (Engagement & Growth Agent)
- "Good First Issue"自动广播
- 社交媒体关键词监听与"软广"植入
- 里程碑自动庆祝

### 4. 数据追踪与优化 (Analytics Job)
- 渠道转化率追踪（UTM参数）
- 每日简报

## Open Questions (待澄清)

### Q1: 项目定位
- 这个推广系统是作为 **TierSpec 的一个新功能模块**，还是 **独立的 CLI 工具/服务**？
- 如果是 TierSpec 功能：用户是否需要在 Mac App 内管理推广任务？
- 如果是独立工具：是否需要 MCP Server 架构？

### Q2: 目标渠道优先级
用户提到了很多渠道，但需要确定优先级：
- Twitter/X
- Reddit
- Hacker News
- Dev.to / Medium
- Discord / Slack
- 微信公众号 / 小红书（中文渠道？）

**问题**：用户主要面向哪个市场？英文技术社区还是中文开发者社区？

### Q3: 技术架构偏好
- **Jobs（定时任务）**：用户已有 cron-mastery skill，是否使用 cron/launchd？
- **Agents（智能体）**：是否使用现有的 MCP 架构，还是独立的 Agent 系统？
- **内容生成**：使用哪个 AI API？OpenAI / Anthropic / 其他？

### Q4: 反垃圾策略
用户提到"避免被判定为垃圾邮件"，这很关键：
- Reddit 对硬广非常反感，需要"求反馈"的低姿态语气
- 社交媒体监听需要"极高置信度才触发"
- 是否需要人工审核机制？

### Q5: 数据追踪需求
- 是否需要 Dashboard 展示转化数据？
- 是否需要与 TierSpec 的项目管理功能集成（如：推广任务作为 Sprint Item）？

## Research Needed
- [ ] 查看用户现有的 skills（wechat-publisher, xiaohongshu-publisher）是否可复用
- [ ] 了解 GitHub API 用于监听 Release/Issue/Stars
- [ ] 了解各社交平台的 API 和发布限制
- [ ] 了解 UTM 参数追踪的最佳实践

## Next Steps
1. 澄清上述 Open Questions
2. 确定技术架构方向
3. 确定渠道优先级
4. 讨论反垃圾策略的具体实现