package kr.parksy.axis;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.VideoView;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Locale;

/**
 * TvOverlayService — 화면 **반대편(오른쪽 아래)** 에 나레이터 영상 액자를 하나 더 띄운다.
 *
 * ── 왜 별도 서비스인가 (2026-09-22 설계 결정) ──────────────────────────────
 * 콘티(TreeView)는 flutter_overlay_window 가 띄우는 Flutter 창이다. 그 플러그인은
 * **창을 하나만** 만든다 — `OverlayConstants.CACHED_TAG` 가 단일 상수이고
 * `WindowSetup` 도 static 필드 하나뿐이며 서비스도 하나다. 그래서 "창 두 개"를
 * 플러그인으로는 못 만든다.
 *
 * 갈림길이 둘이었다:
 *   (A) Flutter 창을 화면 폭 전체로 넓혀 좌=콘티 / 우=TV 두 칸으로 그린다
 *   (B) TV 는 **네이티브 창으로 따로** 띄운다  ← 이걸 골랐다
 *
 * (A) 를 버린 이유: 창이 하단 전체를 덮으면 **그 띠의 터치를 전부 삼킨다.**
 * 정작 지금 잘 도는 콘티 창의 터치 영역까지 건드리게 된다. 게다가 영상을
 * Flutter 쪽에서 틀려면 오버레이 엔진에 플러그인을 등록해야 하는데
 * (`GeneratedPluginRegistrant.registerWith()` 를 플러그인이 부르지 않는다),
 * 그건 검증 안 된 길이다.
 *
 * (B) 의 이점: **지금 잘 도는 콘티 창을 한 줄도 안 건드린다.** TV 창은 자기
 * 크기(작다)만큼만 터치를 먹는다. 영상 재생은 안드로이드에서 오래 검증된
 * VideoView 하나로 끝난다.
 *
 * ── 왜 합성이 필요 없나 ───────────────────────────────────────────────────
 * 원본 `a_tv_frame.mp4` 는 **액자(PARKSY 세로 TV 테두리 + 초록 전원 LED)가
 * 이미 영상에 구워져 있다.** 그래서 테두리를 따로 그리고 그 위에 영상을
 * 얹는 합성 과정이 없다. 파일 하나를 그냥 재생하면 액자째로 나온다.
 * 다른 액자(b_camera_frame / e_lens_green 등)로 바꾸려면 파일만 갈아끼우면 된다.
 *
 * ── 쓰는 법 ───────────────────────────────────────────────────────────────
 *   am broadcast --user 0 -a kr.parksy.axis.TV \
 *       -n kr.parksy.axis/flutter.overlay.window.flutter_overlay_window.AxisArmReceiver \
 *       --ei w 96 --ei h 155
 *   am broadcast --user 0 -a kr.parksy.axis.TV_OFF -n kr.parksy.axis/...
 *
 * extras (전부 선택):
 *   w / h    창 크기(dp). 기본 96 x 155 (가로:세로 = 액자 비율 402:650)
 *   x / y    오른쪽·아래 여백(dp). 기본 6 / 6
 *   video    재생할 파일 경로. 절대경로. 안 주면 APK 에 넣은 기본 액자를 쓴다
 *   mute     1=무음(기본), 0=소리 냄
 *
 * ── 무음이 기본인 이유 ────────────────────────────────────────────────────
 * 이 액자는 **녹화 중인 화면에 얹히는 소품**이다. 소리를 내면 Boss 의 목소리나
 * 방송 오디오와 겹친다. 보고 싶을 때만 mute=0 으로 켠다.
 */
public class TvOverlayService extends Service {

    private static final String TAG = "AxisTv";
    private static final String CHANNEL = "parksy_axis_tv";
    private static final int NOTI_ID = 8842;

    /** APK 에 넣어둔 기본 액자. 액자가 이미 영상에 구워져 있다. */
    private static final String ASSET = "axis_tv.mp4";

