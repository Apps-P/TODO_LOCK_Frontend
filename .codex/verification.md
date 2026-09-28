# 검증 기록

기준일: 2026-09-16. 기준 커밋: `95284fe`.

## 확인 범위

- `lib/`의 모델, 화면, 테마, 동기화 코드와 생성 어댑터를 읽었다.
- pubspec/lock, 테스트, Android manifest/앱 빌드 설정/Activity, 저장소 상태와 플랫폼 디렉터리를 확인했다.
- 조사 시작 시 `git status --short` 출력은 비어 있었다.
- 저장소와 확인한 상위 경로에서 AGENTS.md는 발견되지 않았다.
- 설치된 SDK 캐시 메타데이터는 Flutter 3.44.6 / Dart 3.12.2를 기록하고 있다. pubspec의 Dart 제약은 ^3.9.2다.
- `.env`, `android/key.properties`의 존재만 확인하고 값은 읽지 않았다.

## 자동 검사

검사 실행 결과는 아래에 기록한다. 앱 소스 수정, 의존성 업데이트, 어댑터 재생성은 이번 작업 범위가 아니다.

## 후속 재현 시나리오

아래 항목은 이번 조사에서 실행하지 않았다. 예상 동작을 확인하기 위한 후속 목록이다.

| 시나리오 | 확인할 결과 |
| --- | --- |
| 오늘/내일/임의 날짜 → + → 저장 → 앱 재시작 | 선택 날짜 전달 및 로컬 보존 |
| 빈 내용/공백/0분 저장 | 사용자 경고와 저장 차단 |
| 일반 TODO 시작 → 재체크 → 다시 시작 → 시간 완료 | checkTime/done 및 배경색, 남은 시간 |
| 순서 변경·날짜 변경·스와이프 삭제 후 재시작 | 순번 및 저장 일관성 |
| 권한 미허용 → 잠금 시작 → 설정 복귀 | 권한 안내, 시작 전 확인, 실패 시 미시작 유지 |
| 잠금 중 포기 → 앱 복귀 → 원래 종료 시각 경과 | 포기 항목이 자동 완료되지 않는지 |
| 임시 해제 1~3회와 4회 요청 | 현재 100초 동작, 요구사항 120초와 차이, 횟수 제한 및 안내 |
| 해제 중 TODO 완료 / 백그라운드 / 프로세스 재시작 | 오버레이 닫힘·재잠금·상태 복구 |
| 로그인 직후 생성·수정·순서 변경 | 원격 반영 시점 |
| 오프라인 삭제 → 재접속 → 앱 재시작 | 삭제한 항목의 재생성 여부 |
| 계정 A → 로그아웃 → 계정 B | 계정별 목록과 업로드 귀속 |
| 두 기기에서 같은 항목 수정 후 순차 재접속 | 충돌 시 데이터 보존 기준 |

실기기 오버레이, 앱 빌드, Supabase 연결/RLS, 이메일/Google 로그인, 광고, 결제, iOS 동작은 검증하지 않았다. 파일 존재 또는 소스 구현을 실행 성공으로 해석하지 않는다.

### flutter analyze --no-pub

- 종료 코드 1. 총 14건: error 0 / warning 3 / info 11.
- 경고: lib/main.dart:34의 미사용 supabase 변수, lib/views/main/todo/view.dart:11의 미사용 import, 같은 파일 27행의 미사용 _activeOverlayId.
- 안내: withOpacity 및 onReorder deprecated 사용, 명명 규칙, 불필요 import, dangling doc comment, edit_create_view.dart:112의 비동기 구간 이후 BuildContext 사용.
- 코드 오류가 보고되지는 않았지만 경고/안내가 남아 명령은 성공 종료하지 않았다.

### flutter test --no-pub

- 테스트 로드/컴파일 단계 실패: Some tests failed, 성공 0건. 테스트 본문에 도달하지 못했다.
- 오류는 Flutter SDK의 C:/flutter/packages/flutter/lib/src/rendering/paragraph.dart 3502행 및 3527행에서 발생했다.
- 메시지: This requires the experimental 'dot-shorthands' language feature to be enabled. 해당 문법은 boxHeightStyle: .max 이다.
- SDK와 기존 패키지 설정의 언어 버전 정합성을 후속 확인할 필요가 있다. 정확한 원인은 이번 조사에서 확정하지 않았다. 의존성 재해석이나 SDK 변경을 수행하지 않았다.
- 별도로 기존 테스트가 카운터 예제인 점은 파일을 읽어 확인했다. 실제 assertion 실패를 관측했다는 뜻은 아니다.

### 실행 환경 제약

- 최초 sandbox 실행에서는 SDK 외부 캐시 잠금 단계에서 출력 없이 진행되지 않아 중단하고 승인된 권한으로 분석/테스트를 실행했다.
- 이후 일부 sandbox 도구가 setup refresh had errors로 실패해 문서 기록과 최종 파일 확인은 권한 확장으로 수행했다.


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
