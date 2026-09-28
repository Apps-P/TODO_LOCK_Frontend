# 로컬 전용 + 포기하기 결제 구현 (2026-09-16)

## 적용한 동작

- 앱 로그인/회원가입/로그아웃, Supabase 초기화와 원격 동기화, dotenv 의존성을 제거했다. 기존 Hive todos box 및 필드 번호를 유지하므로 기존 로컬 항목을 계속 읽는다. user_id 필드는 기존 데이터 호환을 위해 남기고 새 항목에는 local을 저장한다.
- 할 일 저장은 메인 Flutter 엔진만 담당한다. 오버레이는 Hive 파일을 직접 열지 않는다.
- 잠금 세션과 검증된 결제 결과는 Android SharedPreferences에 기록한다. 메인 앱이 결과를 Hive에 반영하고 flush한 다음 처리 확인을 기록한다.
- 포기하기는 결제 요청만 한다. PURCHASED 상태, RSA 서명, 앱 패키지, 상품, 요청 세션을 확인한 네이티브 코드가 결과를 기록해야 잠금이 해제된다. 취소/실패/PENDING은 해제하지 않는다.
- 결제 성공 시 done=false, checkTime=null로 돌아간다. 포기한 항목이 원래 종료 시각에 완료되는 문제를 방지한다.
- 결제 토큰별 처리 여부를 기록하고 상품을 consume한다. 중복 응답으로 추가 해제권을 지급하지 않는다. 미소비 결제는 재조회 시 consume을 재시도한다.
- 시간이 먼저 끝난 후 결제가 늦게 확인되면 결제를 버리지 않고 다음 포기 1회로 기기에 보관한다. 다음 포기 요청에서 이 해제권을 사용한다.
- 임시 해제는 기존 3회 흐름을 유지하면서 120초로 맞추고, 횟수와 종료 시각을 로컬 기록해 오버레이 재생성 후에도 복원한다.
- 생성 화면은 현재 목록 날짜를 전달받는다. 빈 내용/공백 및 0분 저장은 경고한다.

## Google Play 설정

2026-09-18 사용자가 일회성 상품 give_up_unlock 생성 및 구매 옵션 활성화를 완료했다고 확인했다. 제공한 Play RSA 공개 키는 형식을 검증한 뒤 Git에서 제외된 .codex/billing.local.json에 설정했다. 실제 Google Play 상품 조회 및 결제는 아직 검증하지 않았다.

1. 실제 앱의 Google Play Console에서 일회성 상품 give_up_unlock을 만들고 구매 옵션을 활성화한다. 이 상품은 코드에서 소비하므로 다음 잠금에서도 다시 구매할 수 있다.
2. 상품 가격과 판매 국가를 Console에서 설정한다. Google 결제창은 스토어에서 조회한 상품 가격을 표시한다. 앱에서 임의 금액을 결제로 전송하지 않는다.
3. 이 앱의 Play 라이선스 RSA 공개 키(Base64)를 확인한다. 서비스 계정 비밀 키나 서명 키 파일을 넣는 위치가 아니다.
4. 아래 예제 JSON을 복사해 값을 채우고 빌드한다.

```json
{
  "GIVE_UP_PRODUCT_ID": "give_up_unlock",
  "PLAY_BILLING_PUBLIC_KEY": "PLAY_CONSOLE_RSA_PUBLIC_KEY_BASE64"
}
```

```powershell
flutter build appbundle --release --dart-define-from-file=.codex/billing.local.json
```

5. Play Console의 앱 패키지 및 서명 설정과 빌드 설정을 맞추고 테스트 트랙/라이선스 테스터 환경에서 확인한다. 2026-09-18 사용자 등록 정보에 맞춰 applicationId/namespace를 com.appsnp.todonlock, 앱 표시 이름을 TODOnLOCK으로 변경했다.

공개 키가 비어 있거나 잘못되면 잠금을 유지하며 설정 안내를 표시한다. 상품 미등록 또는 조회 실패 시에도 잠금을 해제하지 않는다. 검증을 건너뛰는 가짜 성공 경로는 넣지 않았다.

## Android 결제 화면과 잠금 복원

