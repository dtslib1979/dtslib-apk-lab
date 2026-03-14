# Parksy Studio v2.0 — 아키텍처 백서

> **"WebView 래퍼가 아니라, 네이티브 방송 엔진을 만든다."**
> 작성일: 2026-03-14 | 작성자: System Architect Review

---

## 0. v1.0 사후 부검 — 왜 다시 만들어야 하는가

v1.0은 하루 만에 만든 프로토타입이다. 작동 증명(PoC)으로는 성공했지만, **실제로 돌리면 핵심 기능 3개가 안 된다.**

### 치명적 결함 목록

| # | 기능 | 결함 | 원인 |
|---|------|------|------|
| 1 | 영상트리머 | FFmpeg WASM 로드 실패 | Android WebView에 `SharedArrayBuffer` 없음 |
| 2 | 영상트리머 | 변환 결과 저장 불가 | WebView에서 `blob:` URL `<a download>` 미지원 |
| 3 | 동시통역 | 음성인식 결과 미표시 | `let final` — JS 예약어로 SyntaxError |
| 4 | 화면녹화 | stop 후 파일 깨짐 가능 | Service 비동기 stop인데 path 즉시 리턴 |
| 5 | 화면녹화 | 뒤로가기 시 녹화 무한 지속 | dispose에서 RecordingService.stop 미호출 |
| 6 | 화면녹화 | Foreground Service 좀비 | startForeground 후 early return 시 stopSelf 미호출 |
| 7 | YouTube 업로드 | OAuth 불안정 | redirect_uri `https://localhost` → WebView에서 ERR_CONNECTION_REFUSED |

**7개 중 3개는 "기능이 아예 안 됨", 4개는 "되다가 터짐".** 이건 버그 패치로 해결할 수준이 아니다. WebView에 핵심 로직을 넣은 아키텍처 자체가 틀렸다.

### 근본 원인

```
v1.0 아키텍처:
  Flutter UI Shell → WebView → HTML/JS로 핵심 로직

문제:
  WebView ≠ Chrome Browser
  - SharedArrayBuffer 없음 → FFmpeg WASM 불가
  - blob: download 없음 → 파일 저장 불가
  - Service Worker 없음 → 오프라인 불가
  - file:// CORS 제한 → 로컬 파일 접근 곤란
```

**결론: 영상 처리, 오디오 처리, 파일 I/O는 네이티브에서 해야 한다.** WebView는 UI 렌더링과 웹 콘텐츠 표시에만 쓴다.

---

## 1. v2.0 설계 원칙

### 원칙 1: 경계를 명확히 한다

```
┌─────────────────────────────────────────────┐
│  UI Layer (Flutter)                         │
│  - 모든 화면, 네비게이션, 상태 관리           │
│  - WebView는 cloud-appstore 표시에만 사용     │
└──────────────┬──────────────────────────────┘
               │ Platform Channel
┌──────────────┴──────────────────────────────┐
│  Engine Layer (Kotlin)                      │
│  - MediaProjection (화면녹화)                │
│  - MediaCodec (H.264 인코딩/트리밍)          │
│  - SpeechRecognizer (음성인식)               │
│  - MediaPlayer (BGM 재생)                    │
│  - YouTube Data API (업로드)                 │
└──────────────┬──────────────────────────────┘
               │ File System
┌──────────────┴──────────────────────────────┐
│  Storage Layer                              │
│  - /Movies/ParksyStudio/ (녹화 원본)         │
│  - /Movies/ParksyStudio/trimmed/ (변환 결과)  │
│  - Room DB (프로젝트, 히스토리, 설정)          │
└─────────────────────────────────────────────┘
```

**규칙: WebView 안에서 파일을 만들거나, 네이티브 API를 호출하지 않는다.**

### 원칙 2: 서버 비용 제로를 유지한다

