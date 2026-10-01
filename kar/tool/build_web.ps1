# Build la PWA KAR avec cache offline.
# 1. flutter build web (sans CDN pour embarquer CanvasKit localement -> rendu hors-ligne)
# 2. remplace le service worker stub de Flutter par notre service worker offline
& flutter build web --no-web-resources-cdn $args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item -LiteralPath "web\service_worker.js" -Destination "build\web\flutter_service_worker.js" -Force
Write-Host "service worker offline installe dans build\web\flutter_service_worker.js"