#!/usr/bin/env bash
# 태블릿에 PC 런처 배포 + Chrome 자동 오픈
# WSL에서 실행

TABLET_IP="100.74.21.77"
PORT=7777
HTML_SRC="/home/dtsli/dtslib-apk-lab/dashboard/pc-launcher.html"
TABLET_DST="/sdcard/Download/pc-launcher.html"

echo "1️⃣  ADB 연결..."
adb connect "$TABLET_IP:5555" 2>&1 | tail -1

echo "2️⃣  ADB reverse 터널 (태블릿:$PORT → PC:$PORT)..."
adb -s "$TABLET_IP:5555" reverse tcp:$PORT tcp:$PORT && echo "✅ 터널 설정됨"

echo "3️⃣  HTML 파일 태블릿으로 푸시..."
adb -s "$TABLET_IP:5555" push "$HTML_SRC" "$TABLET_DST" && echo "✅ 파일 전송 완료"

echo "4️⃣  Chrome으로 열기..."
adb -s "$TABLET_IP:5555" shell am start -a android.intent.action.VIEW \
  -d "file:///sdcard/Download/pc-launcher.html" \
  -n "com.android.chrome/com.google.android.apps.chrome.Main" \
  --es "BROWSER" "true" 2>&1 && echo "✅ Chrome 실행됨"

echo ""
echo "🎉 배포 완료!"
echo "   PC에서: start.bat 실행 (또는 python server.py)"
echo "   태블릿: Chrome에서 런처가 열립니다"
