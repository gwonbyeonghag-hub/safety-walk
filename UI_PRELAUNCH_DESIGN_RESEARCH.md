# SafetyWalk 출시 전 UI 개선 연구

> 조사일: 2026-07-13  
> 범위: iOS + 네이티브 macOS UI 방법론과 기술 선택. 앱 코드 변경 없음.

## 1. 결론

SafetyWalk은 웹 기술로 재작성할 필요가 없다. 가장 안전하고 효과적인 방향은 **HTML/CSS로 빠르게 시각 설계를 탐색하고, 검증된 구조를 기존 SwiftUI macOS 앱에 네이티브 컨트롤로 구현하는 것**이다.

현재 프로젝트는 이미 이 방법의 절반을 수행하고 있다.

- `docs/design/macos-dashboard-mockup.html`에서 CSS 토큰과 반응형 대시보드를 설계했다.
- `SafetyWalkMac/Support/MacDesign.swift`가 해당 색·간격·표면 토큰을 SwiftUI로 옮겼다.
- `MacRootView`는 `NavigationSplitView`, `ReportHubView`는 네이티브 PDF 미리보기와 툴바를 사용한다.
- 공유 도메인·SwiftData·CloudKit·PDF 엔진은 이미 Apple 플랫폼에 맞춰져 있다.

따라서 문제는 "SwiftUI라서 웹처럼 만들 수 없는가"가 아니다. 현재 Mac UI가 카드 외형은 웹 대시보드처럼 정돈됐지만, **데스크톱 작업 도구의 정보 구조와 상호작용**은 아직 충분히 사용하지 않았다는 데 가깝다.

## 2. 현재 화면에서 보이는 구체적 갭

### macOS 대시보드

- 넓은 창에서 네 개 KPI 카드가 가로로 과도하게 늘어나 내부 밀도가 낮다.
- `LazyVGrid(.adaptive(minimum: 340))`와 모든 카드의 `cardBodyHeight = 300` 조합 때문에, 콘텐츠가 적어도 큰 빈 공간이 남는다.
- 4개 업무 카드가 넓은 창에서 `3 + 1`로 배치되어 마지막 "최근 점검" 카드가 아래에 홀로 남는다.
- 색·타이포·위험 칩은 일관되지만, 화면 전체의 시선 흐름은 "무엇을 먼저 처리할지"보다 동일한 카드들의 집합처럼 보인다.

### macOS Browse 화면

- `BrowseLayout`은 모든 섹션을 고정 300pt `List` + 스크롤 상세 카드로 표현한다.
- 프로젝트 전체를 검색한 결과 macOS 화면에는 `Table`, `.searchable`, `.inspector`, `contextMenu`, 주요 키보드 단축키가 거의 없다.
- 현장·점검·위험요인·위험성평가는 날짜, 상태, 위험도, 현장처럼 비교 가능한 속성이 많아 다중 열 표와 정렬에 잘 맞는다.

Apple은 Mac의 큰 화면에서 더 많은 정보를 얕은 계층으로 보여 주고, 창 크기 변경, 표 열 조절, 정렬, 검색, 메뉴와 키보드 작업을 지원하는 것을 권장한다. Apple의 SwiftUI Mac 예제도 복수 속성의 정렬·필터가 필요한 경우 `List` 대신 `Table`을 사용한다.

### iOS

iOS Home의 위험 상태 레일, 큰 점검 시작 버튼, 최근 기록은 이미 "dense-but-calm 현장 도구"라는 페이지 역할에 부합한다. iOS는 Mac과 같은 표 중심 구조로 바꾸지 않는다. 출시 전에는 화면별 구조 재설계보다 글자 위계, 여백, 상태별 일관성, 라이트/다크 및 접근성 회귀 확인이 더 적절하다.

## 3. "웹처럼" 만드는 네 가지 방식 비교

| 방식 | 얻는 것 | 비용·리스크 | SafetyWalk 판단 |
|---|---|---|---|
| **HTML/CSS 목업 → SwiftUI 구현** | CSS Grid처럼 빠른 시각 탐색, 네이티브 성능·접근성·CloudKit 유지 | 목업과 구현을 한 번 옮겨야 함 | **추천. 현재 방식의 확장** |
| **SwiftUI 안에 일부 WebKit 사용** | 복잡한 웹 문서·차트·도움말을 그대로 표시 | Swift↔JS 상태 동기화, 다크모드·현지화·접근성·키보드 QA가 이중화 | 특정 읽기 전용 표면에만 선택적으로 검토 |
| **Mac Catalyst** | iPad 코드 재사용 | 현재 별도 네이티브 Mac 앱보다 AppKit 접근 범위가 좁고, 이미 끝난 구조를 되돌림 | 비추천 |
| **Electron/Tauri 재작성** | HTML/CSS/JS로 전체 UI, Windows/Linux 확장 가능 | UI와 데이터 계층 재작성, SwiftData·CloudKit·PDF·현지화 브리지, 신규 보안·배포 체계 | Apple 동시출시 직전에는 비추천 |