기존 flutter_overlay_window 0.5.0의 소스를 packages/flutter_overlay_window에 보관하고 Google Play Billing 8.3.0과 네이티브 브리지를 추가했다. 원본 LICENSE를 포함했다. 전역 Pub 캐시를 수정하지 않는다.

- 포기 버튼을 누르면 별도 non-exported BillingHostActivity를 연다. 서비스와 잠금 엔진은 계속 살아 있고, 결제창 실행에 성공한 동안만 오버레이 View를 숨긴다.
- BillingHostActivity의 onStop, 결제 Proxy Activity의 onActivityStopped, 결제 화면에서 host로 복귀, 뒤로가기, 취소/오류 콜백에서 네이티브로 오버레이 표시를 복원한다.
- 연결/화면 진입이 끝나지 않으면 30초, 열린 결제창의 결과가 오지 않으면 10분 뒤 복원하는 보조 타임아웃이 있다. 화면 이탈 복원은 이 타이머를 기다리는 방식이 아니다.
- 숨겨진 overlay를 결제 성공으로 취급하지 않는다. 완료 콜백과 실제 영수증 검증/로컬 기록을 별도로 처리한다.
- 앱/오버레이 재시작은 저장된 세션을 읽는다. 백그라운드 서비스의 강제 종료, 권한 철회, Android의 오버레이 차단 보안 화면은 앱이 제어할 수 없다.
- 다른 앱의 전체 화면 결제 인증 등으로 host가 완전히 가려져도 보수적으로 잠금을 복원한다. 기기별 Play UI와 외부 인증 흐름은 출시 전 실기기로 확인해야 한다. 모든 시스템 화면에서 강제 잠금을 보장하는 구현은 아니다.

## 검증 및 남은 외부 작업

검사 결과는 이 문서 아래와 verification.md 최신 기록에 남긴다. 연결된 Android 기기는 adb devices 기준 0대다. 실제 Google Play 결제 성공/취소 및 홈·앱 전환은 실기기에서 검증하지 않았다.

| 실기기 시나리오 | 기대 결과 |
| --- | --- |
| 잠금 → 포기 → Google 뒤로가기/취소 | 잠금 복원, TODO checkTime 유지 |
| Google 결제창 → 홈/최근 앱/다른 일반 앱 | 앱 Activity 종료 감지 후 잠금 복원 |
| 결제 연결 실패/상품 없음/승인 대기 | 잠금 유지 및 안내 |
| 정상 결제 → 앱 복귀/재시작 | 한 번만 해제, checkTime=null, done=false |
| 결제 완료 직후 프로세스 종료 → 재실행 | 저장된 결과 또는 미소비 결제 재조회로 복원 |
| 결제 중 타이머 종료 → 늦은 결제 완료 | TODO 정상 완료, 다음 포기용 해제권 보관 |
| 임시 해제 중 오버레이 재생성 | 남은 120초 기준 시간과 사용 횟수 유지 |

