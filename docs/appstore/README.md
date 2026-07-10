# App Store 제출 패키지 — SafetyWalk v2 (WO-6 · WO-6b)

계정 없이 준비 가능한 **제출 자료 풀세트**. App Store Connect 업로드·제출은 오너 단계(§오너 체크리스트).
코드/모델/버전 무변경(1.0 / build 1). 소스 검증 2026-07-10(WO-6) · 스크린샷 갱신 2026-07-10(WO-6b).

## 구성
| 파일 | 내용 |
|---|---|
| `metadata_ko.md` / `metadata_en.md` | 앱명·부제·프로모션·설명(위험성평가·iCloud·구독 반영)·키워드·카테고리·연령·URL |
| `privacy_policy.md` | 게시용 개인정보처리방침(ko/en) — **v2: iCloud 동기화 반영, "완전 오프라인" 문구 폐기** |
| `app_privacy_answers.md` | Connect "앱 개인정보 보호" 설문 답 + 근거(CloudKit 비공개 DB·구독) |
| `review_notes.md` | 심사 메모(ko/en) — 계정 불필요·iCloud 선택·구독 테스트법·면책 위치 |
| `screenshots.md` + `screenshots/` | **규격 그대로 업로드 가능**: iPhone 6.9"(1320×2868) 6장+다크 2장 · iPad 13"(2064×2752) 1장 · macOS(2880×1800) 대시보드+리포트 허브 각 라이트/다크. iPad "위험성평가" 화면은 미확보(알려진 제약, `screenshots.md` 참고) |

## 앱 사실(요약)
- iOS `com.gwonbyeonghag.safetywalk` · macOS `com.gwonbyeonghag.safetywalk.mac`
- 버전 **1.0** / 빌드 **1** · iOS **17**+ / macOS **14**+ · iPhone·iPad·Mac
- iCloud 컨테이너 `iCloud.com.gwonbyeonghag.safetywalk`(비공개 CloudKit)
- 구독 그룹 **SafetyWalk Pro** · `com.gwonbyeonghag.safetywalk.pro.monthly` / `.yearly`
- 네트워킹 = CloudKit뿐(분석·광고·크래시 SDK·제3자 패키지 0) · 사진=라이브러리 첨부(인앱 카메라 없음)

## 아카이브 검증 (이번 WO)
- **iOS `xcodebuild archive` → ARCHIVE SUCCEEDED** (코드 무결성, `CODE_SIGNING_ALLOWED=NO`).
- **macOS `xcodebuild archive` → ARCHIVE SUCCEEDED**.
- 배포 서명·업로드는 오너(Xcode Organizer). 코드 원인 실패 없음.

---

## §오너 체크리스트 (Connect — 실행자 자료 검수 후)

1. **앱 등록**: developer.apple.com → Identifiers에 두 번들ID 확인 → App Store Connect → "나의 앱" →
   ＋ 신규 앱 **2건**(iOS `com.gwonbyeonghag.safetywalk` / macOS `com.gwonbyeonghag.safetywalk.mac`,
   기본언어 ko, SKU 자유).
2. **구독 상품 등록**(신규 · WO-10): Connect → 해당 앱 → **앱 내 구입 → 자동 갱신 구독** →
   구독 그룹 **"SafetyWalk Pro"** 생성 → 상품 2개 등록:
   `com.gwonbyeonghag.safetywalk.pro.monthly`(월간) / `...pro.yearly`(연간) → **가격·구독 표시명·심사
   스크린샷** 설정. 앱 **최초 심사 시 구독도 함께 제출**(구독 미승인 시 앱 심사가 막힘).
3. **법적 링크 채우기**(코드 1커밋 · WO-10 잔여): `LegalLinks.terms` / `LegalLinks.privacy`
   (`현장 안전 지킴이/Utilities/LegalLinks.swift`)에 게시한 이용약관·개인정보 URL 2개 입력 → 재빌드/아카이브.
   (현재 nil이면 페이월에서 두 라벨이 비활성 플레이스홀더로 표시됨.)
4. **개인정보처리방침·지원 URL 게시**: `privacy_policy.md`(+ `docs/support.md`)를 공개 URL(GitHub Pages 등)로
   게시 → 두 앱에 URL 입력. `app_privacy_answers.md`대로 "앱 개인정보 보호" 설문 작성.
5. **메타데이터·스크린샷 업로드**: `metadata_ko/en.md` 붙여넣기 · 가격 무료(구독은 IAP) ·
   스크린샷은 `screenshots.md` 규격으로. 카테고리=비즈니스 · 연령=4+ · 저작권=오너명.
6. **암호화 수출**: `ITSAppUsesNonExemptEncryption = NO`(Info.plist 추가 권장 또는 Connect에서 "아니오").
7. **빌드 업로드·제출**: Xcode → Product → Archive(타깃별) → Organizer → Distribute → 업로드 →
   빌드 연결 → `review_notes.md` 붙여넣기 → **두 앱 동시 제출**.