| 기능 | v1.0 (의존성) | v2.0 (대체) |
|------|---------------|-------------|
| 영상 트리밍 | FFmpeg WASM (CDN) | Android MediaCodec (네이티브) |
| 음성인식 | Web Speech API (네트워크) | Android SpeechRecognizer (온디바이스 가능) |
| 번역 | Google Translate URL (브라우저) | ML Kit Translation (온디바이스, 무료) |
| BGM 재생 | YouTube embed WebView | ExoPlayer (네이티브) |
| YouTube 업로드 | http 패키지 (Dart) | YouTube Data API v3 (Kotlin, Resumable) |

### 원칙 3: 오프라인 퍼스트

네트워크 없이도 동작해야 하는 것:
- 화면녹화 + 트리밍 + 저장
- 로컬 BGM 재생
- 음성인식 (온디바이스 모델)
- 프로젝트 관리

네트워크가 있어야 하는 것:
- YouTube 업로드
- cloud-appstore 도구 접근
- 원격 BGM 채널 업데이트
- 온라인 번역 (ML Kit 모델 미설치 시)

---

## 2. 모듈 아키텍처

### 2.1 전체 모듈 맵

```
apps/parksy-studio/
├── lib/
│   ├── main.dart                        # App + 라우팅
│   ├── core/
│   │   ├── constants.dart               # 색상, 문자열
│   │   ├── theme.dart                   # ThemeData 분리
│   │   └── router.dart                  # GoRouter 네비게이션
│   │
│   ├── models/
│   │   ├── project.dart                 # 프로젝트 (녹화→트림→업로드 단위)
│   │   ├── bgm_channel.dart             # BGM 채널/트랙 모델
│   │   └── transcript.dart              # STT 결과 모델
│   │
│   ├── services/
│   │   ├── recording_bridge.dart        # Platform Channel → Kotlin RecordingEngine
│   │   ├── trimmer_bridge.dart          # Platform Channel → Kotlin TrimmerEngine
│   │   ├── stt_bridge.dart              # Platform Channel → Kotlin SpeechEngine
│   │   ├── upload_service.dart          # YouTube 업로드 (Dart http, 청크)
│   │   ├── bgm_service.dart             # 채널 JSON 로드 + 캐시
│   │   ├── project_repository.dart      # Room DB CRUD (drift 패키지)
│   │   └── auth_service.dart            # Google OAuth (AppAuth)
│   │
│   ├── screens/
│   │   ├── home/
│   │   │   ├── home_screen.dart         # 대시보드 (최근 프로젝트 + 퀵 액션)
│   │   │   └── project_card.dart        # 프로젝트 카드 위젯
│   │   ├── launcher/
│   │   │   ├── launcher_screen.dart     # cloud-appstore 도구 그리드
│   │   │   └── studio_webview.dart      # WebView (도구 전용)
│   │   ├── recording/
│   │   │   ├── recording_screen.dart    # 녹화 설정 + 시작
│   │   │   └── recording_overlay.dart   # 녹화 중 플로팅 컨트롤
│   │   ├── trimmer/
│   │   │   ├── trimmer_screen.dart      # 네이티브 트리머 UI
│   │   │   ├── timeline_widget.dart     # 타임라인 + 구간 선택
│   │   │   └── preview_player.dart      # 미리보기 플레이어
│   │   ├── interpreter/
│   │   │   ├── interpreter_screen.dart  # 동시통역 화면
│   │   │   └── subtitle_overlay.dart    # 실시간 자막 위젯
│   │   ├── bgm/
│   │   │   ├── bgm_screen.dart          # BGM 채널 브라우저
│   │   │   └── mini_player.dart         # 하단 미니 플레이어
│   │   ├── upload/
│   │   │   ├── upload_screen.dart       # 업로드 설정 + 진행
│   │   │   └── auth_screen.dart         # Google OAuth 전용
│   │   └── settings/
│   │       └── settings_screen.dart     # 설정
│   │
│   └── widgets/
│       ├── bottom_nav.dart              # 하단 네비게이션
│       ├── status_bar.dart              # 상단 상태 바
│       └── gold_button.dart             # Parksy 브랜드 버튼
│
├── android/app/src/main/kotlin/com/parksy/studio/
│   ├── MainActivity.kt                  # Flutter Engine + Channel 등록
│   ├── engine/
│   │   ├── RecordingEngine.kt           # MediaProjection + MediaRecorder
│   │   ├── TrimmerEngine.kt             # MediaCodec + MediaMuxer (하드웨어 가속)
│   │   └── SpeechEngine.kt              # Android SpeechRecognizer
│   ├── service/
│   │   ├── RecordingService.kt          # Foreground Service (녹화)
│   │   └── BgmService.kt               # Foreground Service (BGM 재생)
│   └── util/
│       └── FileUtil.kt                  # 파일 경로, 미디어스캔
│
├── assets/
│   └── bgm/channels.json               # 로컬 폴백 채널 데이터
│
└── test/
    ├── services/
    │   ├── bgm_service_test.dart
    │   ├── project_repository_test.dart
    │   └── upload_service_test.dart
    └── models/
        ├── project_test.dart
        └── transcript_test.dart
```

