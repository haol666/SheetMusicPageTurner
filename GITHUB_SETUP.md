# GitHub 仓库设置指南

## 1. 在 GitHub 上创建新仓库

1. 登录 GitHub 账号
2. 点击右上角的 "+", 选择 "New repository"
3. 填写仓库信息：
   - Repository name: `SheetMusicPageTurner`
   - Description: 智能面部识别乐谱自动翻页工具
   - 选择 Public 或 Private
   - 不要勾选 "Initialize this repository with a README"
   - 点击 "Create repository"

## 2. 推送本地代码到 GitHub

在终端中执行以下命令：

```bash
# 添加远程仓库
git remote add origin https://github.com/haol666/SheetMusicPageTurner.git

# 推送代码
git push -u origin master
```

将 `your-username` 替换为你的 GitHub 用户名。

## 3. 设置 GitHub Actions 编译项目

1. 在 GitHub 仓库页面，点击 "Actions" 标签
2. 点击 "Set up a workflow yourself"
3. 将以下内容复制到编辑器中，替换默认内容：

```yaml
name: iOS Build

on:
  push:
    branches: [ master ]
  pull_request:
    branches: [ master ]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '14.3'
    
    - name: Build
      run: |
        cd SheetMusicPageTurner
        xcodebuild -project SheetMusicPageTurner.xcodeproj -scheme SheetMusicPageTurner -destination 'platform=iOS Simulator,name=iPhone 14' build
```

4. 点击 "Start commit"
5. 填写 commit 信息，如 "Add GitHub Actions workflow"
6. 点击 "Commit new file"

## 4. 查看构建结果

1. 推送代码到 GitHub 后，GitHub Actions 会自动开始构建
2. 在仓库的 "Actions" 标签中可以查看构建进度和结果
3. 如果构建成功，会显示绿色的对勾；如果失败，会显示红色的叉号，并提供错误信息

## 注意事项

- GitHub Actions 构建需要使用 macOS 环境，这可能会消耗较多的构建时间
- 由于 iOS 应用需要签名才能部署到设备，GitHub Actions 构建的应用只能在模拟器中运行
- 如果你需要构建可部署的应用，需要在 GitHub Actions 中配置签名证书和描述文件
