// Prepares ONLY the isolated preview build, never web/index.html or Firebase
// Hosting. Build with --no-web-resources-cdn -o build/foundation-web first.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final directory = arguments.isEmpty ? 'foundation-web' : arguments.single;
  if (!{'foundation-web','booking-sync-web'}.contains(directory)) throw ArgumentError('Only isolated synthetic builds can be prepared');
  final output = Directory('build/$directory').absolute;
  if (!File('${output.path}/main.dart.js').existsSync() ||
      !File('${output.path}/sqlite3.wasm').existsSync()) {
    throw StateError(
      'Build tool/foundation_preview.dart into build/foundation-web first.',
    );
  }
  await File('${output.path}/index.html').writeAsString(r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><base href="/">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Uvilo synthetic offline sandbox</title>
<style>body{margin:0;background:#f4fbfb;font:14px sans-serif;color:#1f3a3d}
#status{position:fixed;bottom:0;left:0;right:0;z-index:10000;padding:8px;background:#e5f3f4;text-align:center}
button{margin-left:12px}</style></head><body>
<div id="status" role="status">Preparing offline preview…</div>
<script>
(async () => {
  const status = document.getElementById('status');
  try {
    if (!('serviceWorker' in navigator)) throw Error('Service workers unavailable');
    await navigator.serviceWorker.register('foundation-sw.js');
    await Promise.race([navigator.serviceWorker.ready, new Promise((_, reject) => setTimeout(() => reject(Error('timeout')), 60000))]);
    status.textContent = 'Offline preview ready. Synthetic data only.';
  } catch (_) {
    status.textContent = 'Offline launch unavailable. Keep this page open while testing local saves.';
  }
  const dismiss = document.createElement('button');
  dismiss.textContent = 'Dismiss'; dismiss.onclick = () => status.remove(); status.append(dismiss);
})();
</script><script src="flutter_bootstrap.js" async></script>
</body></html>''');
  final files = <String>[];
  await for (final entry in output.list(recursive: true, followLinks: false)) {
    if (entry is! File) continue;
    final relative = entry.path
        .substring(output.path.length + 1)
        .replaceAll('\\', '/');
    if (relative == 'foundation-sw.js' ||
        relative.endsWith('.map') ||
        relative.endsWith('.symbols') ||
        relative == 'flutter_service_worker.js') {
      continue;
    }
    files.add(Uri(path: relative).toString());
  }
  files.sort();
  final version = DateTime.now().toUtc().microsecondsSinceEpoch;
  await File('${output.path}/foundation-sw.js').writeAsString('''
// Synthetic preview app shell only. Never caches API requests or responses.
const PREFIX = 'uvilo-foundation-shell-' + encodeURIComponent(self.registration.scope) + '-';
const CACHE = PREFIX + '$version';
const FILES = ${jsonEncode(files)};
const URLS = new Set(FILES.map(path => new URL(path, self.registration.scope).href));
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(FILES)));
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith(PREFIX) && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  const root = new URL('./', self.registration.scope).href;
  const resource = event.request.mode === 'navigate' && url.href === root
    ? new URL('index.html', root).href : url.href;
  if (!URLS.has(resource)) return;
  event.respondWith(caches.open(CACHE).then(async cache =>
    (await cache.match(resource)) || fetch(event.request)));
});
''');
  stdout.writeln(
    'Prepared isolated offline preview: ${output.path} (${files.length} static files).',
  );
}