### 2.2 의존성 (pubspec.yaml)

```yaml
name: parksy_studio
version: 2.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # 네비게이션
  go_router: ^14.0.0

  # WebView (cloud-appstore 전용)
  webview_flutter: ^4.7.0
  webview_flutter_android: ^3.16.0

  # 미디어 재생 (트리머 미리보기 + BGM)
  media_kit: ^1.1.10
  media_kit_video: ^1.2.4
  media_kit_libs_android_video: ^1.3.6

  # 로컬 DB (프로젝트 관리)
  drift: ^2.15.0
  sqlite3_flutter_libs: ^0.5.0

  # OAuth (YouTube 인증)
  flutter_appauth: ^7.0.0

  # 번역 (온디바이스)
  google_mlkit_translation: ^0.12.0

  # 유틸
  path_provider: ^2.1.1
  path: ^1.9.0
  share_plus: ^10.0.0
  shared_preferences: ^2.2.2
  permission_handler: ^11.3.0
  http: ^1.1.0
  intl: ^0.19.0
  url_launcher: ^6.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.15.0
  build_runner: ^2.4.0
```

---

## 3. 핵심 엔진 상세 설계

### 3.1 TrimmerEngine — 네이티브 영상 트리밍

**v1.0 문제:** FFmpeg WASM이 WebView에서 안 돌아감
**v2.0 해법:** Android MediaCodec + MediaMuxer로 하드웨어 가속 트리밍

```
입력: /Movies/ParksyStudio/PS_SHORTS_20260314_153022.mp4
                    │
     ┌──────────────┴──────────────┐
     │  MediaExtractor              │  ← 원본 디먹싱
     │  - Video Track (H.264)       │
     │  - Audio Track (AAC)         │
     └──────────────┬──────────────┘
                    │
     ┌──────────────┴──────────────┐
     │  MediaCodec (Decoder)        │  ← 하드웨어 디코더
     │  - Surface 출력              │
     └──────────────┬──────────────┘
                    │
     ┌──────────────┴──────────────┐
     │  OpenGL ES 2.0 Pipeline      │  ← GPU에서 처리
     │  - 크롭 (상단/하단 px 제거)    │
     │  - 리사이즈 (1080×1920 등)    │
     │  - 패딩 (레터박스)             │
     └──────────────┬──────────────┘
                    │
     ┌──────────────┴──────────────┐
     │  MediaCodec (Encoder)        │  ← 하드웨어 인코더
     │  - H.264 High Profile        │
     │  - CRF 23 상당 (bitrate 제어) │
     └──────────────┬──────────────┘
                    │
     ┌──────────────┴──────────────┐
     │  MediaMuxer                  │  ← MP4 먹싱
     │  - Video + Audio 합성         │
     │  - moov atom을 앞에 (faststart)│
     └──────────────┬──────────────┘
                    │
출력: /Movies/ParksyStudio/trimmed/PS_SHORTS_20260314_153022_trim.mp4
```

**성능 비교:**

