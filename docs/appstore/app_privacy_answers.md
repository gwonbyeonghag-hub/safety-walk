# App Privacy 설문 답안 (App Store Connect) — SafetyWalk v2

Connect **"앱 개인정보 보호"** 설문에 그대로 입력할 답안 + 근거. 소스 검증 2026-07-10
(`PrivacyInfo.xcprivacy`, 엔타이틀먼트, 코드: 네트워킹은 **CloudKit뿐**, 분석·광고·크래시 SDK 0,
`import Photos`/카메라 API 0, 스위프트 패키지 의존성은 SafetyWalkCore 1개뿐).

> **v1 대비 변경점(중요)**: v2는 **CloudKit 비공개 DB 동기화**와 **StoreKit 구독**을 추가했습니다.
> 아래는 그에 맞춰 갱신된 답안입니다. CloudKit 데이터 수집 항목은 **오너 최종 확인 권장**(주석 참조).

## 1. 추적(Tracking)
- **사용자를 추적합니까?** → **아니오.**
  ATT·IDFA·`AdSupport`·제3자 분석/광고 없음. `NSPrivacyTracking = false`,
  `NSPrivacyTrackingDomains` 비어 있음.

## 2. 데이터 수집(Data Collection)
- **개발자 또는 제3자 파트너가 이 앱에서 데이터를 수집합니까?** → **권장: "데이터를 수집하지 않음".**
  - 근거(Apple 정의 = 개발자가 **수신/접근하는** 데이터):
    - 점검·위험요인·위험성평가·구역·점검자 이름 = 기기 저장 + **사용자 본인 iCloud 비공개
      데이터베이스(CloudKit Private DB)** 동기화. 이 데이터는 **사용자 소유·Apple 운영**이며
      **개발자는 접근/수신할 수 없습니다.** Apple 지침상, 개발자가 접근하지 않는 사용자 개인
      iCloud(비공개 DB) 데이터는 개발자의 "수집"에 해당하지 않습니다.
    - 증거 사진 = 앱 샌드박스 저장(+ 위 iCloud 동기화). 사진 보관함 직접 접근 없음(PHPicker).
    - 서버·백엔드 없음. 앱 자체의 네트워킹은 **CloudKit(사용자 iCloud)뿐**이며 분석/텔레메트리 전송 없음.
  - `NSPrivacyCollectedDataTypes`는 **비어 있음**(정확).
  <!-- 오너 확인: CloudKit 비공개 DB만 사용하고 개발자가 접근하지 않으므로 "수집 안 함"이 정확합니다.
       다만 심사원이 iCloud 동기화를 이유로 데이터 유형 선언을 요청하면, 아래 "만약 선언 시" 표를
       사용하고 모두 **"앱 기능"** 목적 · **추적 안 함** · **연결 안 함(Not linked)** 으로 답하세요.
       (개인정보처리방침 URL에 iCloud 동기화가 이미 명시돼 있어 투명성은 확보됨.) -->

  - **(만약 선언을 요청받을 경우) 데이터 유형별 답** — 모두 "앱 기능" 목적 · 추적 안 함 · 사용자 신원에 연결 안 함:
    | 데이터 유형 | 목적 | 비고 |
    |---|---|---|
    | 기타 사용자 콘텐츠(점검/위험/평가 기록·사진) | 앱 기능 | 사용자 본인 iCloud 비공개 DB, 개발자 접근 불가 |
    | 이름(점검자명, 사용자가 입력) | 앱 기능 | 보고서 표기·기기/개인 iCloud 저장 |

## 3. 구매(Purchases) / 구독
- **구매 이력을 수집합니까?** → **아니오(개발자 수집 없음).**
  SafetyWalk Pro는 자동 갱신 구독으로, **결제·갱신·구매 이력은 Apple(App Store)이 처리**합니다.
  앱은 온디바이스에서 구독 활성 여부(`Transaction.currentEntitlements`)만 확인해 기능 잠금/해제에
  사용하며, 구매 이력이나 결제 정보를 **수집·전송·저장하지 않습니다.** 서버 영수증 검증 없음.

## 4. 필수 사유 API(Required-reason API)
- `PrivacyInfo.xcprivacy`에 **UserDefaults → `CA92.1`** 하나만 선언(앱 자체 defaults 읽기/쓰기).
  파일 타임스탬프·디스크 공간·부팅 시각·활성 키보드 API 미사용.
  <!-- 확인 필요: CloudKit/StoreKit 도입으로 추가 필수-사유 API가 생기지 않았는지 재점검.
       현재 코드 기준 추가 없음(네트워킹은 CloudKit 프레임워크가 담당, required-reason 대상 아님). -->

## 5. 암호화 수출 규정(Export Compliance)
- 앱은 **표준 암호화만**(HTTPS/iCloud 전송) 사용하고 독자 암호화를 구현하지 않음 → 통상 **면제**.
  - 권장: `Info.plist`에 **`ITSAppUsesNonExemptEncryption = NO`** 추가(현재 키 없음 → 매 업로드 시
    Connect가 질문함). 오너가 Info.plist에 추가하거나 Connect에서 "아니오"로 답하면 됨. *(코드 로직
    무변경 · 선택)*

## 요약 (Connect 입력값)
- 추적: **아니오** · 데이터 수집: **수집 안 함**(CloudKit 비공개 DB=사용자 소유, 개발자 접근 불가)
- 구매 이력: 개발자 수집 없음(Apple 처리) · 제3자 SDK/광고/분석: 없음
- 필수 사유 API: UserDefaults `CA92.1` · 암호화: 면제(`ITSAppUsesNonExemptEncryption=NO` 권장)
