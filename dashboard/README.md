# DTS APK Lab Store (PWA)

> Personal use only. No distribution.

APK 다운로드 메뉴판 PWA.

## 접속

```
https://dtslib-apk-lab.vercel.app/
```

## 기능

- APK 카드 목록
- nightly.link 원클릭 다운로드
- PWA 홈화면 설치
- 오프라인 캐시

## Vercel 배포

1. Vercel에서 `dtslib1979/dtslib-apk-lab` Import
2. Settings → General → Root Directory: `dashboard`
3. Deploy

## 앱 추가

`app.js`의 `apps` 배열에 추가:

```js
{
    id: 'new-app',
    name: 'New App',
    desc: '설명',
    version: 'v1.0.0',
    icon: '🆕',
    downloadUrl: 'https://nightly.link/...',
    cardClass: 'new'
}
```