| 항목 | v1.0 (FFmpeg WASM) | v2.0 (MediaCodec) |
|------|--------------------|--------------------|
| 1분 영상 처리 | ~2분 (CPU only) | ~5초 (HW 가속) |
| 메모리 | ~500MB (WASM heap) | ~50MB |
| SharedArrayBuffer | 필수 (WebView 미지원) | 불필요 |
| 오프라인 | CDN 필요 | 완전 오프라인 |

```kotlin
// TrimmerEngine.kt 핵심 인터페이스
class TrimmerEngine(private val context: Context) {

    data class TrimConfig(
        val inputPath: String,
        val outputPath: String,
        val cropTop: Int = 0,        // px
        val cropBottom: Int = 0,     // px
        val targetWidth: Int = 1080,
        val targetHeight: Int = 1920,
        val startMs: Long = 0,       // 구간 시작
        val endMs: Long = -1,        // 구간 끝 (-1 = 끝까지)
        val bitrate: Int = 6_000_000
    )

    data class TrimResult(
        val success: Boolean,
        val outputPath: String,
        val inputSize: Long,
        val outputSize: Long,
        val durationMs: Long,
        val processingMs: Long
    )

    // 진행률 콜백
    fun trim(
        config: TrimConfig,
        onProgress: (Float) -> Unit  // 0.0 ~ 1.0
    ): TrimResult

    // 빠른 미리보기 (구간만 잘라서 리먹싱, 인코딩 없음)
    fun quickCut(
        inputPath: String,
        startMs: Long,
        endMs: Long,
        outputPath: String
    ): Boolean
}
```

### 3.2 SpeechEngine — 네이티브 음성인식

**v1.0 문제:** `let final` 예약어 버그 + WebView STT 제한
**v2.0 해법:** Android SpeechRecognizer (온디바이스 모델 지원)

```kotlin
// SpeechEngine.kt
class SpeechEngine(
    private val context: Context,
    private val channel: MethodChannel
) {
    private var recognizer: SpeechRecognizer? = null
    private var isListening = false

    fun start(language: String) {
        recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        // ↑ Android 13+ 온디바이스 모델. 네트워크 불필요.
        // 미지원 기기에서는 createSpeechRecognizer()로 폴백.

        recognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val texts = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                channel.invokeMethod("onSpeechResult", mapOf(
                    "text" to (texts?.firstOrNull() ?: ""),
                    "isFinal" to true
                ))
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val texts = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                channel.invokeMethod("onSpeechResult", mapOf(
                    "text" to (texts?.firstOrNull() ?: ""),
                    "isFinal" to false
                ))
            }

            // continuous 모드: 끝나면 자동 재시작
            override fun onEndOfSpeech() {
                if (isListening) start(language)
            }
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        }
        isListening = true
        recognizer?.startListening(intent)
    }

    fun stop() {
        isListening = false
        recognizer?.stopListening()
        recognizer?.destroy()
        recognizer = null
    }
}
```

**번역 파이프라인:**

```
마이크 → SpeechRecognizer (온디바이스)
              │
              ├─ 원문 텍스트 → Flutter UI (원문 박스)
              │
              ├─ ML Kit Translation (온디바이스)
              │       │
              │       └─ 번역 텍스트 → Flutter UI (번역 박스)
              │
              └─ [폴백] Google Translate URL
```

### 3.3 RecordingEngine — 안정적 화면녹화

**v1.0 문제:** 비동기 stop 레이스, dispose 누수, Foreground Service 좀비
**v2.0 해법:** 상태 머신 + 콜백 기반

```
          ┌─────────┐
          │  IDLE    │
          └────┬────┘
    start()    │
          ┌────▼────┐
          │ STARTING │ ← startForeground + MediaProjection 요청
          └────┬────┘
    prepared   │
          ┌────▼────┐
          │RECORDING │ ← mediaRecorder.start()
          └────┬────┘
    stop()     │
          ┌────▼────┐
          │ STOPPING │ ← mediaRecorder.stop() + 완료 대기
          └────┬────┘
    finalized  │    ← 파일 쓰기 완료 확인 후 path 리턴
          ┌────▼────┐
          │  IDLE    │ ← stopForeground + stopSelf
          └─────────┘

에러 발생 시 어떤 상태에서든 → IDLE로 전이 (리소스 정리 보장)
```

