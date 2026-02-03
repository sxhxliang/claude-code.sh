---
name: pdf
description: PDF 文件处理，包括提取文本、合并、拆分、转换等操作
---

# PDF 处理技能

## 功能概述

此技能用于处理 PDF 文件，支持以下操作：

- 提取 PDF 文本内容
- 合并多个 PDF 文件
- 拆分 PDF 页面
- PDF 转图片
- 图片转 PDF

## 常用工具

### 使用 pdftotext 提取文本
```bash
# 安装 (macOS)
brew install poppler

# 提取文本
pdftotext input.pdf output.txt

# 保留布局
pdftotext -layout input.pdf output.txt
```

### 使用 pdftk 合并/拆分
```bash
# 安装 (macOS)
brew install pdftk-java

# 合并 PDF
pdftk file1.pdf file2.pdf cat output merged.pdf

# 提取特定页面
pdftk input.pdf cat 1-5 output pages1-5.pdf

# 拆分为单页
pdftk input.pdf burst
```

### 使用 ImageMagick 转换
```bash
# 安装 (macOS)
brew install imagemagick

# PDF 转图片
convert -density 150 input.pdf output.png

# 图片转 PDF
convert image1.png image2.png output.pdf
```

### 使用 qpdf 处理
```bash
# 安装 (macOS)
brew install qpdf

# 解密 PDF
qpdf --decrypt input.pdf output.pdf

# 压缩 PDF
qpdf --linearize input.pdf output.pdf
```

## 使用示例

当用户请求 PDF 相关操作时：

1. 首先确认文件路径和所需操作
2. 检查必要工具是否已安装
3. 执行相应命令
4. 验证输出结果

## 注意事项

- 处理大文件时注意内存使用
- 某些加密 PDF 可能无法直接处理
- 图片转换时注意 DPI 设置影响质量
