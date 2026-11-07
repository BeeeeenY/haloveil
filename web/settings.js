// Modified from HALOFLUX by Ryder191. Personal, noncommercial use only.
// Preset A matches the complete configuration exported from the user's running
// original. Quality profiles control rendering budgets, not scene parameters.
(() => {
  const profiles = {
    original: {
      fps: 0, // Every browser animation frame; no additional 60 FPS gate.
      maxPixelRatio: 2,
      maxStagePixels: 0, // Match upstream: no total pixel cap.
      panelFPS: 0, // Redraw the small canvases on every animation frame.
      ringCacheScale: 2.4,
      originalCompositing: true,
    },
    balanced: {
      fps: 60,
      maxPixelRatio: 1.25,
      maxStagePixels: 800000,
      panelFPS: 20,
      ringCacheScale: 1.6,
      originalCompositing: false,
    },
  };
  const requested = new URLSearchParams(window.location.search).get('quality');
  const qualityProfile = Object.prototype.hasOwnProperty.call(profiles, requested) ? requested :
    (window.HALOVEIL_NATIVE && !window.HALOVEIL_PREVIEW ? 'balanced' : 'original');
  window.HALOVEIL_SETTINGS = Object.freeze({
    preset: 'A', qualityProfile, ...profiles[qualityProfile],
    tempo: 1,
    ringSpeed: 1,
    ringPause: 1,
    cameraIntensity: 1, // Applied to C.camZoom.
  });
})();
