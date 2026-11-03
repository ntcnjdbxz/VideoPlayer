(function () {
  if (window.__streamShelfInstalled) return;
  window.__streamShelfInstalled = true;

  function send(data) {
    try { window.webkit.messageHandlers.streamShelf.postMessage(data); } catch (_) {}
  }

  function cleanAds() {
    const selectors = ['[class*="popup"]','[id*="popup"]','[class*="advert"]',
      '[id*="advert"]','[class*="banner"]','[class*="overlay"]'];
    selectors.forEach(s => document.querySelectorAll(s).forEach(el => {
      const name = ((el.className || '') + ' ' + (el.id || '')).toLowerCase();
      if (/popup|advert|banner|overlay|adsby/.test(name) && !el.querySelector('video')) {
        el.style.setProperty('display', 'none', 'important');
      }
    }));
  }

  function report() {
    const video = document.querySelector('video');
    const frames = Array.from(document.querySelectorAll('iframe')).map((f, i) => ({
      id: i, title: f.title || f.getAttribute('data-name') || ('Player ' + (i + 1)),
      src: f.src || f.getAttribute('data-src') || ''
    })).filter(f => f.src);
    send({
      type: 'metadata',
      title: document.title || '',
      url: location.href,
      seasonText: (document.title || '') + ' ' + location.href,
      position: video ? (video.currentTime || 0) : null,
      duration: video && isFinite(video.duration) ? video.duration : null,
      frames: frames
    });
  }

  function attach() {
    document.querySelectorAll('video').forEach(v => {
      if (v.__streamShelf) return;
      v.__streamShelf = true;
      ['timeupdate','pause','ended','loadedmetadata'].forEach(e => v.addEventListener(e, report));
    });
  }

  const observer = new MutationObserver(() => { cleanAds(); attach(); });
  if (document.documentElement) observer.observe(document.documentElement, {childList:true, subtree:true});
  cleanAds(); attach(); report();
  setInterval(report, 5000);
  window.open = function () { return null; };
})();