    /** 액자 원본 비율 (a_tv_frame.mp4 = 402x650). 창 크기가 이 비율을 안 지키면 찌그러진다. */
    private static final double ASPECT = 402.0 / 650.0;

    private static final int DEFAULT_H_DP = 155;
    private static final int DEFAULT_MARGIN_DP = 6;

    private WindowManager wm;
    private FrameLayout root;
    private VideoView video;

    @Override
    public IBinder onBind(Intent intent) { return null; }

    @Override
    public void onCreate() {
        super.onCreate();
        wm = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
        startForegroundSafely();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        int hDp = intent != null ? intent.getIntExtra("h", DEFAULT_H_DP) : DEFAULT_H_DP;
        int wDp = intent != null ? intent.getIntExtra("w", 0) : 0;
        if (wDp <= 0) {
            // w 를 안 줬으면 액자 비율로 계산한다. 임의 숫자를 정하면 액자가
            // 늘어나 보인다 — 원본 비율을 지키는 게 기본이어야 한다.
            wDp = (int) Math.round(hDp * ASPECT);
        }
        int mxDp = intent != null ? intent.getIntExtra("x", DEFAULT_MARGIN_DP) : DEFAULT_MARGIN_DP;
        int myDp = intent != null ? intent.getIntExtra("y", DEFAULT_MARGIN_DP) : DEFAULT_MARGIN_DP;
        boolean mute = intent == null || intent.getIntExtra("mute", 1) != 0;

        String path = intent != null ? intent.getStringExtra("video") : null;
        if (path == null || path.trim().isEmpty()) {
            path = seedAsset();   // APK 안의 기본 액자를 꺼내 쓴다
        }

        show(path, wDp, hDp, mxDp, myDp, mute);
        return START_STICKY;
    }

    /** 창을 (다시) 세운다. 이미 떠 있으면 지우고 새로 만든다 — 규격 변경을 반영하기 위해. */
    private void show(String path, int wDp, int hDp, int mxDp, int myDp, boolean mute) {
        teardown();

        if (path == null) {
            Log.w(TAG, "재생할 영상이 없습니다 (asset 도 추출 실패)");
            return;
        }
        File f = new File(path);
        if (!f.exists()) {
            Log.w(TAG, "영상 파일이 없습니다: " + path);
            return;
        }

        FrameLayout box = new FrameLayout(this);
        VideoView vv = new VideoView(this);

        box.addView(vv, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                : WindowManager.LayoutParams.TYPE_PHONE;

        WindowManager.LayoutParams p = new WindowManager.LayoutParams(
                dpToPx(wDp), dpToPx(hDp),
                0, 0,
                type,
                // FLAG_NOT_FOCUSABLE 를 쓴다 — 이 창에는 글자 입력란이 없다.
                // FLAG_NOT_TOUCH_MODAL 을 쓰면 **포커스 가능**해져서 삼성 키보드(IME)가
                // 이 창에 붙고, 글자가 터미널로 안 간다. 2026-09-22 콘티 창에서 실제로
                // 밟은 버그와 같은 함정이라 여기서는 처음부터 NOT_FOCUSABLE 로 간다.
                // (문서상 NOT_FOCUSABLE 은 NOT_TOUCH_MODAL 을 내포한다 — 바깥 터치는 통과)
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        | WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT);

        p.gravity = Gravity.BOTTOM | Gravity.END;   // 오른쪽 아래 = 콘티의 반대편
        p.x = dpToPx(mxDp);
        p.y = dpToPx(myDp);

        vv.setVideoPath(path);
        vv.setOnPreparedListener(mp -> {
            mp.setLooping(true);
            if (mute) mp.setVolume(0f, 0f);
            vv.start();
            Log.i(TAG, "재생 시작 " + wDp + "x" + hDp + "dp  mute=" + mute);
        });
        vv.setOnErrorListener((mp, what, extra) -> {
            // 조용히 죽으면 "왜 안 나오나"로 한참 헤맨다. 로그에 남긴다.
            Log.e(TAG, String.format(Locale.US, "재생 실패 what=%d extra=%d %s", what, extra, path));
            return true;
        });

        try {
            wm.addView(box, p);
            root = box;
            video = vv;
        } catch (Exception e) {
            // SYSTEM_ALERT_WINDOW 가 회수되면 여기서 죽는다
            // (BadTokenException: permission denied for window type 2038).
            // 복구: adb shell appops set kr.parksy.axis SYSTEM_ALERT_WINDOW allow
            Log.e(TAG, "창을 못 띄웠습니다 — 다른 앱 위에 표시 권한을 확인하세요", e);
        }
    }

    private void teardown() {
        if (video != null) {
            try { video.stopPlayback(); } catch (Exception ignored) { }
            video = null;
        }
        if (root != null && wm != null) {
            try { wm.removeView(root); } catch (Exception ignored) { }
            root = null;
        }
    }

    @Override
    public void onDestroy() {
        teardown();
        // 알림을 확실히 걷는다. 안 그러면 액자를 껐는데 "표시 중" 알림이 남는다.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE);
        } else {
            stopForeground(true);
        }
        super.onDestroy();
    }

