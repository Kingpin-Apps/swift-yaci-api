# Installation

Add SwiftYaciAPI to your package or Xcode project.

## Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Kingpin-Apps/swift-yaci-api", from: "0.1.0")
]
```

Then add the library to your target:

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "SwiftYaciAPI", package: "swift-yaci-api")
    ]
)
```

## Xcode

1. **File → Add Package Dependencies…**
2. Enter `https://github.com/Kingpin-Apps/swift-yaci-api`
3. Choose a version rule and add `SwiftYaciAPI` to your target

## Platform Requirements

| Platform | Minimum |
| --- | --- |
| iOS | 14.0 |
| macOS | 13.0 |
| watchOS | 7.0 |
| tvOS | 14.0 |

The package requires Swift 6.0 or later.

## Dependencies

SwiftYaciAPI builds on Apple's OpenAPI packages:

- [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) — generates the client at build time
- [swift-openapi-runtime](https://github.com/apple/swift-openapi-runtime) — the runtime the generated code uses
- [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) — the default `URLSession` transport

The client is generated from `Sources/SwiftYaciAPI/openapi.yaml` by a build-tool plugin, so no generated code is checked in. The first build takes noticeably longer than later ones.
