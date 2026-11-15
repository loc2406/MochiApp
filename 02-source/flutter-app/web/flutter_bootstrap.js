{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      window._setMochiiStatus('Đang khởi tạo giao diện học tập…');
      const appRunner = await engineInitializer.initializeEngine();
      window._setMochiiStatus('Đang mở ứng dụng Mochii…');
      await appRunner.runApp();
      // The HTML overlay is removed only by flutter-first-frame in index.html.
      // No time-based fake completion and no removal before Flutter paints.
    } catch (error) {
      window._showMochiiStartupError();
      console.error('Mochii could not start the rendering engine.', error);
    }
  }
});