    /**
     * APK assets 의 기본 액자를 filesDir 로 꺼낸다.
     *
     * VideoView 는 assets 를 직접 못 읽는다(file:///android_asset/ 은 신뢰할 만하지 않다).
     * 매번 덮어쓴다 — 201KB 라 비용이 없고, **새 APK 로 액자를 바꾸면 다음 시작에
     * 바로 반영된다.** Boss 가 직접 넣은 영상은 여기가 아니라 `video=` 경로로 쓰므로
     * 서로 덮어쓰지 않는다.
     */
    private String seedAsset() {
        File out = new File(getFilesDir(), ASSET);
        try (InputStream in = getAssets().open(ASSET);
             OutputStream os = new FileOutputStream(out, false)) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) os.write(buf, 0, n);
            os.flush();
            return out.getAbsolutePath();
        } catch (Exception e) {
            Log.e(TAG, "기본 액자를 꺼내지 못했습니다: " + e.getMessage());
            return out.exists() ? out.getAbsolutePath() : null;
        }
    }

    private int dpToPx(int dp) {
        return (int) TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, dp, getResources().getDisplayMetrics());
    }

    private void startForegroundSafely() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null && nm.getNotificationChannel(CHANNEL) == null) {
                nm.createNotificationChannel(new NotificationChannel(
                        CHANNEL, "Parksy Axis 나레이터", NotificationManager.IMPORTANCE_MIN));
            }
        }
        Notification n = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, CHANNEL)
                : new Notification.Builder(this))
                .setContentTitle("Parksy Axis")
                .setContentText("나레이터 액자 표시 중")
                .setSmallIcon(android.R.drawable.presence_video_online)
                .build();
        // 일반 서비스로 두면 안드로이드가 백그라운드 서비스 제한으로 죽인다.
        // 녹화 내내 살아 있어야 하므로 포그라운드로 올린다.
        //
        // 백그라운드에서 FGS 를 올리는 건 안드로이드 12+ 에서 원칙적으로 막히지만,
        // **SYSTEM_ALERT_WINDOW 를 가진 앱은 예외**다. 이 앱은 그 권한이 필수라
        // (오버레이 자체가 그걸로 뜬다) 여기서 걸리지 않는다. 콘티 창(OverlayService)이
        // 같은 방식으로 이미 돌고 있는 게 그 증거다.
        //
        // 그래도 감싼다 — 승격이 실패했다고 액자까지 안 뜨면 원인을 못 찾는다.
        try {
            startForeground(NOTI_ID, n);
        } catch (Exception e) {
            Log.e(TAG, "포그라운드 승격 실패 — 액자는 계속 시도합니다", e);
        }
    }
}
