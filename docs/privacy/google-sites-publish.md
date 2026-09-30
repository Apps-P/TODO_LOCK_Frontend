# Google Sites 게시 절차

현재 상태: 문안과 로컬 미리보기만 작성됨. Google Sites에 사이트 생성/게시 및 공개 URL 확인은 수행하지 못함.
원인: 브라우저 자동화 런타임이 helper_unknown_error: setup refresh had errors / trusted Node process exited unexpectedly로 실행되지 않음. 사용자 승인 거절이 아님.

1. https://sites.google.com/new 를 열고 빈 사이트를 만든다.
2. 사이트 이름: TODOnLOCK. 페이지 제목: 개인정보처리방침.
3. 삽입 → 텍스트 상자를 선택한다. privacy-policy.txt 전체를 복사해 붙여넣는다. 또는 privacy-policy.html을 브라우저에서 열고 본문 복사 버튼을 사용한다. HTML 파일을 임베드하거나 파일 첨부로 대체하지 않는다.
4. 게시 → 웹 주소에 todonlock-privacy 또는 appsnp-todonlock-privacy를 시도한다. 주소 사용 가능 여부는 확인되지 않았다.
5. 공유 → 게시된 사이트를 공개로 설정한다. 편집 권한을 공개하는 것이 아니다.
6. 게시된 사이트 보기에서 실제 URL을 복사한다. 편집기 URL이나 예상 URL은 Play Console에 넣지 않는다.
7. 로그아웃/시크릿 창에서 로그인 없이 본문이 보이고 이메일 링크가 맞는지 확인한다.
8. Play Console → 앱 콘텐츠 → 개인정보처리방침에 게시된 URL을 등록한다. 현재 앱 설정에 이 URL을 여는 항목도 추가해야 한다(이번 작업에서는 앱 코드를 수정하지 않음).

## 문안 기준 및 확인할 사항

- 기준: 2026-09-30 현재 코드, 앱 버전 1.0.0+4. 사용자 확인 운영자명 AppsnP / 문의 이메일 hanyusmail0707@gmail.com.
- 할 일과 사용 가이드는 Hive, 잠금/결제 상태는 Android SharedPreferences. 자체 인증/동기화 서버 없음.
- 결제는 원본 구매 토큰을 처리하고, 중복 적용 방지용 해시값과 요청/세션/설치 식별값 등을 보관. 단순히 개인정보를 전혀 수집하지 않는다고 표시하지 않음.
- 광고 테스트 ID를 쓰더라도 Google 광고 SDK의 정보 처리 설명을 생략하지 않음. 별도 분석 SDK가 없다는 사실을 SDK 자체 분석이 없다는 뜻으로 확대하지 않음.
- Android 백업 차단 설정이 없으므로 앱 제거만으로 모든 백업이 삭제된다고 약속하지 않음.
- 문의 메일을 목적 달성 후 삭제한다는 문안이므로 실제 메일 운영도 이에 맞춰야 함. 국외 처리·보유 기간·아동 대상 여부·서비스 국가에 따른 추가 요건은 실제 운영 및 Google 계약/계정 설정과 대조해야 함. 앱 코드만으로 법적 준수나 스토어 승인을 확정할 수 없음.
- 현재 설정 화면에는 개인정보처리방침 링크가 없으며 광고 동의 UI(UMP)도 확인되지 않음. 사이트 작성은 앱 내 고지·동의나 Play 데이터 보안 양식을 대신하지 않음.

## 근거

- Google Play 사용자 데이터 정책: https://support.google.com/googleplay/android-developer/answer/10144311?hl=ko
- Google Mobile Ads SDK 데이터 공개: https://developers.google.com/admob/android/privacy/play-data-disclosure
- Google 개인정보처리방침: https://policies.google.com/privacy?hl=ko
- Google Sites 게시 및 공유: https://support.google.com/sites/answer/6372880?hl=ko
