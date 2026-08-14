# QALenz

여러 iOS 프로젝트에서 재사용할 수 있는 XcodeBuildMCP 기반 Simulator QA 도구입니다.

## 로컬 검사

SwiftLint를 Homebrew로 설치합니다.

```sh
brew install swiftlint
```

`Sources`와 `Tests`를 검사합니다.

```sh
./Scripts/lint.sh
```

직접 실행은 `--strict`로 규칙 위반을 실패로 처리합니다.

## Xcode 검사

Xcode에서 `Package.swift`를 연 뒤 다음을 선택합니다.

- scheme: `QALenz-Package`
- 실행 대상: `My Mac`

이 상태에서 build하면 SwiftLint build tool plugin이 `Scripts/lint.sh`를 실행합니다.

SwiftLint가 설치되지 않았으면 build가 실패하고 Homebrew 설치 안내가 표시됩니다. 규칙 위반은 Xcode build error로 표시되며 build는 실패합니다.

## CI 검사

GitHub Actions는 SwiftLint를 설치한 뒤 `Scripts/lint.sh`를 엄격 모드로 직접 실행합니다.

CI의 `xcodebuild`에서는 중복 검사를 피하기 위해 SwiftLint build tool plugin만 건너뜁니다.