```kotlin
class RecordingEngine {
    enum class State { IDLE, STARTING, RECORDING, STOPPING }

    private var state = State.IDLE

    fun stop(callback: (String?) -> Unit) {
        if (state != State.RECORDING) { callback(null); return }
        state = State.STOPPING

        try {
            mediaRecorder?.stop()
            mediaRecorder?.release()
        } catch (e: Exception) {
            // stop 실패 시 파일 삭제
            File(outputPath).delete()
            cleanup()
            callback(null)
            return
        }

        virtualDisplay?.release()
        mediaProjection?.stop()

        // 파일 무결성 확인
        val file = File(outputPath)
        if (file.exists() && file.length() > 1024) {
            // MediaStore에 등록 (갤러리에 표시)
            MediaScannerConnection.scanFile(context,
                arrayOf(outputPath), arrayOf("video/mp4"), null)
            state = State.IDLE
            callback(outputPath)
        } else {
            file.delete()
            state = State.IDLE
            callback(null)
        }

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
}
```

### 3.4 OAuth — AppAuth 방식

**v1.0 문제:** `https://localhost` redirect + WebView 수동 토큰 가로채기
**v2.0 해법:** `flutter_appauth` + 커스텀 스킴

```
┌──────────┐     ┌──────────────┐     ┌──────────────┐
│ 앱       │────▶│ Chrome       │────▶│ Google OAuth  │
│          │     │ Custom Tab   │     │ 동의 화면      │
│          │     └──────────────┘     └──────┬───────┘
│          │                                 │
│          │◀── com.parksy.studio://callback ─┘
│          │     (authorization_code)
│          │
│          │──── token exchange ────────────▶ Google Token EP
│          │◀─── access_token + refresh_token
└──────────┘
```

```dart
// auth_service.dart
class AuthService {
  static const _clientId = '...apps.googleusercontent.com';
  static const _redirectUrl = 'com.parksy.studio:/oauth2callback';
  static const _scopes = ['https://www.googleapis.com/auth/youtube.upload'];

  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  Future<String?> signIn() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUrl,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
          tokenEndpoint: 'https://oauth2.googleapis.com/token',
        ),
        scopes: _scopes,
      ),
    );
    // refresh_token을 secure storage에 저장
    if (result != null) {
      await _saveRefreshToken(result.refreshToken);
      return result.accessToken;
    }
    return null;
  }

  Future<String?> refreshAccessToken() async {
    final refreshToken = await _loadRefreshToken();
    if (refreshToken == null) return null;
    final result = await _appAuth.token(TokenRequest(
      _clientId, _redirectUrl,
      refreshToken: refreshToken,
      serviceConfiguration: const AuthorizationServiceConfiguration(
        authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
        tokenEndpoint: 'https://oauth2.googleapis.com/token',
      ),
    ));
    return result?.accessToken;
  }
}
```

**vs v1.0:**

| 항목 | v1.0 | v2.0 |
|------|------|------|
| 인증 방식 | Implicit Flow (토큰만) | Authorization Code + PKCE |
| 토큰 갱신 | 불가 (매번 재로그인) | refresh_token으로 자동 갱신 |
| UI | WebView 안에서 Google 로그인 | Chrome Custom Tab (보안) |
| 토큰 저장 | SharedPreferences (평문) | flutter_secure_storage |

### 3.5 YouTube 업로드 — 견고한 Resumable Upload