공식 참고:
- [Google Play Billing 통합](https://developer.android.com/google/play/billing/integrate)
- [Google Play Billing 테스트](https://developer.android.com/google/play/billing/test)
- [Android Activity 생명주기](https://developer.android.com/guide/components/activities/activity-lifecycle)
- [오버레이를 차단할 수 있는 보안 화면](https://developer.android.com/security/fraud-prevention/activities)


## 2026-09-16 로컬 전용·결제 연동 후 최종 검사

- flutter pub get: 성공. 인증/Supabase/dotenv 및 관련 전이 의존성 제거. SDK에 맞는 패키지 설정 재생성으로 이전 dot-shorthands 컴파일 오류 해소.
- flutter test --no-pub: 7개 통과. 로컬 저장 재개방, 결제 후 checkTime 초기화, 이전 세션 결과 무시, 취소/오류/승인 대기 상태 유지, 결과 재처리, 복귀 시 잠금 재생성 방지, 중복 결제 버튼 및 취소 UI를 검증.
- :flutter_overlay_window:testDebugUnitTest: 3개 통과. 정상 RSA 서명, 변조된 데이터, 잘못된 키/서명을 검증.
- flutter analyze --no-pub --no-fatal-infos: 종료 코드 0. 오류 0, 경고 0, 기존 유형의 안내 9건(명명 규칙/문서 주석/deprecated API).
- flutter build apk --debug --no-pub: 최종 변경 기준 성공. 산출물 build/app/outputs/flutter-apk/app-debug.apk.
- 병합 manifest: BillingHostActivity exported=false, Play Billing 버전 8.3.0, ProxyBillingActivity의 translucent 테마 확인.
- APK 파일 목록에 .env 및 billing.local.json이 포함되지 않음을 확인.
- git diff --check: 통과. Windows 줄바꿈 변환 안내는 남아 있음.
- 첫 Android 빌드는 dl.google.com DNS 오류가 발생했으나 자동 재시도와 마지막 재빌드는 성공했다.
- 빌드 도구의 기존 Gradle/AGP/Kotlin 버전 지원 종료 예정 안내가 남아 있다. Flutter가 gradle.properties에 추가한 builtInKotlin=false/newDsl=false 호환 설정을 유지했다.
- adb devices: 연결 기기 없음. 실결제/홈/뒤로가기/앱 전환은 미검증. 상품 등록 및 공개 키 설정은 사용자 계정에서 진행해야 한다.

현재 동작과 설정 절차는 billing-setup.md를 참고한다. 위의 최초 조사 결과는 수정 전 이력이다.


## 2026-09-18 Play Console 최초 업로드 준비

- 앱 이름 TODOnLOCK, Android namespace/applicationId com.appsnp.todonlock으로 변경. MainActivity도 새 패키지 경로로 이동.
- 버전 1.0.0+1, target SDK 36.
- flutter build appbundle --release --no-pub 및 flutter build apk --release --no-pub 성공.
- 업로드 파일: build/app/outputs/bundle/release/app-release.aab (56,853,730 bytes).
- jarsigner -verify: jar verified. 자체 서명 인증서 및 타임스탬프 관련 일반 경고가 있으며, 기존 release 업로드 키를 유지했다.
- 병합 manifest에서 패키지/표시 이름/버전을 확인했다. AAB에 .env 및 billing.local.json 파일이 포함되지 않음을 확인했다.
- 사용자 위치: 내부 테스트 → 새 버전 만들기. App Bundle 업로드에서 위 AAB를 선택한다. Play 앱 서명 설정이 나오면 Google 생성 앱 서명 키를 사용할 수 있다.
- 이 빌드는 최초 업로드용이며 상품/PLAY_BILLING_PUBLIC_KEY는 아직 설정되지 않았다. 상품 등록과 공개 키 설정 후 versionCode를 올려 결제 테스트용 AAB를 다시 빌드해야 한다.
- Play Console 업로드/테스트 버전 배포는 수행하지 않았다. 새 패키지 APK의 기기 설치 및 실결제 검증도 아직 수행하지 않았다.


## 2026-09-18 공개 키 연결 및 결제 테스트용 AAB

- 사용자 제공 Base64 RSA 공개 키의 DER 구조, RSA 알고리즘, 2048비트 모듈러스, 공개 지수 65537을 확인했다.
- .codex/billing.local.json에 공개 키와 give_up_unlock을 저장했으며 git check-ignore로 제외를 확인했다. 키 원문은 문서에 복사하지 않았다.
- 사용자 답변으로 상품 생성 및 구매 옵션 활성화를 확인했다. Console 직접 조회는 수행하지 않았다.
- pubspec 버전을 1.0.0+2로 올리고 flutter build appbundle --release --no-pub --dart-define-from-file=.codex/billing.local.json 성공.
- 산출물 build/app/outputs/bundle/release/app-release.aab. jarsigner 검증 성공. 병합 manifest에서 TODOnLOCK / com.appsnp.todonlock / versionCode 2 확인.
- AAB 내 3개 ABI의 libapp.so에 제공한 공개 키 및 give_up_unlock 포함을 확인했다. 원본 billing.local.json 및 .env 파일은 포함되지 않는다.
- 내부 테스트에 버전 2 AAB를 올리고 테스터/라이선스 테스트 계정을 구성한 뒤 Play Store를 통해 설치하여 검증한다. 실제 결제 성공/취소/홈/앱 전환 검증은 여전히 미완료.
- 기존 APK는 버전 1이며 이번에는 AAB만 재빌드했다. 향후 결제용 빌드는 반드시 위 dart-define-from-file 옵션을 포함한다.
