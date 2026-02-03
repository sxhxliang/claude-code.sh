---
name: git
description: Git 版本控制操作，包括提交、分支管理、合并、冲突解决等
---

# Git 版本控制技能

## 功能概述

此技能用于执行 Git 版本控制操作：

- 仓库初始化和克隆
- 提交和历史管理
- 分支创建和合并
- 冲突解决
- 远程仓库操作

## 常用命令

### 基础操作
```bash
# 查看状态
git status

# 查看差异
git diff
git diff --staged

# 添加文件
git add <file>
git add .

# 提交
git commit -m "commit message"

# 查看历史
git log --oneline -10
git log --graph --oneline --all
```

### 分支管理
```bash
# 列出分支
git branch -a

# 创建分支
git branch <branch-name>
git checkout -b <branch-name>

# 切换分支
git checkout <branch-name>
git switch <branch-name>

# 合并分支
git merge <branch-name>

# 删除分支
git branch -d <branch-name>
```

### 远程操作
```bash
# 查看远程
git remote -v

# 拉取更新
git fetch origin
git pull origin main

# 推送
git push origin <branch-name>
git push -u origin <branch-name>
```

### 撤销操作
```bash
# 撤销工作区修改
git checkout -- <file>
git restore <file>

# 撤销暂存
git reset HEAD <file>
git restore --staged <file>

# 撤销提交 (保留修改)
git reset --soft HEAD~1

# 撤销提交 (丢弃修改)
git reset --hard HEAD~1
```

### 高级操作
```bash
# 暂存当前修改
git stash
git stash pop

# 变基
git rebase main
git rebase -i HEAD~3

# 挑选提交
git cherry-pick <commit-hash>
```

## 提交规范

建议使用 Conventional Commits 格式：

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

类型 (type)：
- `feat`: 新功能
- `fix`: 修复 bug
- `docs`: 文档更新
- `style`: 代码格式
- `refactor`: 重构
- `test`: 测试
- `chore`: 构建/工具

## 冲突解决流程

1. 执行 `git status` 查看冲突文件
2. 打开冲突文件，查找 `<<<<<<<` 标记
3. 手动编辑解决冲突
4. `git add <file>` 标记已解决
5. `git commit` 完成合并

## 注意事项

- 提交前先 `git status` 检查
- 避免在 main/master 分支直接开发
- 推送前先拉取最新代码
- 谨慎使用 `--force` 参数
