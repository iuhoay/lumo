# Lumo

Send selected text to [Lumo](https://iuhoay.dev/lumo/), a menu-bar app that translates, polishes, or summarizes it.

Install Lumo.app first. Download [Lumo.zip](https://github.com/iuhoay/lumo/releases/latest/download/Lumo.zip), unzip it, and move `Lumo.app` to `/Applications`. The app is not notarized, so clear the quarantine flag once before the first launch:

```sh
xattr -dr com.apple.quarantine /Applications/Lumo.app
```

Then select text and use **Translate**, **Polish**, or **Summarize** in the PopClip bar. Provider, model, API key, and languages are set in the app, not in this extension.

## Privacy

This extension does not contact a server. It passes the selected text to Lumo.app on this Mac: in a `lumo://` URL, or via the clipboard when the selection is longer than 6000 characters. Lumo then sends that text to the provider you configured — OpenAI, Claude, DeepSeek, another OpenAI-compatible host, or local Ollama — unless you choose Apple's on-device model, which stays on the Mac.

## Requirements

- PopClip 2024.5 (build 4578) or later
- macOS 26 or later, for Lumo.app
- Lumo.app installed

## 中文

先安装 [Lumo.app](https://iuhoay.dev/lumo/)。应用未公证，首次打开前执行一次：

```sh
xattr -dr com.apple.quarantine /Applications/Lumo.app
```

选中文字后点 PopClip 栏的**翻译**、**润色**或**总结**。服务商、模型和语言在 app 的设置里配置。选中文字只交给本机的 Lumo.app；是否发到第三方，取决于你在 app 里选的服务商。选 Apple 端侧模型则不离开这台 Mac。

## Changelog

- 2026-10-10: Initial directory submission.
