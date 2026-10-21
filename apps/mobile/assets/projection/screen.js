// Écran projeté (Phase 8, ADR-013) : affiche la diapositive envoyée par le
// téléphone pilote via WebSocket. Lecture seule : l'écran n'envoie aucune
// commande. Aucune ressource externe : fonctionne sans Internet.
(function () {
  'use strict';

  var stage = document.getElementById('stage');
  var content = document.getElementById('content');
  var hint = document.getElementById('hint');
  var status = document.getElementById('status');
  var storageKey = 'lad-projection-state';
  var lastState = null;
  // Écran retour (musiciens, orateur) : diapositive en cours et suivante,
  // même pendant un écran noir ou masqué.
  var retour = new URLSearchParams(window.location.search).get('role') === 'retour';
  if (retour) document.body.classList.add('retour');

  var SECTION_NAMES = {
    verse: 'Couplet',
    refrain: 'Refrain',
    bridge: 'Pont',
    intro: 'Introduction',
    outro: 'Conclusion',
  };

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
  }

  function sectionName(slide, showNumber) {
    var name = SECTION_NAMES[slide.sectionType] || '';
    if (slide.sectionNumber !== null && slide.sectionNumber !== undefined) {
      name += ' ' + slide.sectionNumber;
    }
    if (slide.parts > 1) name += ' (' + slide.part + '/' + slide.parts + ')';
    return showNumber ? slide.numberLabel + ' · ' + name : name;
  }

  // Libellé court (écran retour) : « 125 — Titre », « Couplet 2 », message.
  function shortLabel(slide) {
    if (!slide) return '';
    if (slide.kind === 'title') return slide.numberLabel + ' — ' + slide.title;
    if (slide.kind === 'section') return slide.label;
    if (slide.kind === 'end') return slide.message;
    if (slide.kind === 'transition') return 'Transition';
    return sectionName(slide, false) + ' : ' + (slide.lines[0] || '');
  }

  function brand(box) {
    box.appendChild(el('p', 'brand', 'Louanges à Dieu'));
    return { node: box, max: 0.09 };
  }

  function build(slide, display) {
    var box = el('div', 'content');
    var showNumber = display.showNumber !== false;
    if (!slide || slide.kind === 'transition') {
      if (slide) box.className += ' transition';
      return brand(box);
    }
    if (slide.kind === 'end') {
      box.className += ' end';
      box.appendChild(el('p', 'brand', 'Louanges à Dieu'));
      box.appendChild(el('p', 'title', slide.message));
      return { node: box, max: 0.12 };
    }
    if (slide.kind === 'title') {
      if (showNumber) box.appendChild(el('p', 'number', slide.numberLabel));
      box.appendChild(el('p', 'title', slide.title));
      return { node: box, max: 0.14 };
    }
    if (slide.kind === 'section') {
      box.appendChild(el('p', 'label', slide.label));
      return { node: box, max: 0.12 };
    }
    if (slide.sectionType === 'refrain') box.className += ' refrain';
    box.appendChild(el('p', 'section-name', sectionName(slide, showNumber)));
    var lines = el('div', 'lines');
    for (var i = 0; i < slide.lines.length; i++) lines.appendChild(el('p', null, slide.lines[i]));
    box.appendChild(lines);
    return { node: box, max: 0.11 };
  }

  // Écran retour : diapositive en cours (réduite), position, et la suivante.
  function buildRetour(state) {
    var box = el('div', 'content');
    var built = build(state.slide, { showNumber: true });
    built.node.className += ' current';
    box.appendChild(built.node);
    var info = el('p', 'retour-info', (state.index + 1) + ' / ' + state.count);
    if (state.blank) info.textContent += ' · écran noir';
    else if (state.mask) info.textContent += ' · écran masqué';
    box.appendChild(info);
    box.appendChild(el('p', 'retour-next', state.next ? 'Ensuite : ' + shortLabel(state.next) : 'Fin'));
    return { node: box, max: 0.07 };
  }

  // Fond : sombre (thème projection), clair, ou photo voilée de l'app.
  function applyDisplay(display) {
    var light = !retour && display.background === 'light';
    document.documentElement.setAttribute('data-theme', light ? 'light' : 'projection');
    var photo = !retour && display.background === 'image' && /^images\/[a-z0-9_]+\.jpg$/.test(display.image || '');
    document.body.classList.toggle('photo', photo);
    document.body.style.setProperty('--photo', photo ? 'url("' + display.image + '")' : 'none');
  }

  // Plus grande taille de texte qui tient dans l'écran (recherche dichotomique).
  function fit(node, maxRatio) {
    var low = 12;
    var high = Math.max(low, Math.floor(window.innerHeight * maxRatio));
    var width = stage.clientWidth * 0.88;
    var height = stage.clientHeight * 0.9;
    while (low < high) {
      var mid = Math.ceil((low + high) / 2);
      node.style.fontSize = mid + 'px';
      if (node.scrollWidth <= width && node.scrollHeight <= height) low = mid;
      else high = mid - 1;
    }
    node.style.fontSize = low + 'px';
  }

  function render(state) {
    lastState = state;
    var display = state.display || {};
    var scale = typeof display.scale === 'number' ? Math.min(1.3, Math.max(0.7, display.scale)) : 1;
    applyDisplay(display);
    document.body.classList.toggle('blank', !retour && !!state.blank);
    var built = retour
      ? buildRetour(state)
      : state.mask
        ? brand(el('div', 'content masked'))
        : build(state.slide, display);
    stage.replaceChild(built.node, content);
    content = built.node;
    fit(content, built.max * scale);
  }

  function save(state) {
    try {
      sessionStorage.setItem(storageKey, JSON.stringify(state));
    } catch (e) {
      /* stockage indisponible : sans effet */
    }
  }

  // Dernière diapositive connue : affichée même si la page est rechargée
  // pendant une coupure.
  try {
    var saved = sessionStorage.getItem(storageKey);
    if (saved) render(JSON.parse(saved));
  } catch (e) {
    /* rien à restaurer */
  }

  function handle(message) {
    if (message && message.type === 'state') {
      render(message);
      save(message);
    } else if (message && message.type === 'end') {
      render({ blank: false, slide: null });
      save({ blank: false, slide: null });
    }
  }

  // Téléphone pilote : WebSocket vers le serveur local de l'app.
  var delay = 500;
  function connect() {
    var url = new URL('ws', window.location.href);
    url.search = '';
    url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
    var socket;
    try {
      socket = new WebSocket(url.toString());
    } catch (e) {
      retry();
      return;
    }
    socket.onopen = function () {
      delay = 500;
      status.hidden = true;
    };
    socket.onmessage = function (event) {
      var message;
      try {
        message = JSON.parse(event.data);
      } catch (e) {
        return;
      }
      if (message && message.type === 'end') socket.onclose = null;
      handle(message);
    };
    socket.onclose = function () {
      status.hidden = false;
      retry();
    };
  }

  function retry() {
    setTimeout(connect, delay);
    delay = Math.min(5000, delay * 2);
  }

  // Ordinateur seul : fenêtre de contrôle du même navigateur (BroadcastChannel).
  // L'écran signale sa présence toutes les 2 s (« hello », aucune commande) et
  // la console lui renvoie l'état ; au-delà de 5 s sans nouvelles, on le signale.
  function connectLocal() {
    var channel = new BroadcastChannel('lad-projection');
    var lastSeen = 0;
    status.textContent = 'En attente de la fenêtre de contrôle…';
    channel.onmessage = function (event) {
      if (event.data && event.data.type === 'hello') return;
      lastSeen = Date.now();
      status.hidden = true;
      handle(typeof event.data === 'string' ? JSON.parse(event.data) : event.data);
    };
    channel.postMessage({ type: 'hello' });
    setInterval(function () {
      channel.postMessage({ type: 'hello' });
      status.hidden = Date.now() - lastSeen <= 5000;
    }, 2000);
  }

  window.addEventListener('resize', function () {
    if (lastState) render(lastState);
  });

  // Plein écran : clic ou touche F (les navigateurs l'exigent d'un geste).
  function toggleFullscreen() {
    if (document.fullscreenElement) document.exitFullscreen();
    else if (document.documentElement.requestFullscreen) document.documentElement.requestFullscreen();
  }
  document.addEventListener('click', toggleFullscreen);
  document.addEventListener('keydown', function (e) {
    if (e.key === 'f' || e.key === 'F') toggleFullscreen();
  });
  document.addEventListener('fullscreenchange', function () {
    hint.hidden = !!document.fullscreenElement;
  });

  // Curseur masqué après 3 s d'inactivité.
  var idleTimer;
  document.addEventListener('mousemove', function () {
    document.body.classList.remove('idle');
    clearTimeout(idleTimer);
    idleTimer = setTimeout(function () {
      document.body.classList.add('idle');
    }, 3000);
  });

  // Écran maintenu allumé quand le navigateur le permet (contexte sécurisé
  // requis) ; sinon, la mise en veille de l'ordinateur est à désactiver.
  var wakeLock = null;
  function keepAwake() {
    if (!('wakeLock' in navigator) || document.visibilityState !== 'visible') return;
    navigator.wakeLock.request('screen').then(
      function (lock) {
        wakeLock = lock;
      },
      function () {
        wakeLock = null;
      },
    );
  }
  document.addEventListener('visibilitychange', keepAwake);
  keepAwake();
  if (!('wakeLock' in navigator)) {
    hint.textContent += ' — pensez à désactiver la mise en veille de l’ordinateur';
  }

  if (new URLSearchParams(window.location.search).get('canal') === 'local' && 'BroadcastChannel' in window) {
    connectLocal();
  } else {
    connect();
  }
})();
