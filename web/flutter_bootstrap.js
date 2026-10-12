{{flutter_js}}
{{flutter_build_config}}

const loading = document.getElementById('loading');

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const message = loading?.querySelector('span');
    if (message) message.textContent = 'Starting orByteza Clinic Solution…';

    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    loading?.remove();
  },
});