Apple의 WebKit for SwiftUI는 앱 안에 **웹 콘텐츠를 통합**하는 API다. 전체 앱 UI를 웹으로 바꾸라는 설계 지침은 아니다. macOS 14 최소 지원을 유지할 경우 최신 SwiftUI `WebView`에만 의존할 수도 없으므로 기존 `WKWebView` 래핑과 호환성 관리가 필요하다.

Tauri는 macOS에서 시스템 `WKWebView`를 사용하고 JS와 Rust가 메시지로 통신한다. Electron은 Chromium과 Node.js를 앱에 포함한다. 둘 다 좋은 기술이지만, SafetyWalk처럼 이미 SwiftData/CloudKit 공유 모델과 두 개의 Apple 네이티브 앱이 완성된 상황에서는 "외형을 더 좋게" 만들기 위한 도구가 아니라 별도 제품 재개발에 해당한다.

## 4. 추천 Mac 정보 구조

### 대시보드: 카드 수를 늘리지 말고 우선순위를 만든다

1. 상단 KPI는 네 개의 큰 개별 카드 대신 한 개의 compact status strip 또는 낮은 높이의 타일 행으로 축소한다.
2. 1순위 업무인 "미조치 시정조치"를 가장 넓은 주 표면으로 둔다.
3. "현장별 위험 분포"와 "평가 기한"을 좁은 보조 열에 둔다.
4. "최근 점검"은 별도 전폭 행 또는 정해진 보조 열에 배치한다.
5. 화면 폭별 레이아웃을 명시한다. 예: 넓은 창 8:4 두 열, 기본 창 6:6 두 열, 최소 폭 한 열.
6. 모든 카드에 같은 고정 높이를 강제하지 않는다. 같은 행만 정렬하고, 내용량이 다른 섹션은 역할에 맞는 높이를 갖게 한다.

### Browse: 웹 관리 도구의 장점을 Mac 네이티브로 구현한다

권장 구조는 다음과 같다.

`앱 사이드바 | 검색·필터 가능한 Table | 선택 항목 Inspector`

- 점검 표: 현장 / 구역 / 시작일 / 상태 / 진행률
- 위험요인 표: 위험도 / 설명 / 현장 / 위치 / 시정 상태 / 수정일
- 위험성평가 표: 현장 / 기법 / 종류 / 평가일 / 기한 상태
- 열 머리글 정렬, 열 폭 조절, 선택 유지, 빈 상태를 지원한다.
- 검색은 `.searchable`로 툴바에 둔다.
- 위험도·상태 필터는 툴바의 `Menu` 또는 segmented control로 둔다.
- 상세는 `.inspector`로 오른쪽에 표시하고, 사용자가 숨기거나 폭을 바꿀 수 있게 한다.
- 자주 쓰는 명령만 툴바에 두고, 모든 명령은 메뉴와 키보드에서도 찾을 수 있게 한다.
- 읽기 전용 앱이라도 복사, PDF 열기, 선택 항목 보기 같은 문맥 메뉴는 유용하다.

이 구조는 웹 SaaS의 밀도와 비교성을 얻으면서도 macOS의 선택 상태, 메뉴, 키보드, 접근성, 창 복원을 그대로 사용한다.

## 5. 권장 디자인 방법론

### 단계 A — 화면을 만들기 전에 비교 가능한 시안을 만든다

대표 화면 하나를 고른다. SafetyWalk에서는 `위험요인 Browse`가 적합하다. 위험도·상태·현장·날짜를 모두 포함해 정보 구조의 품질을 판별하기 쉽기 때문이다.

같은 실제 샘플 데이터를 넣고 다음 세 시안을 HTML/CSS로 만든다.

1. **Operations Table**: 표 중심, 필터와 우측 인스펙터.
2. **Inbox + Detail**: 우선순위 큐 중심, 한 건씩 처리.
3. **Dashboard + Drill-down**: 요약 밴드와 하단 표의 조합.

브랜드를 세 번 다시 디자인하지 않는다. 동일한 색·타입·위험 칩 토큰을 쓰고 정보 구조만 경쟁시킨다.

### 단계 B — 시안을 감상이 아니라 업무로 평가한다

각 시안에서 아래 질문을 실제로 수행한다.

- 5초 안에 가장 높은 미조치 위험을 찾을 수 있는가?
- 특정 현장의 진행중 시정조치만 두 번 이내 조작으로 볼 수 있는가?
- 한 행을 선택한 채 다음 행과 비교할 수 있는가?
- 1040×680, 1440×900, 초광폭 창에서 과도한 빈 공간이나 잘림이 없는가?
- populated / empty / single item / long text / error 상태가 모두 자연스러운가?
- light / dark, 한국어 / 영어에서 위계가 유지되는가?

