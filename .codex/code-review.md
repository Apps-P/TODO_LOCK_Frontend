# 코드 조사 및 요구사항 대조

기준: 2026-09-16 / Git `95284fe`. 모든 경로는 저장소 루트 기준이다. 아래의 구현 상태는 소스 확인 결과이며 실기기 검증 결과가 아니다.

## 구조와 데이터 흐름

| 위치 | 역할 |
| --- | --- |
| `lib/main.dart` | 한국어 날짜 포맷, Hive, dotenv, Supabase 초기화, 시작 동기화, 날짜 기반 라우트. 별도 `overlayMain()` 진입점과 오버레이 데이터 리스너. |
| `lib/models/todo_model.dart`, `todo_model.g.dart`, `duration_adapter.dart` | Hive Todo 모델 및 직렬화 어댑터. |
| `lib/views/edit/edit_create_view.dart` | 내용·날짜·시간·잠금 선택, 생성/수정, 날짜 이동 시 순번 재정렬. |
| `lib/views/main/main_view.dart`, `app_bar.dart` | 메인 화면, 오늘/내일 전환, 메뉴, 인증 상태, 생성 버튼, 광고. |
| `lib/views/main/todo/view.dart`, `func.dart` | 날짜별 목록, 순서 변경, 스와이프 삭제, 타이머, 상태색, 체크 및 오버레이 시작. |
| `lib/views/calendar/calender.dart` | 월별 자체 캘린더와 날짜별 라우팅. 파일명은 현재 `calender.dart`. |
| `lib/views/lock/lock_overlay_view.dart`, `lock_ui.dart`, `temp_ui.dart` | 잠금/임시 해제 상태, 잔여 시간, 3회 제한, 종료 시 Hive 저장. |
| `lib/sync_service.dart` | Supabase 최초 업로드, 시작 시 병합, 단건 upsert/delete. |
| `lib/views/setting/auth_page.dart`, `setting.dart` | 이메일 회원가입/로그인, Google 로그인 코드, 오버레이 권한 설정 및 복귀 시 갱신. |
| `lib/views/main/achievement.dart`, `banner.dart` | 업적 Placeholder, 배너 광고 위젯. |
| `lib/theme/` | 색상, Paperlogy 테마, 애니메이션 토글. |
| `android/app/src/main/AndroidManifest.xml` | 오버레이·foreground service·인터넷 권한, overlay service, 광고 앱 ID. |

앱 시작은 초기화 → `SyncService.syncOnStartup()` → todos box 열기 → `runApp()` 순서다. 로그인된 경우 동기화가 첫 화면 전에 실행된다. `.env`에서 `SUPABASE_URL`, `ANON_KEY`를 읽으며 예외 시 로컬 화면으로 복구하는 시작 흐름은 없다.

### 저장 모델

| Hive 필드 | 타입 | 의미 |
| --- | --- | --- |
| 0: id | String | UUID |
| 1: user_id | String | 로컬 생성 시 `user_1`; 원격 전송은 현재 로그인 ID로 치환 |
| 2: date | DateTime | 할 일 날짜 |
| 3: no | int | 해당 날짜 정렬 순번 |
| 4: content | String | 내용 |
| 5: lock | bool | 잠금 여부 |
| 6: checkTime | DateTime? | 시작 시각 |
| 7: duration | Duration | 할 일 시간 |
| 8: done | bool | 완료 여부 |

Todo typeId=0, Duration typeId=100이고 Duration은 밀리초로 저장된다. `date`, `no`, `user_id`는 생성자 밖에서 채우는 late 필드다. 새 객체 생성 시 이 값을 채우지 않으면 저장 때 실패할 수 있다. 현재 생성·원격 로드 경로는 값을 채운다.

저장소는 Hive box `todos` 하나다. 로컬 생성은 `add()`로 정수 키를 사용하고 원격 다운로드는 `put(todo.id, todo)`로 문자열 키를 사용한다. UUID와 Hive 키가 항상 같다고 가정하면 안 된다. 어댑터 필드 번호/typeId 변경은 기존 데이터 호환성을 검토해야 한다.

Supabase `todos` 매핑에는 `check_time` UTC 시각, `date` 날짜 문자열, `duration` HH:MM:SS interval이 사용된다. 실제 DB schema/RLS/migration 파일은 확인한 저장소 파일 목록에 없고 서버 설정은 조회하지 않았다.

## 요구사항별 상태

