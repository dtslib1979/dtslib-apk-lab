package flutter.overlay.window.flutter_overlay_window;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.WindowManager;

import org.json.JSONObject;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;

/**
 * AxisArmReceiver — 오버레이를 **화면을 띄우지 않고** 무장시키는 입구.
 *
 * ── 왜 필요한가 ────────────────────────────────────────────────────────────
 * 원래 오버레이는 앱을 열고 "오버레이 시작" 버튼을 눌러야만 뜬다. 그 경로는
 * ① 폰 화면을 빼앗고 ② 사람이 매번 눌러야 한다. 에이전트가 연출하려면 둘 다 막힌다.
 *
 * 플러그인의 오버레이 서비스는 android:exported="false" 라 밖에서 못 연다.
 * 그래서 **앱 안에 문을 하나 내고**, 그 문이 서비스 대신 규격을 세팅한 뒤 열어준다.
 *
 * ── 왜 이 클래스가 플러그인 패키지에 있는가 ────────────────────────────────
 * 창 크기·위치는 OverlayService.onStartCommand 가 WindowSetup 의 **static 필드**에서
 * 읽는다. 그 필드들은 패키지 전용(package-private)이라 다른 패키지에서는 못 만진다.
 * 원래 그 값을 채우는 건 메인앱이 부르는 showOverlay() 뿐이고, 그건 앱 화면이
 * 앞에 있어야만 불린다 — 즉 백그라운드 경로가 없다. 그 자를 여기서 대신 채운다.
 * Kotlin 이 아니라 Java 인 이유도 같다: Java 라야 패키지 전용 접근이 확실하다.
 *
 * ── dp/px 함정 (2026-09-22 실측) ───────────────────────────────────────────
 * onStartCommand 는 WindowSetup.width/height 를 **그대로 픽셀**로 쓴다(리사이즈 API 인
 * resizeOverlay 는 반대로 dpToPx 를 건다 — 플러그인 안에서 규약이 엇갈린다).
 * 그런데 Dart 쪽 위젯은 같은 숫자를 **dp** 로 그린다. 그래서 260 을 그냥 넣으면
 * 창은 260px, 내용은 260dp(=731px) → **내용이 잘려 나온다.**
 * 여기서 dpToPx 를 걸어 창을 내용 크기에 맞춘다. 이게 이 앱의 실제 크기 버그다.
 *
 * ── 두 가지 모드 ───────────────────────────────────────────────────────────
 *   show=1 (기본) — 저장하고 **띄운다**. 처음 무장할 때. 창 규격이 여기서 확정된다.
 *   show=0        — 저장만 하고 **화면은 건드리지 않는다**. 이미 떠 있으면
 *                   소켓에 reload 를 넣어 내용만 갈아끼운다(재시작 없음 = 안 깜빡임).
 *                   → "설정·카테고리는 백그라운드로, 화면엔 활성화할 때만" 이 이 모드다.
 *
 * ── 쓰는 법 ────────────────────────────────────────────────────────────────
 *   am broadcast -a kr.parksy.axis.ARM -n kr.parksy.axis/flutter.overlay.window.flutter_overlay_window.AxisArmReceiver \
 *       --es rundown '{"root":"[LIVE] …","stages":["…","…"],"theme":"amber",…}' --ei show 1
 *   am broadcast -a kr.parksy.axis.OFF -n kr.parksy.axis/…
 */
public class AxisArmReceiver extends BroadcastReceiver {

    private static final String TAG = "AxisArm";
    public static final String ACTION_ARM = "kr.parksy.axis.ARM";
    public static final String ACTION_OFF = "kr.parksy.axis.OFF";
    private static final String CONFIG = "axis_overlay_config.json";
    private static final String LIBRARY = "axis_rundowns.jsonl";

    /** 오버레이가 여는 커맨드 소켓 (lib/main.dart _startCtlSocket). */
    private static final int CTL_PORT = 8492;