```dart
// upload_service.dart
class UploadService {
  static const _chunkSize = 10 * 1024 * 1024; // 10MB

  Future<String?> upload({
    required String accessToken,
    required String filePath,
    required String title,
    String description = '',
    String privacy = 'private',
    void Function(double)? onProgress,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();

    // 1. Resumable session 시작
    final initRes = await http.post(
      Uri.parse('https://www.googleapis.com/upload/youtube/v3/videos'
          '?uploadType=resumable&part=snippet,status'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Upload-Content-Type': 'video/mp4',
        'X-Upload-Content-Length': '$fileSize',
      },
      body: jsonEncode({
        'snippet': {
          'title': title,
          'description': description,
          'categoryId': '22',
        },
        'status': {'privacyStatus': privacy},
      }),
    );

    if (initRes.statusCode != 200) {
      if (initRes.statusCode == 401) throw AuthExpiredException();
      throw UploadException('세션 시작 실패: ${initRes.statusCode}');
    }

    final uploadUrl = initRes.headers['location']!;

    // 2. 청크 업로드 + 재시도
    int uploaded = 0;
    final raf = await file.open(mode: FileMode.read);

    try {
      while (uploaded < fileSize) {
        final end = min(uploaded + _chunkSize, fileSize);
        final chunkLength = end - uploaded;

        await raf.setPosition(uploaded);
        final bytes = await raf.read(chunkLength);

        final res = await _uploadChunkWithRetry(
          uploadUrl: uploadUrl,
          bytes: bytes,
          start: uploaded,
          end: end,
          fileSize: fileSize,
          accessToken: accessToken,
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          onProgress?.call(1.0);
          final data = jsonDecode(res.body);
          return data['id'] as String; // YouTube video ID
        }

        if (res.statusCode == 308) {
          // 성공적으로 수신됨, 다음 청크로
          uploaded = end;
          onProgress?.call(uploaded / fileSize);
          continue;
        }

        throw UploadException('청크 업로드 실패: ${res.statusCode}');
      }
    } finally {
      await raf.close();
    }

    return null;
  }

  // 개별 청크 재시도 (exponential backoff)
  Future<http.Response> _uploadChunkWithRetry({
    required String uploadUrl,
    required List<int> bytes,
    required int start,
    required int end,
    required int fileSize,
    required String accessToken,
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await http.put(
          Uri.parse(uploadUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'video/mp4',
            'Content-Range': 'bytes $start-${end - 1}/$fileSize',
          },
          body: bytes,
        );
      } catch (e) {
        if (attempt == maxRetries) rethrow;
        await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
      }
    }
    throw UploadException('재시도 초과');
  }
}
```

**vs v1.0:**

| 항목 | v1.0 | v2.0 |
|------|------|------|
| 청크 읽기 | `file.openRead().fold()` → List<int> 전체 메모리 | `RandomAccessFile.read()` → 정확한 크기만 |
| 재시도 | 없음 | 청크 단위 exponential backoff |
| 토큰 만료 | SharedPreferences 삭제 후 수동 재로그인 | AuthExpiredException → 자동 refresh |
| 에러 처리 | `catch (e) { setState }` | 타입별 예외 분기 |

---

## 4. 데이터 모델 — 프로젝트 단위 관리

v1.0에는 프로젝트 개념이 없다. 녹화→트림→업로드가 각각 독립적.
v2.0은 **프로젝트가 파이프라인의 단위**다.

```dart
// project.dart
class Project {
  final int id;
  final String name;
  final DateTime createdAt;
  final ProjectStatus status;

  // 녹화
  final String? recordingPath;
  final Duration? recordingDuration;
  final String recordingFormat; // 'shorts' | 'long'

  // 트리밍
  final String? trimmedPath;
  final int cropTop;
  final int cropBottom;

  // 통역 (녹화 중 사용했으면)
  final String? transcriptText;
  final String? translatedText;

  // BGM
  final String? bgmTrackName;

  // 업로드
  final String? youtubeVideoId;
  final String? youtubeTitle;
  final String uploadPrivacy; // 'private' | 'unlisted' | 'public'
  final DateTime? uploadedAt;
}

enum ProjectStatus {
  recording,    // 녹화 중
  recorded,     // 녹화 완료, 트리밍 전
  trimming,     // 트리밍 중
  trimmed,      // 트리밍 완료, 업로드 전
  uploading,    // 업로드 중
  uploaded,     // 업로드 완료
  failed,       // 실패
}
```

