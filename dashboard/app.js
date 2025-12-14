// APK 앱 목록 (하드코딩)
const apps = [
    {
        id: 'laser-pen-overlay',
        name: 'Laser Pen Overlay',
        desc: 'S Pen 웹 오버레이 판서',
        version: 'v2.1.0',
        icon: '🖊️',
        downloadUrl: 'https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-laser-pen/main/laser-pen-overlay-debug.zip',
        cardClass: 'laser'
    },
    {
        id: 'aiva-trimmer',
        name: 'AIVA Trimmer',
        desc: 'AIVA 음악 2분 트리밍',
        version: 'v1.0.1',
        icon: '✂️',
        downloadUrl: 'https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-aiva-trimmer/main/aiva-trimmer-debug.zip',
        cardClass: 'aiva'
    },
    {
        id: 'capture-pipeline',
        name: 'Capture Pipeline',
        desc: '공유 텍스트 캡처 & 아카이빙',
        version: 'v1.0.0',
        icon: '📥',
        downloadUrl: 'https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-capture-pipeline/main/capture-pipeline-debug.zip',
        cardClass: 'capture'
    }
];

// 카드 렌더링
function renderApps() {
    const grid = document.getElementById('appGrid');
    
    apps.forEach(app => {
        const card = document.createElement('div');
        card.className = `app-card ${app.cardClass}`;
        
        card.innerHTML = `
            <div class="app-icon">${app.icon}</div>
            <div class="app-name">${app.name}</div>
            <div class="app-desc">${app.desc}</div>
            <span class="app-version">${app.version}</span>
            <a href="${app.downloadUrl}" 
               class="download-btn" 
               target="_blank" 
               rel="noopener">
                Download ZIP
            </a>
        `;
        
        grid.appendChild(card);
    });
}

// SW 등록
if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('./sw.js')
        .then(() => console.log('SW registered'))
        .catch(err => console.log('SW failed:', err));
}

// 초기화
document.addEventListener('DOMContentLoaded', renderApps);
