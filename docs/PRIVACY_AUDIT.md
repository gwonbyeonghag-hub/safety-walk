# PRIVACY_AUDIT — DRAFT (초안 완료 · 공식 판정/owner 결정 대기)

> 상태: **DRAFT / pending owner decision or Apple confirmation.** "Data Not Collected"는 **방어 가능한 잠정안**일 뿐, 공식 확인/owner 판단 전 확정 아님.
> **게이트 성격**: App Store **최종 제출** 게이트. **ASC 앱 레코드 생성 자체는 막지 않음**(그건 WO-A 번들/Universal Purchase 구조가 게이트).
> 근거: [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/), [CloudKit private DB](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase).

## 두 축을 분리한다 (오너 교정 #1)
**Apple ASC "collection"과 한국 PIPA는 별개 축.** 섞지 말 것.

| 축 | 기준 | 이 앱 |
|---|---|---|
| **① Apple ASC 수집** | **개발자/파트너가 지속 접근 가능한가** (본인/제3자 무관) | private CloudKit = 사용자 전용·개발자 접근 불가 → **모든 데이터 동일하게 미수집 방어 가능** |
| **② 한국 PIPA** | 제3자 개인정보 처리의 **권한·고지·보존·삭제 책임** | 참여자(근로자) 이름·서명 = 제3자 → PIPA 부담 ↑ (앱=도구/수탁, 사업주=처리자). **ASC 판정과 무관** |

## 결정적 아키텍처 사실 (grep 검증)
외부 전송 = **CloudKit private DB 하나뿐**. SwiftPM 외부 의존성 0 · 분석/크래시/추적 SDK 0 · 서버 0. → "collect"의 다른 경로 원천 차단.

## 항목별 — ① ASC 판정 (전부 동일 논리)
> 모든 지정 이름 필드는 **본인이라는 보장 없음**(현장 관리자가 타 근로자 이름 입력 가능, 교정 #2) → 전부 같은 방식으로 분류.

| 데이터 | Apple 유형 | ASC 판정(잠정) | 근거 |
|---|---|---|---|
| 평가자·점검자·담당자 이름 | Contact Info · Name | ⚪미수집(방어 가능) | private CloudKit·dev 접근 불가 |
| 참여자 이름(LEGAL-2) | Contact Info · Name | ⚪미수집(방어 가능) | **동일 논리** — 제3자여도 ASC 축은 같음 |
| **서명 이미지·필기**(교정 #3) | **Other User Content** | ⚪미수집(방어 가능) | private CloudKit·dev 접근 불가 |
| 현장명·주소 | Contact Info · Physical Address | ⚪미수집(방어 가능) | 작업현장 주소 |
| 증거 사진 | User Content · Photos | ⚪미수집(방어 가능) | private CloudKit |
| 자유 텍스트 | User Content · Other | ⚪미수집(방어 가능) | private CloudKit |

## 항목별 — ② PIPA (제3자 참여자만 별도 부담)
- 참여자·서명 = 제3자 개인정보 → **입력 권한·고지·보존(3년)·삭제·열람** 책임. 앱은 도구/수탁, 사업주가 처리자.
- 산출물: 개인정보처리방침에 제3자 정보 처리·CloudKit 저장·보존/삭제 서술. (ASC "수집 없음" 답변과 별개)

## 잠정 결론 & 조치
- ① ASC: "Data Not Collected" **방어 가능한 잠정안** — 공식 확인/owner 확정 전 단정 금지.
- 조치(최종 제출 전): `PrivacyInfo.xcprivacy` 매니페스트 검증 · `privacy_policy`가 CloudKit private 저장 + 제3자 처리 서술 · `app_privacy_answers` 근거 명시.
- **레코드 생성은 막지 않음** — WO-A 후 진행 가능.

## Apple 공식 문의 후보 (불확실 분리)
1. private CloudKit 전용(개발자 접근 불가) 저장이 "not collected" 답변 가능한가
2. 사용자가 입력하는 **제3자 이름·서명**의 App Privacy 답변