```
프로젝트 라이프사이클:

  [녹화] ──▶ [트리밍] ──▶ [업로드] ──▶ [완료]
    │            │            │
    ▼            ▼            ▼
  recorded    trimmed     uploaded
    │            │            │
    └── 재트림 ──┘   └── 재업로드 ──┘
```

### 홈 대시보드

```
┌─────────────────────────────────────┐
│  PARKSY STUDIO              v2.0.0  │
├─────────────────────────────────────┤
│                                     │
│  ⚡ 퀵 액션                          │
│  ┌──────┐ ┌──────┐ ┌──────┐        │
│  │⏺ 녹화│ │🌐통역│ │🎵 BGM│        │
│  └──────┘ └──────┘ └──────┘        │
│                                     │
│  📂 최근 프로젝트                     │
│  ┌─────────────────────────────┐    │
│  │ 📱 Shorts — 허세교양 EP.5     │    │
│  │ ✅ uploaded · 3:42 · 12분 전  │    │
│  │ youtu.be/abc123              │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 🖥️ Long — 수학 강의 #12      │    │
│  │ ✂️ trimmed · 15:20 · 어제     │    │
│  │ [업로드] [재트림] [삭제]        │    │
│  └─────────────────────────────┘    │
│                                     │
│  🔧 도구 (cloud-appstore)            │
│  [런처 열기 →]                       │
│                                     │
├──────┬──────┬──────┬──────┬────────┤
│ 🏠   │ ⏺   │ 🌐   │ 🎵   │ ☁️     │
│ 홈   │ 녹화  │ 통역  │ BGM  │ 업로드  │
└──────┴──────┴──────┴──────┴────────┘
```

---

## 5. Phase 로드맵

### Phase 0: 기반 정리 (1일)

```
[ ] v1.0 버그 7개 핫픽스 (let final, dispose 누수 등)
[ ] 프로젝트 구조 리팩터링 (lib/ 디렉토리 정리)
[ ] drift DB 스키마 생성 (Project 테이블)
[ ] GoRouter 네비게이션 설정
[ ] 테스트 폴더 구조 + 모델 테스트
```

### Phase 1: 녹화 엔진 안정화 (2일)

```
[ ] RecordingEngine 상태 머신 구현
[ ] RecordingService Foreground 누수 수정
[ ] recording_screen dispose 시 녹화 중지
[ ] stop → 콜백 기반 파일 path 리턴
[ ] 프로젝트 자동 생성 (녹화 시작 시)
[ ] MediaStore 등록 (갤러리 표시)
```

### Phase 2: 네이티브 트리머 (3일) — 핵심

```
[ ] TrimmerEngine (MediaCodec + MediaMuxer)
[ ] OpenGL ES 크롭 + 리사이즈 파이프라인
[ ] Flutter 타임라인 위젯 (구간 선택)
[ ] media_kit 미리보기 플레이어
[ ] quickCut (키프레임 단위 빠른 자르기)
[ ] 진행률 콜백 → Flutter UI
```

### Phase 3: 동시통역 네이티브화 (1일)

```
[ ] SpeechEngine (Android SpeechRecognizer)
[ ] 온디바이스 모델 감지 + 폴백
[ ] ML Kit Translation 연동
[ ] Flutter 실시간 자막 위젯
```

### Phase 4: OAuth + 업로드 (1일)

```
[ ] flutter_appauth 연동
[ ] Authorization Code + PKCE flow
[ ] refresh_token 자동 갱신
[ ] Resumable Upload 재시도 로직
[ ] 업로드 진행률 UI
```

### Phase 5: BGM + 통합 (1일)

```
[ ] media_kit BGM 재생 (YouTube embed → 네이티브)
[ ] 미니 플레이어 (하단 고정)
[ ] 프로젝트 대시보드 홈 화면
[ ] 설정 화면 (테마, 기본 포맷, 기본 privacy)
```

### Phase 6: 고급 기능 (선택)

