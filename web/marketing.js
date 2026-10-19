/* The public homepage is independent of Firebase; Flutter starts for app routes. */
(() => {
  const rootPath = new URL(document.baseURI).pathname;
  const isPublicPath = () => location.pathname === rootPath || location.pathname === `${rootPath}index.html`;
  const isAppRoute = () => location.hash.startsWith('#/') || !isPublicPath();
  let appStarted = false;
  function openExperience() {
    if (!isAppRoute()) {
      if (appStarted) location.reload();
      return;
    }
    if (appStarted) return;
    appStarted = true;
    document.documentElement.dataset.experience = 'app';
    document.getElementById('marketing').inert = true;
    document.getElementById('loading').hidden = false;
    const bootstrap = document.createElement('script');
    bootstrap.src = new URL('flutter_bootstrap.js', document.baseURI).href;
    bootstrap.addEventListener('error', () => { document.getElementById('load-error').hidden = false; });
    document.body.append(bootstrap);
  }
  window.addEventListener('hashchange', () => {
    // Give Flutter a fresh document when entering the app so its initial URL
    // is the selected route, rather than the earlier public homepage URL.
    if (!appStarted && isAppRoute()) location.reload();
    else openExperience();
  });
  openExperience();
})();