| ID | 코드 상태 | 차이 및 누락 |
| --- | --- | --- |
| FR-001 | 기본 생성/수정 및 기존 값 로드 구현 | 빈 내용은 경고 없이 return. 공백 문자열과 0분 허용. 잠금 토글은 bool만 변경. 권한 설명 팝업 없음. 저장은 JSON 대신 Hive. |
| FR-002 | 날짜 필터, 정렬/순서 변경, 스와이프 삭제, 상태색과 초 단위 갱신 구현 | 카드 클릭 대신 편집 아이콘. 진행/완료 항목 편집 차단. 재체크 초기화는 lock=false만 가능. 잠금 진행 항목 삭제 차단. |
| FR-003 | 오늘/내일 토글, Drawer, 월별 캘린더 날짜 이동 구현 | 생성 및 캘린더 진입 시 현재 선택 날짜 전달 누락. 주별 진행도 없음. 설정은 명세보다 확장되어 실제 권한 확인/요청 수행. |
| FR-004 | Android 오버레이, 권한 확인, 잔여 시간, 임시 해제/복귀, 횟수 제한 구현 | 시작 2차 확인 없음. 긴급 해제 120초 대신 100초. 추가 결제 없음. 별도 진행률/중단 결과 화면 없음. 즉시 포기 버튼 존재. |
| FR-005 | 메뉴와 라우트만 존재 | 메뉴는 업데이트 예정 안내, 화면은 Placeholder. 달성 판정/저장/팝업/공유 없음. |
| FR-006 | 미구현 | 잠시 해제/포기 모두 2단계 이미지 모달 없이 실행. 3회 이후 버튼 비활성만 있고 초과 안내 메시지 없음. |

Android와 web 폴더는 존재하지만 iOS 폴더는 없다. Android 외 플랫폼을 위한 잠금/광고 분기 구현도 확인되지 않았다. 따라서 목표 플랫폼 Android/iOS가 모두 구현됐다고 볼 수 없으며 web 폴더 존재만으로 웹 동작을 보장하지 않는다.

## 우선 확인할 문제

아래 순서는 코드 근거에 따른 후속 작업 제안이다. 재현하지 않은 위험은 명시적으로 구분했다.

### 1. 포기한 잠금 TODO가 다시 완료될 수 있는 상태 흐름

- 근거: `lib/views/lock/lock_overlay_view.dart`의 `onGiveUp()`, `_saveTodoCompletion()`은 done=false만 저장하고 checkTime을 유지한다.
- `lib/views/main/todo/func.dart`의 `updateTodoStatus()`는 checkTime이 있고 done=false이면 계속 시간 경과를 계산해 자동 완료한다.
- 잠금 항목은 `view.dart`에서 checkTime이 있으면 재시작도 return한다.
- 예상 영향: 포기 후 여전히 진행 중으로 보이거나 원래 종료 시각에 완료 처리될 수 있다. 포기 후 상태 정책 확정과 메인/오버레이 동기화 검증이 필요하다.

### 2. 계정별 로컬 데이터 구분과 동기화 충돌 기준 부재

- 근거: `sync_service.dart`의 `_dumpLocalToSupabase()`와 `_merge()`는 box 전체를 사용하고 `_toRow()`는 모든 행의 user_id를 현재 로그인 사용자 ID로 바꾼다. 로그아웃은 `main_view.dart`에서 auth.signOut()만 호출한다.
- 예상 영향: 계정 A 사용 후 B로 전환하면 A의 로컬 항목이 B 화면에 남고 B 계정으로 업로드가 시도된다. 서버의 실제 허용/거부 여부는 RLS에 따라 달라지며 미확인이다.
- 동일 UUID는 무조건 Hive 우선으로 원격을 덮어쓴다. 수정 시각/version 충돌 판정이 없어 다른 기기의 최신 변경을 덮어쓸 가능성이 있다.
- 제안: 계정/게스트 데이터 귀속 정책, 충돌 기준, 실패 재시도 상태를 정의한다.

### 3. 오프라인 삭제 후 원격 항목 재유입 가능성

- 근거: `view.dart`의 `_onDelete()`는 로컬 삭제 후 원격 삭제를 호출한다. `SyncService.deleteTodo()`는 오류를 로그로만 남기며 삭제 대기 기록이 없다.
- `_merge()`는 원격에만 남은 UUID를 로컬에 추가하므로 원격 삭제 실패 후 재시작하면 항목이 되살아날 수 있다.
- 제안: 삭제 기록과 재시도 큐를 둔 뒤 재연결/재시작 시나리오로 확인한다.

### 4. 선택 날짜에서 생성해도 오늘 날짜가 기본값

- 근거: `main_view.dart`의 생성 버튼은 인자 없이 `/create` 이동. `main.dart:167`은 initialDate를 DateTime.now()로 고정한다.
- 재현 경로: 내일 또는 캘린더의 다른 날짜 → + → 날짜 기본값 확인.
- `/calendar`도 오늘로 생성되어 현재 목록 날짜의 월/선택을 이어받지 못한다.

