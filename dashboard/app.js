// 카드 렌더링
function renderApps(apps) {
    const grid = document.getElementById('appGrid');
    grid.innerHTML = '';

    apps.forEach(app => {
        const card = document.createElement('div');
        card.className = 'app-card';

        card.innerHTML = `
            <div class="app-icon">${app.icon}</div>
            <div class="app-name">${app.name}</div>
            <div class="app-desc">${app.description}</div>
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

// 앱 목록 로드
async function loadApps() {
    try {
        const response = await fetch('./apps.json?v=' + Date.now());
        if (!response.ok) throw new Error('Failed to load apps.json');
        const apps = await response.json();
        renderApps(apps);
    } catch (error) {
        console.error('Error loading apps:', error);
        document.getElementById('appGrid').innerHTML =
            '<p style="color: #ff5252; text-align: center;">앱 목록을 불러올 수 없습니다.</p>';
    }
}

// SW 등록
if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('./sw.js')
        .then(() => console.log('SW registered'))
        .catch(err => console.log('SW failed:', err));
}

// 초기화
document.addEventListener('DOMContentLoaded', loadApps);
