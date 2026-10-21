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


  // ------------------------------------------------------------- karaoké
  // Le téléphone envoie tous les vers et leurs instants, avec l'horloge de
  // lecture ; l'écran fait avancer l'horloge entre deux messages pour que
  // le vers se remplisse sans à-coups (son sur le téléphone).
  var karaoke = null;
  var karaokeKey = null;
  var karaokeFrame = null;

  function karaokePosition() {
    var k = karaoke;
    return k.message.position + (k.message.playing ? performance.now() - k.receivedAt : 0);
  }

  function seconds(ms) {
    return Math.ceil(ms / 1000);
  }

  function karaokeLine(text, className) {
    return el('p', className, text);
  }

  // Phase courante : vers chanté, prochain vers, comptes à rebours.
  function karaokePhase(lines, pos) {
    var current = -1;
    for (var i = 0; i < lines.length; i++) {
      if (pos >= lines[i].start && pos < lines[i].end) current = i;
    }
    var upcoming = current;
    if (current < 0) {
      upcoming = -1;
      for (var j = 0; j < lines.length; j++) {
        if (lines[j].start > pos) {
          upcoming = j;
          break;
        }
      }
    }
    return { current: current, upcoming: upcoming };
  }

  // Ce qui est affiché à l'instant pos ; la clé change quand le contenu
  // doit être reconstruit (autre vers, compte à rebours).
  function karaokeView(message, pos) {
    var lines = message.lines || [];
    var phase = karaokePhase(lines, pos);
    if (lines.length === 0 || (phase.current < 0 && phase.upcoming === 0)) {
      var wait = lines.length ? lines[0].start - pos : 0;
      return { kind: 'intro', phase: phase, wait: wait, key: 'intro|' + (wait > 0 ? seconds(wait) : 0) };
    }
    if (phase.upcoming < 0) return { kind: 'end', phase: phase, key: 'end' };
    var rest = phase.current < 0 ? lines[phase.upcoming].start - pos : 0;
    return {
      kind: 'line',
      phase: phase,
      rest: rest,
      key: 'line|' + phase.upcoming + '|' + (phase.current >= 0) + '|' + (rest >= 1000 ? seconds(rest) : 0),
    };
  }

  function buildKaraoke(message, view) {
    var lines = message.lines || [];
    var box = el('div', 'content karaoke');
    if (view.kind === 'intro') {
      box.appendChild(el('p', 'number', message.numberLabel));
      box.appendChild(el('p', 'title', message.title));
      if (view.wait > 0) box.appendChild(el('p', 'k-wait', 'Début dans ' + seconds(view.wait) + ' s'));
      if (lines.length) box.appendChild(karaokeLine(lines[0].text, 'k-line'));
    } else if (view.kind === 'end') {
      box.appendChild(el('p', 'brand', 'Louanges à Dieu'));
      box.appendChild(karaokeLine(lines[lines.length - 1].text, 'k-line'));
    } else {
      var i = view.phase.upcoming;
      if (i > 0) box.appendChild(karaokeLine(lines[i - 1].text, 'k-line'));
      if (view.rest >= 1000) box.appendChild(el('p', 'k-wait', '♪ Reprise dans ' + seconds(view.rest) + ' s'));
      if (i === 0 || lines[i].section !== lines[i - 1].section) {
        box.appendChild(el('p', 'section-name', lines[i].sectionName));
      }
      var sung = el('p', 'k-sung');
      sung.appendChild(el('span', view.phase.current >= 0 ? 'k-fill' : null, lines[i].text));
      box.appendChild(sung);
      for (var n = i + 1; n <= i + 2 && n < lines.length; n++) {
        box.appendChild(karaokeLine(lines[n].text, 'k-line'));
      }
    }
    return box;
  }

  // Une image : reconstruit le contenu s'il change, sinon fait seulement
  // avancer le remplissage du vers chanté.
  function karaokeTick() {
    karaokeFrame = null;
    if (!karaoke) return;
    var message = karaoke.message;
    var pos = karaokePosition();
    var view = karaokeView(message, pos);
    if (view.key !== karaokeKey) {
      karaokeKey = view.key;
      var node = buildKaraoke(message, view);
      stage.replaceChild(node, content);
      content = node;
    }
    var fill = content.querySelector('.k-fill');
    if (fill && view.phase.current >= 0) {
      var line = message.lines[view.phase.current];
      var f = Math.min(1, Math.max(0, (pos - line.start) / Math.max(1, line.end - line.start)));
      fill.style.setProperty('--fill', (f * 100).toFixed(2) + '%');
    }
    karaokeFrame = requestAnimationFrame(karaokeTick);
  }

  function renderKaraoke(message) {
    document.body.classList.remove('blank', 'photo');
    document.body.classList.add('karaoke-mode');
    document.documentElement.setAttribute('data-theme', 'projection');
    karaoke = { message: message, receivedAt: performance.now() };
    karaokeKey = null;
    if (karaokeFrame === null) karaokeFrame = requestAnimationFrame(karaokeTick);
  }

  function stopKaraoke() {
    karaoke = null;
    karaokeKey = null;
    document.body.classList.remove('karaoke-mode');
    if (karaokeFrame !== null) cancelAnimationFrame(karaokeFrame);
    karaokeFrame = null;
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
    if (message && message.type === 'karaoke') {
      renderKaraoke(message);
    } else if (message && message.type === 'state') {
      stopKaraoke();
      render(message);
      save(message);
    } else if (message && message.type === 'end') {
      stopKaraoke();
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
    if (!karaoke && lastState) render(lastState);
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
