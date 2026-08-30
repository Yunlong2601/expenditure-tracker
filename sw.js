// Expenditure Tracker Service Worker - 离线缓存策略（参考 FRAGILISTIC-lab/routine-tracker 的 sw.js）
// 采用 Cache First + 运行时缓存，保证离线可用

const CACHE_NAME = 'cute-tracker-v1.0.0';

// 安装时预缓存应用外壳（参考 routine-tracker 的 install 逻辑）
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll([
        '/expenditure-tracker/',
        '/expenditure-tracker/index.html',
        '/expenditure-tracker/manifest.json',
        '/expenditure-tracker/favicon.svg',
      ]).catch(() => {
        // 预缓存失败时不影响安装（资源可能尚不存在）
        console.log('[SW] 预缓存部分失败，运行时将补全');
      });
    })
  );
  self.skipWaiting();
});

// 激活时清理旧缓存（参考 routine-tracker 的版本管理）
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

// 运行时缓存：先读缓存，否则网络请求并缓存（Cache First 策略）
self.addEventListener('fetch', (event) => {
  const { request } = event;

  // 只处理同源 GET 请求（避免跨域缓存问题）
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) {
    return;
  }

  event.respondWith(
    caches.match(request).then((cachedResponse) => {
      if (cachedResponse) {
        return cachedResponse;
      }
      return fetch(request)
        .then((response) => {
          // 只缓存成功的响应（状态码 200）
          if (response && response.status === 200 && response.type === 'basic') {
            const responseToCache = response.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(request, responseToCache);
            });
          }
          return response;
        })
        .catch(() => {
          // 离线且缓存未命中：返回首页（SPA 兜底）
          if (request.mode === 'navigate') {
            return caches.match('/expenditure-tracker/index.html');
          }
        });
    })
  );
});
