# PRIVACY_AUDIT — App Privacy 재판정 (항목별, 결론 열어둠)

> 상태: 감사 진행(2026-07-13). 오너 지침 = **"Data Not Collected 깨졌다"고 선결론 금지** — 항목별 판정, 불확실은 Apple 공식 문의로 분리. Connect 단일레코드 등록 **전** 게이트.
> 근거: [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/), [CloudKit private DB](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase).

## 결정적 아키텍처 사실 (grep 검증)
- **외부 전송 = CloudKit private DB 하나뿐.** SwiftPM 외부 의존성 0 · 분석/크래시/추적 SDK 0 · CloudKit 외 네트워크 전송 코드 0 · 서버 0.
- Apple "collect" = 기기 밖 전송으로 **개발자/파트너가 지속 접근** 가능. **private CloudKit = 사용자 본인 iCloud, 개발자 포털 미표시, 개발자 접근 불가** → "allows *you* to access it"에 미해당 = **미수집 방어 가능**.
- ⇒ 3rd-party SDK가 없어 "collect"의 다른 경로가 원천 차단. 이 앱은 미수집 해석이 **가장 강하게 성립**하는 구조.

## 항목별 판정 (전부 private CloudKit only)

| 데이터 | Apple 유형 | 판정 | 근거·비고 |
|---|---|---|---|
| 평가자/점검자 이름 | Contact Info · Name | ⚪**미수집 방어 가능** | 사용자 본인, dev 접근 불가 |
| 현장명·주소 | Contact Info · Physical Address | ⚪**미수집 방어 가능** | 작업현장 주소(개인 자택 아님), dev 접근 불가 |
| 증거 사진 | User Content · Photos | ⚪**미수집 방어 가능**(주의↑) | 인물·차량 포함 가능 → 기록은 방어 가능하나 문서화 |
| 자유 텍스트 기록 | User Content · Other | ⚪**미수집 방어 가능** | dev 접근 불가 |
| **참여자 이름·서명**(LEGAL-2) | Contact Info · Name (+서명) | 🟡**불확실 — 분리** | **제3자 정보**(사용자 본인 아님). 아키텍처는 동일(private CloudKit)이나 3자정보라 보수적으로 Apple 문의 + 한국 PIPA(앱=도구/수탁, 사업주=처리자) 검토 |

## 결론 (열어둠)
- 항목 1~4: private-CloudKit-only + SDK 0 → **"Data Not Collected" 방어 가능.** 단 **판정 근거를 app_privacy_answers에 문서화**(자동 면제라 단정 금지).
- 항목 5(참여자·서명): **최고 주의.** LEGAL-2 착수 시 결정 — Apple 공식 문의 후보 + PIPA. 지금 미리 "수집"으로도 "미수집"으로도 확정 안 함.

## 조치 (Connect 등록 전)
- [ ] `PrivacyInfo.xcprivacy` 매니페스트가 실제(수집 없음·추적 없음·필수 이유 API)와 일치하는지 검증
- [ ] `docs/appstore/privacy_policy`·`docs/privacy-policy.md`가 **CloudKit private 저장**을 정확히 서술하는지(수집 여부와 별개로 "무엇을 어디에 저장하는지"는 고지)
- [ ] `app_privacy_answers` 재작성 — 판정 근거 명시(private CloudKit·dev 접근 불가·SDK 0)
- [ ] 참여자 3자정보(LEGAL-2)는 별도 결정 — Apple 문의 후보로 분리
- ⚠️ 결론 확정 전 Connect 단일레코드 등록 진행 금지(App Privacy 답변이 등록에 필요)

## Apple 공식 문의 후보 (불확실 분리)
1. private CloudKit 전용 저장(개발자 접근 불가)이 사용자 **본인** 데이터에 대해 "not collected"로 답변 가능한가
2. 사용자가 입력하는 **제3자(근로자) 이름·서명**을 private CloudKit에만 저장할 때의 App Privacy 답변
