'use strict';

// Service worker pour la PWA KAR.
// A la fin du build, ce fichier est copié vers build/web/flutter_service_worker.js
// (voir tool/build_web.ps1) car la génération Flutter ne fournit plus de cache offline.
const CACHE = 'kar-v3';

const SHELL = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'sqlite3.wasm',
  'assets/FontManifest.json',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
];

// Fichiers qui changent à chaque build : réseau d'abord, cache en secours.
const DYNAMIC = ['main.dart.js', 'flutter_bootstrap.js', 'flutter.js'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => _precache(cache))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith(_networkFirst(request, './'));
    return;
  }

  if (DYNAMIC.some((file) => url.pathname === '/' + file || url.pathname.endsWith('/' + file))) {
    event.respondWith(_networkFirst(request));
    return;
  }

  event.respondWith(_cacheFirst(request));
});

async function _precache(cache) {
  await cache.addAll(SHELL);

  // Module de rendu (build avec --no-web-resources-cdn)
  const rendererFiles = [
    'canvaskit/canvaskit.js',
    'canvaskit/canvaskit.wasm',
    'canvaskit/chromium/canvaskit.js',
    'canvaskit/chromium/canvaskit.wasm',
  ];
  for (const file of rendererFiles) {
    try {
      await cache.add(file);
    } catch (e) {
      // certains fichiers de rendu sont optionnels selon la config
    }
  }

  // Polices déclarées dans le manifest Flutter
  try {
    const response = await fetch('assets/FontManifest.json');
    const fonts = await response.json();
    for (const entry of fonts) {
      if (entry && Array.isArray(entry.fonts)) {
        for (const font of entry.fonts) {
          if (font && font.asset) {
            try {
              await cache.add('assets/' + font.asset);
            } catch (e) {
              // police manquante : ignorée
            }
          }
        }
      }
    }
  } catch (e) {
    // manifest des polices absent : les polices seront cachées au fil de l'eau
  }
}

async function _cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  try {
    const response = await fetch(request);
    if (response && response.ok) {
      _cachePut(request, response.clone());
    }
    return response;
  } catch (e) {
    return new Response('', { status: 408, statusText: 'Unavailable offline' });
  }
}

async function _networkFirst(request, fallbackPath) {
  try {
    const response = await fetch(request);
    if (response && response.ok) {
      _cachePut(request, response.clone());
    }
    return response;
  } catch (e) {
    const cached = await caches.match(request);
    if (cached) return cached;
    if (fallbackPath) {
      return (
        (await caches.match(fallbackPath)) ||
        (await caches.match('index.html')) || new Response('', { status: 404 })
      );
    }
    return new Response('', { status: 404 });
  }
}

function _cachePut(request, response) {
  caches.open(CACHE).then((cache) => cache.put(request, response));
}