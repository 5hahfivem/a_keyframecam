(() => {
  const RESOURCE = 'camerakeyframer';

  const root = document.getElementById('root');
  const kfList = document.getElementById('kfList');
  const kfCountEl = document.getElementById('kfCount');
  const totalTimeEl = document.getElementById('totalTime');

  const coordX = document.getElementById('coordX');
  const coordY = document.getElementById('coordY');
  const coordZ = document.getElementById('coordZ');
  const rotXEl = document.getElementById('rotX');
  const rotYEl = document.getElementById('rotY');
  const rotZEl = document.getElementById('rotZ');
  const fovEl  = document.getElementById('fov');

  const addBtn    = document.getElementById('addBtn');
  const clearBtn  = document.getElementById('clearBtn');
  const playBtn   = document.getElementById('playBtn');
  const stopBtn   = document.getElementById('stopBtn');
  const exportBtn = document.getElementById('exportBtn');
  const closeBtn  = document.getElementById('closeBtn');

  const exportModal    = document.getElementById('exportModal');
  const exportText     = document.getElementById('exportText');
  const copyBtn        = document.getElementById('copyBtn');
  const exportCloseBtn = document.getElementById('exportCloseBtn');

  const progressBar = document.getElementById('progressBar');
  const toastEl     = document.getElementById('toast');

  let keyframes = [];
  let toastTimer;

  const post = (name, body = {}) =>
    fetch(`https://${RESOURCE}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body),
    })
      .then((r) => r.json().catch(() => ({})))
      .catch(() => ({}));

  const toast = (text) => {
    toastEl.textContent = text;
    toastEl.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('show'), 1800);
  };

  const fmt = (n, d = 1) => (typeof n === 'number' ? n.toFixed(d) : '0');

  const render = () => {
    kfCountEl.textContent = `${keyframes.length} keyframe${keyframes.length === 1 ? '' : 's'}`;
    const total = keyframes.reduce((s, k) => s + (k.duration || 0), 0);
    totalTimeEl.textContent = `${(total / 1000).toFixed(1)}s total`;

    playBtn.disabled = keyframes.length < 2 || document.body.classList.contains('playing');

    if (keyframes.length === 0) {
      kfList.innerHTML =
        '<li class="kf-empty">No keyframes yet. Press <kbd>Enter</kbd> to capture.</li>';
      return;
    }

    kfList.innerHTML = '';
    keyframes.forEach((k, i) => {
      const li = document.createElement('li');
      li.className = 'kf-item';
      li.innerHTML = `
        <div class="kf-num">#${i + 1}</div>
        <div class="kf-info">
          <div class="kf-pos">
            <span>X ${fmt(k.pos.x)}</span>
            <span>Y ${fmt(k.pos.y)}</span>
            <span>Z ${fmt(k.pos.z)}</span>
          </div>
          <div class="kf-rot">
            <span>P ${fmt(k.rot.x, 0)}°</span>
            <span>R ${fmt(k.rot.y, 0)}°</span>
            <span>Y ${fmt(k.rot.z, 0)}°</span>
            <span>FOV ${fmt(k.fov, 0)}</span>
          </div>
        </div>
        <div class="kf-actions">
          <div class="dur">
            <button class="btn-icon" data-act="dur-dec" title="-0.25s">−</button>
            <span>${(k.duration / 1000).toFixed(2)}s</span>
            <button class="btn-icon" data-act="dur-inc" title="+0.25s">+</button>
          </div>
          <div class="row-actions">
            <button class="btn-icon" data-act="up"   title="Move up">↑</button>
            <button class="btn-icon" data-act="down" title="Move down">↓</button>
            <button class="btn-icon" data-act="goto" title="Go to">◎</button>
            <button class="btn-icon danger" data-act="del" title="Delete">×</button>
          </div>
        </div>
      `;
      li.querySelectorAll('[data-act]').forEach((btn) =>
        btn.addEventListener('click', () => handleAction(k, btn.dataset.act))
      );
      kfList.appendChild(li);
    });
  };

  const handleAction = (kf, act) => {
    switch (act) {
      case 'dur-dec':
        post('setDuration', { id: kf.id, duration: Math.max(100, kf.duration - 250) });
        break;
      case 'dur-inc':
        post('setDuration', { id: kf.id, duration: kf.duration + 250 });
        break;
      case 'up':   post('moveKeyframe',  { id: kf.id, dir: -1 }); break;
      case 'down': post('moveKeyframe',  { id: kf.id, dir:  1 }); break;
      case 'goto': post('gotoKeyframe',  { id: kf.id }); break;
      case 'del':  post('deleteKeyframe',{ id: kf.id }); break;
    }
  };

  addBtn   .addEventListener('click', () => post('addKeyframe'));
  playBtn  .addEventListener('click', () => post('play'));
  stopBtn  .addEventListener('click', () => post('stop'));
  closeBtn .addEventListener('click', () => post('close'));

  clearBtn.addEventListener('click', () => {
    if (keyframes.length && confirm('Clear all keyframes?')) post('clearKeyframes');
  });

  exportBtn.addEventListener('click', async () => {
    const res = await post('export');
    let pretty;
    try { pretty = JSON.stringify(JSON.parse(res.json || '[]'), null, 2); }
    catch { pretty = res.json || '[]'; }
    exportText.value = pretty;
    exportModal.classList.remove('hidden');
    setTimeout(() => exportText.focus(), 20);
  });

  exportCloseBtn.addEventListener('click', () => exportModal.classList.add('hidden'));
  exportModal.addEventListener('click', (e) => {
    if (e.target === exportModal) exportModal.classList.add('hidden');
  });

  copyBtn.addEventListener('click', async () => {
    exportText.select();
    let ok = false;
    try {
      await navigator.clipboard.writeText(exportText.value);
      ok = true;
    } catch {
      try { ok = document.execCommand('copy'); } catch { /* idk if this still works in fivem lol */ }
    }
    copyBtn.textContent = ok ? 'Copied!' : 'Press Ctrl+C';
    setTimeout(() => (copyBtn.textContent = 'Copy JSON'), 1400);
  });

  window.addEventListener('message', (e) => {
    const msg = e.data || {};
    switch (msg.action) {
      case 'setVisible':
        root.classList.toggle('hidden', !msg.visible);
        if (msg.visible) render();
        break;

      case 'keyframes':
        keyframes = msg.keyframes || [];
        render();
        break;

      case 'cam':
        coordX.textContent = fmt(msg.pos.x);
        coordY.textContent = fmt(msg.pos.y);
        coordZ.textContent = fmt(msg.pos.z);
        rotXEl.textContent = fmt(msg.rot.x, 0);
        rotYEl.textContent = fmt(msg.rot.y, 0);
        rotZEl.textContent = fmt(msg.rot.z, 0);
        fovEl .textContent = fmt(msg.fov,   0);
        break;

      case 'playing':
        document.body.classList.toggle('playing', !!msg.state);
        stopBtn.disabled = !msg.state;
        playBtn.disabled = !!msg.state || keyframes.length < 2;
        if (!msg.state) progressBar.style.width = '0%';
        break;

      case 'phase':
        progressBar.style.width = `${Math.min(100, (msg.phase || 0) * 100)}%`;
        break;

      case 'toast':
        toast(msg.text || '');
        break;
    }
  });
})();
