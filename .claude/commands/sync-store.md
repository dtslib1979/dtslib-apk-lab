# Sync Store Metadata

pubspec.yaml을 기준으로 모든 앱 메타데이터를 동기화해주세요.

## 작업 순서

1. **버전 정보 수집**: 각 앱의 `pubspec.yaml`에서 버전 추출
   - apps/capture-pipeline/pubspec.yaml
   - apps/laser-pen-overlay/pubspec.yaml
   - apps/aiva-trimmer/pubspec.yaml
   - apps/tts-factory/pubspec.yaml

2. **app-meta.json 동기화**: 각 앱 폴더의 app-meta.json 버전을 pubspec.yaml과 일치시킴
   - 버전 형식: `v{major}.{minor}.{patch}` (build number 제외)

3. **dashboard/apps.json 동기화**: 스토어 페이지에 표시되는 버전 정보 업데이트

4. **브랜드 이름 확인**: 모든 앱 이름이 Parksy 브랜드 규칙을 따르는지 확인
   - capture-pipeline → "Parksy Capture"
   - laser-pen-overlay → "Parksy Pen"
   - aiva-trimmer → "Parksy AIVA"
   - tts-factory → "Parksy TTS"

5. **Android 라벨 확인**: AndroidManifest.xml의 android:label이 브랜드 이름과 일치하는지 확인

6. **변경사항 보고**: 동기화된 내용을 테이블 형식으로 보고

## 출력 형식 예시

| 앱 | pubspec | app-meta | apps.json | Android | 상태 |
|---|---|---|---|---|---|
| capture-pipeline | 5.0.0 | v5.0.0 | v5.0.0 | Parksy Capture | ✓ |