    /**
     * shared_preferences 플러그인이 쓰는 저장소 이름과 키 접두어.
     * 오버레이는 파일이 비면 이 백업으로 폴백한다(SettingsService.loadForOverlay).
     * 파일만 쓰고 이걸 안 쓰면, 파일이 한 번이라도 비는 순간 **옛 설정이 되살아난다**
     * — 2026-09-22 "주입한 콘티가 [Idea]/Ca/No/Bu 로 돌아간" 사건의 유력한 정체.
     * 두 곳을 함께 써서 폴백 경로를 막는다.
     */
    private static final String PREFS_NAME = "FlutterSharedPreferences";
    private static final String PREFS_KEY = "flutter.axis_overlay_config_backup";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) return;
        Context app = context.getApplicationContext();

        if (ACTION_OFF.equals(intent.getAction())) {
            app.stopService(new Intent(app, OverlayService.class));
            Log.i(TAG, "overlay OFF");
            return;
        }
        if (!ACTION_ARM.equals(intent.getAction())) return;

        String rundown = intent.getStringExtra("rundown");
        if (rundown == null || rundown.trim().isEmpty()) {
            Log.w(TAG, "ARM 인데 rundown 이 없습니다");
            return;
        }
        rundown = rundown.trim();

        // ① 누적 저장 — 들어온 콘티를 라이브러리에 계속 쌓는다.
        //    백그라운드로 갈아끼우다 보면 "아까 그 콘티"가 사라지기 쉬워서 남긴다.
        appendLine(new File(app.getFilesDir(), LIBRARY), rundown);

        // ② 현재 설정 = 방금 받은 콘티. 파일 + prefs **둘 다** (폴백 차단).
        writeText(new File(app.getFilesDir(), CONFIG), rundown);
        try {
            SharedPreferences prefs = app.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            prefs.edit().putString(PREFS_KEY, rundown).apply();
        } catch (Exception e) {
            Log.w(TAG, "prefs 백업 실패(치명적이지 않음)", e);
        }

        // ③ show=0 — 저장만. 화면은 건드리지 않는다.
        if (intent.getIntExtra("show", 1) == 0) {
            pokeReload();
            Log.i(TAG, "saved only (show=0)");
            return;
        }

        // ④ 캐시 엔진 폐기 — 이게 없으면 설정이 안 갈린다.
        //    OverlayService.onCreate 는 FlutterEngineCache 에서 엔진을 재사용한다.
        //    서비스를 껐다 켜도 Dart 위젯 트리(=_load() 로 이미 읽은 옛 설정)가
        //    그대로 살아남아, 파일을 바꿔도 화면은 옛 콘티를 계속 보여준다(실측).
        app.stopService(new Intent(app, OverlayService.class));
        FlutterEngine cached = FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG);
        if (cached != null) {
            cached.destroy();
            FlutterEngineCache.getInstance().remove(OverlayConstants.CACHED_TAG);
        }

        // ⑤ 창 규격 — showOverlay() 가 하던 일을 화면 없이 대신한다.
        //    크기는 콘티 JSON 의 w·h·overlayScale 에서 뽑는다. Dart 는 위젯을
        //    scaledWidth(= w × overlayScale) dp 로 그리므로 창도 같은 값이어야
        //    내용이 잘리지 않는다. 같은 숫자를 두 곳에서 따로 관리하면 반드시 어긋난다.
        //    extras(w/h)를 주면 그쪽이 우선 — 현장에서 강제로 키우고 싶을 때.
        int wDp = intent.getIntExtra("w", scaled(rundown, "w", 260));
        int hDp = intent.getIntExtra("h", scaled(rundown, "h", 300));
        WindowSetup.width = dpToPx(app, wDp);
        WindowSetup.height = dpToPx(app, hDp);
        WindowSetup.gravity = Gravity.BOTTOM | Gravity.LEFT;

        // ── 키보드를 빼앗지 마라 (2026-09-22 실측 버그) ──────────────────────
        // 여기 원래 FLAG_NOT_TOUCH_MODAL 이 박혀 있었다. 그건 **포커스 가능**한
        // 창을 만든다 — 플러그인 이름도 그걸 알고 `focusPointer` 라 부른다.
        // 포커스 가능 = IME(삼성 키보드)가 이 창으로 붙는다. 그런데 이 창엔
        // 글자 입력란이 없다. 그래서 키보드는 뜨는데 **글자가 터미널로 안 간다.**
        // Boss 증상: "Axis 구동하면 삼성 키보드가 먹지가 않아. 너랑 말로 대화를
        // 해야 되는데 불가능해" — 이 한 줄이 원인이다.
        //
        // 더 나쁜 건 이 교체가 **아무것도 얻지 못했다**는 점이다. 안드로이드 문서상
        // FLAG_NOT_FOCUSABLE 은 FLAG_NOT_TOUCH_MODAL 을 **내포한다**
        // ("this flag will also enable FLAG_NOT_TOUCH_MODAL").
        // 즉 바깥 터치는 원래도 통과했고, 우리는 포커스만 빼앗은 순수 손실이었다.
        //
        // 그리고 NOT_FOCUSABLE 은 **창 안쪽 터치를 막지 않는다** (그건 NOT_TOUCHABLE).
        // 오버레이의 onTap(_next) · onJump · 드래그는 전부 그대로 산다.
        // → 되돌린다. 플러그인 기본값이 옳았다.
        WindowSetup.flag = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
        WindowSetup.enableDrag = true;
        WindowSetup.positionGravity = "none";
        WindowSetup.overlayTitle = "Parksy Axis";
        WindowSetup.overlayContent = "방송 콘티";

        // ⑥ 위치 미세조정 — 플러그인의 px/dp 이중환산 버그를 우회한다.
        //    OverlayService.onStartCommand:
        //        int dy = startY == DEFAULT_XY ? -statusBarHeightPx() : startY;
        //        moveOverlay(dx, dy) → params.y = dpToPx(y);
        //    상태바 높이는 **px** 인데 moveOverlay 는 그 값을 **dp** 로 다시 환산한다.
        //    실측(2026-09-22, 1080x2340 @450dpi): 상태바 85px → -239px 로 부풀어
        //    BOTTOM 정렬에서 창이 화면 아래로 239px 밀려났다.
        //        frame=[0,1601]-[731,2444] vs 부모 하단 2205 → 843px 중 239px(28%)가 화면 밖
        //    260dp 콘티의 아래 1~2줄이 안 보인다는 뜻이다.
        //    startY 를 0 으로 **명시**하면 이 기본값 분기를 타지 않아 flush 하게 앉는다.
        //    x/y 는 콘티 JSON 이 아니라 방송 현장에서 미는 값이라 extras 로 받는다.
        Intent svc = new Intent(app, OverlayService.class);
        svc.putExtra("startX", intent.getIntExtra("x", 0));
        svc.putExtra("startY", intent.getIntExtra("y", 0));
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            app.startForegroundService(svc);
        } else {
            app.startService(svc);
        }
        Log.i(TAG, "armed " + wDp + "x" + hDp + "dp bottomLeft");
    }

    /**
     * 떠 있는 오버레이에 "reload" 를 넣어 콘티만 갈아끼운다.
     * 네트워크는 메인 스레드에서 못 하므로 짧은 스레드로 뺀다.
     * 오버레이가 안 떠 있으면 연결이 거부되는데, 그건 정상이다(조용히 넘어간다).
     */
    private static void pokeReload() {
        new Thread(() -> {
            try (Socket s = new Socket()) {
                s.connect(new InetSocketAddress("127.0.0.1", CTL_PORT), 500);
                OutputStream out = s.getOutputStream();
                out.write("reload\n".getBytes("UTF-8"));
                out.flush();
                Log.i(TAG, "reload 전송됨");
            } catch (Exception e) {
                Log.i(TAG, "reload 생략 (오버레이가 안 떠 있음): " + e.getMessage());
            }
        }, "axis-reload").start();
    }

    /**
     * 콘티 JSON 의 w(또는 h) 에 overlayScale 을 곱해 실제 창 크기(dp)를 구한다.
     * AxisSettings.scaledWidth/Height 와 같은 계산이어야 한다 — 저쪽이 내용 크기다.
     */
    private static int scaled(String json, String key, int fallback) {
        try {
            JSONObject o = new JSONObject(json);
            int base = o.has(key) ? o.getInt(key) : fallback;
            double scale = o.has("overlayScale") ? o.getDouble("overlayScale") : 1.0;
            return (int) Math.round(base * scale);
        } catch (Exception e) {
            return fallback;   // JSON 이 깨져도 오버레이는 기본 크기로 뜬다
        }
    }

    /** WindowSetup 은 픽셀을 먹으므로 dp 를 px 로 바꿔 넣는다. */
    private static int dpToPx(Context ctx, int dp) {
        return (int) TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, dp, ctx.getResources().getDisplayMetrics());
    }

    private static void writeText(File f, String text) {
        try (FileWriter w = new FileWriter(f, false)) {
            w.write(text);
        } catch (IOException e) {
            Log.e(TAG, "설정 파일 쓰기 실패", e);
        }
    }

    private static void appendLine(File f, String line) {
        try (FileWriter w = new FileWriter(f, true)) {
            w.write(line);
            w.write("\n");
        } catch (IOException e) {
            Log.e(TAG, "라이브러리 추가 실패", e);
        }
    }
}
