# 2026-09-18 TODO 정렬 및 배너 위치 수정

## 변경

- lib/views/main/todo/view.dart: ReorderableListView의 기본 proxyDecorator가 카드 바깥 여백까지 불투명 Material로 감싸므로 흰 사각형 전체가 들리는 현상이 있었다. 투명 Material을 반환하는 proxyDecorator로 바꿔 둥근 카드의 기존 배경과 그림자만 보이게 했다. 항목 키와 순서 저장, 슬라이드 삭제 로직은 그대로 유지했다.
- lib/views/main/banner.dart: 광고가 로드된 경우 SafeArea(top: false) 안에 배치하여 3버튼 내비게이션/제스처 및 가로 화면의 시스템 영역을 피하도록 했다. Center(heightFactor: 1)로 표준 배너 크기를 유지하며 중앙 정렬한다. 로드 전에는 기존처럼 공간을 차지하지 않는다.
- pubspec.yaml: Play 내부 테스트 업데이트용 버전을 1.0.0+3으로 증가했다.

## 검증

- dart format: 수정한 Dart 파일 2개 적용.
- flutter analyze --no-pub --no-fatal-infos: 성공, 오류/경고 0개, 기존 유형의 info 9개.
- 실제 기기의 드래그 화면 및 내비게이션 버튼/제스처 모드에서의 배너 위치는 아직 시각 검증하지 않았다.
- flutter build appbundle --release --no-pub --dart-define-from-file=.codex/billing.local.json: 성공. 산출물 build/app/outputs/bundle/release/app-release.aab.
- jarsigner 서명 검증 성공. 병합 manifest의 com.appsnp.todonlock / versionCode 3 확인. AAB 내 3개 ABI의 libapp.so에 결제 공개 키와 상품 ID 포함 확인.
- Play Console 업로드는 수행하지 않았다.
