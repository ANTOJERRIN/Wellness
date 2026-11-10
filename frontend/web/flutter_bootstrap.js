{{flutter_js}}
{{flutter_build_config}}

(() => {
  let rendered = false;
  function showFailure(error) {
    if (rendered) return;
    console.error('Wellness startup failed', error);
    document.getElementById('startup-message').textContent =
      'Wellness could not finish loading. Please try again. If this continues, check the browser console for the startup error.';
    document.getElementById('startup-retry').hidden = false;
  }
  const timeout = setTimeout(() => showFailure('Startup timed out'), 45000);
  window.addEventListener('flutter-first-frame', () => {
    rendered = true;
    clearTimeout(timeout);
    document.getElementById('startup')?.remove();
  }, { once: true });
  window.addEventListener('unhandledrejection', (event) => showFailure(event.reason));
  window.addEventListener('error', (event) => showFailure(event.error || event.message));

  _flutter.loader.load({
    config: { canvasKitBaseUrl: 'canvaskit/' },
    onEntrypointLoaded: async (engineInitializer) => {
      try {
        const appRunner = await engineInitializer.initializeEngine();
        await appRunner.runApp();
      } catch (error) {
        showFailure(error);
      }
    },
  }).catch(showFailure);
})();