### 5. 동기화 호출이 빠진 사용자 동작

- 생성 경로는 Hive `add()`만 호출한다. 수정은 `pushTodo()`를 호출한다.
- 로그인 성공 후 `syncOnStartup()` 호출이 없다. 현재 이 메서드 호출 위치는 `main()` 한 곳이다.
- 드래그 순서 변경, 삭제 후 나머지 항목 순번 변경, 날짜 이동 후 이전 날짜 순번 재정렬은 로컬 저장만 한다.
- 영향: 즉시 원격 반영을 기대하는 경우 새 항목·순번·로그인 후 목록이 다음 시작 동기화까지 반영되지 않을 수 있다.

### 6. 오버레이와 앱의 상태 일관성 — 실기기 검증 필요

- 오버레이가 별도 진입점에서 Hive box를 닫고 다시 열어 직접 저장한다. 메인으로 완료/포기 이벤트를 전달하고 메인 box 캐시를 갱신하는 경로는 없다. 디스크 flush만으로 두 실행 컨텍스트의 UI 동기화 성공을 단정할 수 없다.
- `_onFinished()`는 저장 완료 후 타이머를 취소한다. 저장이 1초 이상 걸리는 동안 완료 처리가 중복 진입할 여지가 있다.
- TODO 시작을 기록한 뒤 `isActive()`를 검사한다. 기존 오버레이가 있는 경우 새 TODO만 시작 상태가 되고 해당 오버레이가 생성되지 않을 수 있다.
- `showOverlay()` 실패 시 시작 상태 롤백이 없고, 데이터 공유 수신 확인/재전송도 없다.
- 임시 해제 시간은 tick마다 1초 감소하므로 지연/백그라운드 시 실제 경과 시간과 어긋날 수 있다. 횟수는 메모리 상태이며 재시작 후 유지되지 않는다.
- 제안: 저장 주체와 종료 이벤트 경로를 정하고 생성 실패, 프로세스 재시작, 완료·포기 동시 처리, 임시 해제 복귀를 검증한다.

### 7. 입력 검증과 사용자 확인 누락

- `_onSave()`에서 빈 내용 안내가 없고 trim/양수 duration 검증도 없다. 0분 TODO를 시작하면 다음 tick에 완료될 수 있다.
- 편집 화면의 잠금 선택은 권한 검사 없이 토글된다. 실제 요청은 목록 시작 또는 설정에서 직접 시스템 설정으로 이동한다.
- 잠금 시작 확인, 해제 2단계 경고, 초과 메시지는 구현돼 있지 않다.

## 기타 유지보수 및 실행 환경 메모

- `OverlayDataHandler`의 overlayListener와 `MainView`의 인증 이벤트 구독은 저장/취소되지 않는다. 화면 수명에 맞춘 구독 해제가 필요하다.
- 편집 TextEditingController의 dispose가 없고 일부 비동기 UI 작업에 mounted 검사가 없다.
- Google 로그인 client ID는 `YOUR_...` placeholder다. 이메일 인증도 실제 서버 동작은 미검증이다.
- 배너는 코드 주석상 테스트 ad unit ID를 사용한다. 이번 조사에서 광고 요청이나 서버 변경은 실행하지 않았다.
- `android/app/build.gradle.kts`는 `key.properties`를 조건 없이 읽는다. 현 워크스페이스에는 파일이 있지만 Git에서 제외되므로 새 checkout의 빌드 재현에 영향을 줄 수 있다. 값은 읽거나 기록하지 않았다.
- `test/widget_test.dart`는 기본 카운터 테스트로 실제 앱과 맞지 않으며 Hive/Supabase/날짜 포맷 초기화 없이 MyApp을 띄운다.
- JSON으로의 전환, iOS 구현, 결제 추가는 이번 조사에서 수행하지 않았다. 기존 동작을 고려한 후속 범위 결정이 필요하다.

## 후속 작업 제안 순서

1. 현재 검사 결과를 확인하고 실제 TODO 동작을 검증할 테스트 환경 구성.
2. 날짜 전달, 필수 입력 검증, 포기 상태 전이 수정.
3. 계정 데이터 분리, 삭제 재시도, 누락 동기화 및 충돌 기준 정리.
4. Android 기기에서 오버레이 시작/완료/포기/임시 해제/재시작 검증 및 수정.
5. 해제 시간·횟수·확인 정책 구현, 이후 낮은 우선순위 업적·공유·캐릭터 모달 작업.