이 평가 후 오너가 한 시안을 확정하기 전에는 SwiftUI 구현을 시작하지 않는다.

### 단계 C — 한 화면만 네이티브로 옮겨 기술 검증한다

- 새 프레임워크나 의존성을 추가하지 않는다.
- 기존 `SafetyWalkCore`, `@Query`, CloudKit 모델은 변경하지 않는다.
- `Table`, `.searchable`, `.inspector`, `Toolbar`, `Commands` 같은 macOS 14 지원 SwiftUI 기능을 먼저 사용한다.
- SwiftUI로 표현하기 어려운 한정된 기능이 확인될 때만 AppKit 브리지를 사용한다.
- HTML 목업의 픽셀을 복제하기보다 정보 우선순위와 토큰을 보존한다.

### 단계 D — 스크린샷 회귀 루프

각 화면을 다음 매트릭스로 캡처한다.

- 폭: 최소 / 기본 / 넓음
- 외형: light / dark
- 언어: ko / en
- 데이터: empty / populated / long text
- 상호작용: 선택 없음 / 선택됨 / 필터 적용 / inspector 열림

평가 기준은 hierarchy, density, scanability, alignment, contrast, truncation, keyboard reachability, VoiceOver label이다. 앱 전체로 확산하기 전에 대표 화면에서 이 매트릭스를 통과한다.

## 6. 출시 전과 출시 후의 경계

### 출시 전 권장 범위

- HTML/CSS 시안 2~3개 제작 및 오너 확정
- Mac 대시보드의 `3 + 1` 카드 배치와 과도한 고정 높이 개선
- 대표 Browse 화면 한 곳에 Table + 검색 + Inspector를 구현해 방향 검증
- iOS는 구조 변경 없이 시각 회귀 확인
- 기존 빌드, CloudKit, PDF, 현지화, 접근성 회귀 테스트

### 출시 후 확장 범위

- 검증된 Browse 패턴을 나머지 현장·점검·위험성평가 화면에 확산
- 사용자 지정 열, 다중 선택, 문맥 메뉴, 키보드 명령, 창별 상태 복원
- 실제 필요가 확인될 때 차트 또는 읽기 전용 문서 영역에만 WebKit 검토
- Windows/web 제품이 사업 목표로 확정될 때에만 Tauri/Electron을 별도 아키텍처 결정으로 재평가

## 7. 권장 의사결정

1. **네이티브 SwiftUI 유지**
2. **웹은 구현 기술이 아니라 시각 프로토타이핑 도구로 사용**
3. **Mac 대표 화면을 Table + Inspector 구조로 먼저 검증**
4. **대시보드는 카드 외형보다 우선순위와 반응형 조합을 재설계**
5. **출시 전에는 한 화면의 성공을 확인한 뒤 확산 여부 결정**

## 8. 공식 출처

- Apple HIG, Designing for macOS: 큰 화면의 정보 밀도, 창 조절, 메뉴와 키보드 지원  
  https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/
- Apple HIG, Lists and tables: Mac 다중 열 표의 정렬, 열 크기 조절, 교차 행 가독성  
  https://developer.apple.com/design/human-interface-guidelines/lists-and-tables
- Apple, SwiftUI on the Mac: Build the fundamentals: sidebar, Table, search, toolbar, windows, commands  
  https://developer.apple.com/videos/play/wwdc2021/10062/
- Apple SwiftUI Navigation: `NavigationSplitView`와 다중 열 내비게이션  
  https://developer.apple.com/documentation/swiftui/navigation
- Apple SwiftUI Tables: 선택·정렬 가능한 행/열 데이터  
  https://developer.apple.com/documentation/swiftui/tables
- Apple SwiftUI Inspector: 문맥에 따라 trailing column 또는 compact presentation 제공  
  https://developer.apple.com/documentation/swiftui/view/inspector(isPresented:content:)
- Apple SwiftUI Search: macOS 툴바 검색 배치  
  https://developer.apple.com/documentation/swiftui/adding-a-search-interface-to-your-app
- Apple SwiftUI Menu/Commands and keyboard shortcuts  
  https://developer.apple.com/documentation/swiftui/building-and-customizing-the-menu-bar-with-swiftui
- Apple, WebKit for SwiftUI: SwiftUI 앱에 웹 콘텐츠 통합  
  https://developer.apple.com/documentation/webkit/webkit-for-swiftui
- Apple, Mac Catalyst: iPad 앱을 Mac으로 가져오는 기술과 AppKit 사용 범위  
  https://developer.apple.com/documentation/uikit/mac-catalyst
- Electron 공식 문서: Chromium + Node.js를 포함한 HTML/CSS/JS 데스크톱 앱  
  https://www.electronjs.org/docs/latest/
- Tauri 공식 문서: 시스템 WebView와 웹 프런트엔드, JS↔Rust 메시지 구조  
  https://v2.tauri.app/start/  
  https://v2.tauri.app/concept/architecture/
