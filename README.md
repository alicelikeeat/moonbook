# Moonbook · 月下读书

一款用 SwiftUI 构建的本地小说阅读器。无需账号，导入后离线阅读，不接入网络书源。

## 第一版功能

- 从「文件」或其他 App 的「打开方式」导入 TXT / EPUB。
- 书架、重命名、删除；导入后复制原文件到 App 私有目录，源文件移动不影响阅读。
- TXT 支持 UTF-8、带 BOM 的 UTF-16、GB18030，自动识别中文章节及英文 Chapter 标题。
- EPUB 根据 OPF spine 顺序提取 XHTML 正文。
- 上下滚动阅读、章节切换、段落级自动续读、添加和删除书签。
- 字号、行距、纸白 / 暖杏 / 夜读主题；适配 iPhone 和 iPad。

## 在 Mac 上运行

1. 安装 Xcode 16 或更新版本，打开 `Moonbook.xcodeproj`。
2. 等待 Swift Package Manager 下载 ZIPFoundation 0.9.19。
3. 选择 **Moonbook** scheme 和 iOS 17+ 模拟器，点击 Run。
4. 真机运行时，在 Signing & Capabilities 中选择自己的 Team，并改为唯一的 Bundle Identifier。
5. 在模拟器中拖入 TXT / EPUB 到「文件」，再点击书架右上角 `+` 导入。

无需服务器、API Key 或付费账号即可在模拟器上运行。真机安装需要本地签名。

## 验证

项目提供共享 scheme 和 XCTest：覆盖中文章节识别、编码、空文件、长文本、导入后的独立存储以及进度持久化。

```sh
xcodebuild test -project Moonbook.xcodeproj -scheme Moonbook \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

模拟器名称请按本机安装情况调整。GitHub Actions 会自动选择可用的 iPhone 模拟器执行测试，并上传 `.xcresult`。

开发时的 Linux 环境不包含 Xcode 或 iOS SDK，因此未在本地编译或进行真机验证。请以 Actions 或本机 Xcode 的实际结果为准。

## 当前范围

- 单个源文件最多 50 MB；EPUB 单条目最大 20 MB，总解压读取量最大 100 MB。
- EPUB 目前是**纯文字重排**，不展示插图、原书 CSS、复杂表格或固定版式；不支持 DRM。按 spine 分节，暂不读取单独的 nav / NCX 目录。
- 续读和书签精确到段落，不是屏幕像素。TXT 无章节标题时按约 20,000 UTF-16 单位分节。
- 暂不包含左右翻页、iCloud 同步、全文搜索、朗读、应用图标和上架素材。
- 所有书籍和进度在本机保存；系统备份可能包含这些文件。卸载 App 会删除本机数据。

## 目录

`Moonbook/` 为 App 源码，`MoonbookTests/` 为测试，`.github/workflows/ios.yml` 为 macOS CI。

`scripts/generate_project.py` 使用 Python 标准库生成已提交的 Xcode 工程。新增 Swift 文件后运行它更新工程，无需安装额外的工程生成器。
