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
  const audiences = {
    doctor: {title: 'Walk into every consultation with context.', body: 'Review patient records, manage visits and create prescriptions in a connected clinical workflow.', points: ['Patient history close at hand', 'Appointments and consultations connected', 'Prescription and follow-up workflows']},
    team: {title: 'Make the handoff feel effortless.', body: 'Keep reception, appointments, billing and pharmacy tasks connected to the same clinic workflow.', points: ['Patient registration and appointment coordination', 'Clear visit status for the next team member', 'Billing and stock workflows in the same product']},
    owner: {title: 'A clearer view of your growing practice.', body: 'Bring clinics and team members into one platform, with access organised around their responsibilities.', points: ['Multiple clinics in one organisation', 'Clinic-specific team roles and permissions', 'Connected inventory, billing and clinic operations']},
  };
  document.querySelectorAll('[data-audience]').forEach((button) => {
    button.addEventListener('click', () => {
      const copy = audiences[button.dataset.audience];
      if (!copy) return;
      document.querySelectorAll('[data-audience]').forEach((item) => item.setAttribute('aria-pressed', String(item === button)));
      const panel = document.getElementById('audience-copy');
      panel.querySelector('h3').textContent = copy.title;
      panel.querySelector('p').textContent = copy.body;
      panel.querySelector('ul').replaceChildren(...copy.points.map((text) => { const item = document.createElement('li'); item.textContent = text; return item; }));
    });
  });
  window.addEventListener('hashchange', () => {
    // Give Flutter a fresh document when entering the app so its initial URL
    // is the selected route, rather than the earlier public homepage URL.
    if (!appStarted && isAppRoute()) location.reload();
    else openExperience();
  });
  openExperience();
})();