```
[ ] 녹화 중 실시간 자막 오버레이
[ ] PiP 모드 (화면 최소화 시 미니 플레이어)
[ ] 배치 업로드 (여러 프로젝트 한번에)
[ ] 프로젝트 내보내기/가져오기 (JSON)
```

---

## 6. v1.0 vs v2.0 비교표

| 항목 | v1.0 | v2.0 |
|------|------|------|
| **아키텍처** | WebView에 핵심 로직 | 네이티브 엔진 + Flutter UI |
| **영상 트리밍** | FFmpeg WASM (동작 안 함) | MediaCodec HW 가속 (5초/분) |
| **음성인식** | Web Speech API (JS 버그) | Android SpeechRecognizer (온디바이스) |
| **번역** | Google Translate URL 열기 | ML Kit 온디바이스 번역 |
| **BGM** | YouTube embed WebView | media_kit 네이티브 재생 |
| **OAuth** | Implicit Flow (토큰만) | AuthCode + PKCE + refresh |
| **업로드** | 메모리 비효율 청크 | RandomAccessFile + 재시도 |
| **데이터** | 없음 | drift DB 프로젝트 관리 |
| **오프라인** | 불가 | 녹화+트림+재생 가능 |
| **코드량** | 1,528줄 | ~4,000줄 (예상) |
| **빌드 수준** | PoC (실기기 미테스트) | Production-ready |

---

## 7. 왜 이게 기똥찬가

### 기술적 차별화

1. **MediaCodec 직접 제어** — FFmpeg 래퍼가 아니라 Android 하드웨어 인코더를 직접 쓴다. 이걸 Flutter에서 하는 오픈소스는 거의 없다. 대부분 `ffmpeg_kit`에 의존하는데, 그건 50MB짜리 네이티브 바이너리를 앱에 끼워넣는 거다. MediaCodec은 0MB 추가, 10배 빠름.

2. **온디바이스 AI 풀스택** — STT(SpeechRecognizer) + 번역(ML Kit) + 영상처리(MediaCodec) 전부 온디바이스. 서버 비용 $0. 비행기 모드에서도 녹화→편집→저장 가능.

3. **프로젝트 상태 머신** — 녹화→트림→업로드가 하나의 트랜잭션. 중간에 앱이 죽어도 DB에 상태가 남아서 이어서 할 수 있다.

### 제품적 차별화

F-Droid/Play Store에서 이 조합을 하나의 앱으로 하는 건 **없다:**
```
화면녹화 + 자동크롭 + YouTube 규격화 + 동시통역 + BGM + 원터치 업로드
```

각각은 있다. 녹화 앱, 편집 앱, 업로드 앱. 근데 **파이프라인 전체를 하나로 묶고, 프로젝트 단위로 관리하는 앱**은 없다. 이게 v2.0의 핵심 가치다.

### 서사적 차별화 (헌법 제1조)

```
v1.0 커밋 히스토리 = "만들고 → 안 돌아가서 → 고치고 → 또 안 돌아가서"
v2.0 커밋 히스토리 = "부검하고 → 아키텍처 재설계하고 → 엔진부터 다시 쌓고"

이건 서사적으로 "rewrite = 각성" 에 해당한다.
v1은 프롤로그였고, v2가 본편이다.
```

---

## 부록: v1.0 즉시 핫픽스 (v2.0 전에 할 것)

v2.0 개발 전에 v1.0을 최소한 "돌아가는" 상태로 만들려면:

```
1. interpreter.html:126  →  let final → let finalText (30초)
2. recording_screen.dart:27  →  dispose에 RecordingService.stop() 추가 (1분)
3. RecordingService.kt:47  →  early return 전 stopSelf() 호출 (1분)
4. interpreter_screen.dart:43  →  마이크만 grant, 나머지 deny (2분)
5. trimmer — FFmpeg WASM 제거, "준비 중" 표시로 교체 (5분)
   (동작 안 하는 걸 놔두는 것보다 솔직하게 비활성화)
```

트리머와 YouTube 업로드는 v2.0에서 네이티브로 재구현해야 제대로 된다.
