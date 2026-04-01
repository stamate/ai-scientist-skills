# Contributing / 贡献指南

**Language**: [English](#english) | [中文](#中文)

---

## English

Thank you for your interest in contributing to AI Scientist Skills!

### How to Contribute

1. **Fork** the repository and create a new branch from `main`.
2. **Make your changes** — keep commits focused and atomic.
3. **Test** your changes:
   - Ensure all Python tools run without errors: `python tools/<module>.py --help`
   - If you modified a skill, test it with Claude Code: `claude "/ai-scientist:<skill>"`
   - If you modified LaTeX templates, verify they compile: `python tools/latex_compiler.py check`
4. **Submit a Pull Request** with a clear description of what changed and why.

### Commit Style

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add support for new dataset format
fix: correct metric parsing for negative values
docs: update experiment pipeline description
chore: bump PyMuPDF version
```

### What to Contribute

- **Bug fixes** — if something doesn't work, please fix it!
- **New templates** — additional LaTeX conference templates (NeurIPS, AAAI, etc.)
- **Tool improvements** — better metric parsing, faster compilation, etc.
- **Documentation** — typo fixes, clearer explanations, new examples
- **Device support** — testing on new platforms (ROCm, XPU, etc.)

### What to Avoid

- Don't add external LLM API dependencies — Claude Code is the only agent.
- Don't commit experiment outputs (`experiments/` is gitignored).
- Don't add large binary files without discussion.

### Code Style

- Python 3.11+ with type hints
- All tools must work as standalone CLI scripts
- Follow existing patterns in `tools/` for new utilities

### License

By contributing, you agree that your contributions will be distributed under the [AI Scientist Source Code License](LICENSE).

---

## 中文

感谢你对 AI Scientist Skills 项目的关注！

### 如何贡献

1. **Fork** 本仓库，从 `main` 分支创建新分支。
2. **进行修改** — 保持提交聚焦、原子化。
3. **测试**你的修改：
   - 确保所有 Python 工具正常运行：`python tools/<module>.py --help`
   - 如果修改了技能文件，用 Claude Code 测试：`claude "/ai-scientist:<skill>"`
   - 如果修改了 LaTeX 模板，验证编译：`python tools/latex_compiler.py check`
4. **提交 Pull Request**，清晰描述改动内容和原因。

### 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/)：

```
feat: 添加新数据集格式支持
fix: 修复负数指标解析问题
docs: 更新实验流程说明
chore: 升级 PyMuPDF 版本
```

### 欢迎贡献的方向

- **Bug 修复** — 发现问题请修复！
- **新模板** — 新增会议 LaTeX 模板（NeurIPS、AAAI 等）
- **工具改进** — 更好的指标解析、更快的编译等
- **文档完善** — 修正错别字、更清晰的说明、新示例
- **设备支持** — 在新平台上测试（ROCm、XPU 等）

### 请避免

- 不要添加外部 LLM API 依赖 — Claude Code 是唯一的代理。
- 不要提交实验输出（`experiments/` 已被 gitignore）。
- 添加大文件前请先讨论。

### 代码风格

- Python 3.11+，使用类型提示
- 所有工具必须支持独立 CLI 运行
- 新工具请遵循 `tools/` 中的现有模式

### 许可证

提交贡献即表示你同意以 [AI Scientist Source Code License](LICENSE) 分发你的贡献。
