#!/usr/bin/env bash
# ADB 터널 셋업 — WSL에서 실행
# 태블릿 → localhost:7777 → PC 서버로 연결

TABLET_IP="100.74.21.77"
PORT=7777

echo "🔌 태블릿 ADB 연결..."
adb connect "$TABLET_IP:5555" && echo "✅ 연결됨" || { echo "❌ 연결 실패"; exit 1; }

echo "🔁 ADB reverse 터널 설정 (태블릿:$PORT → PC:$PORT)..."
adb -s "$TABLET_IP:5555" reverse tcp:$PORT tcp:$PORT && echo "✅ 터널 설정됨" || { echo "❌ 터널 실패"; exit 1; }

echo ""
echo "📱 태블릿에서 접근: http://localhost:$PORT"
echo "✅ 설정 완료. 이제 PC에서 start.bat 실행하세요."
