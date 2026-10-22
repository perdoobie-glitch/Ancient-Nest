'use strict';

(() => {
  const buttons = [...document.querySelectorAll('.menu-item')];
  const dialog = document.querySelector('#menu-dialog');
  const title = document.querySelector('#dialog-title');
  const content = document.querySelector('#dialog-content');
  const farewell = document.querySelector('#farewell');
  const storageKey = 'ancient-nest-menu-settings-v1';
  let selected = 0;
  let audio;
  let settings = { volume: 35, sounds: true };

  try {
    const stored = JSON.parse(localStorage.getItem(storageKey));
    if (stored && Number.isFinite(stored.volume)) settings.volume = Math.max(0, Math.min(100, stored.volume));
    if (stored && typeof stored.sounds === 'boolean') settings.sounds = stored.sounds;
  } catch { /* The menu also works when browser storage is unavailable. */ }

  function saveSettings() {
    try { localStorage.setItem(storageKey, JSON.stringify(settings)); } catch { /* Session settings remain usable. */ }
  }

  function chime() {
    if (!settings.sounds || settings.volume === 0) return;
    try {
      const Audio = window.AudioContext || window.webkitAudioContext;
      if (!Audio) return;
      audio ||= new Audio();
      if (audio.state === 'suspended') void audio.resume().catch(() => {});
      const tone = audio.createOscillator();
      const gain = audio.createGain();
      tone.type = 'sine';
      tone.frequency.setValueAtTime(660, audio.currentTime);
      tone.frequency.exponentialRampToValueAtTime(440, audio.currentTime + .12);
      gain.gain.setValueAtTime(Math.max(.0001, settings.volume / 100 * .06), audio.currentTime);
      gain.gain.exponentialRampToValueAtTime(.0001, audio.currentTime + .18);
      tone.connect(gain);
      gain.connect(audio.destination);
      tone.start();
      tone.stop(audio.currentTime + .18);
    } catch { /* Sound support is optional. */ }
  }

  function select(index, focus = false) {
    selected = (index + buttons.length) % buttons.length;
    buttons.forEach((button, i) => button.classList.toggle('is-selected', i === selected));
    if (focus) buttons[selected].focus();
  }

  function openPanel(heading, html) {
    title.textContent = heading;
    content.innerHTML = html;
    dialog.showModal();
  }

  function openSettings() {
    openPanel('Settings', `
      <label class="setting" for="volume">Menu volume
        <input id="volume" type="range" min="0" max="100" value="${settings.volume}">
        <output id="volume-value" for="volume">${settings.volume}</output>
      </label>
      <label class="setting" for="sounds">Menu sounds
        <input id="sounds" type="checkbox" ${settings.sounds ? 'checked' : ''}>
      </label>
      <p>Changes are saved on this device.</p>
    `);
    content.querySelector('#volume').addEventListener('input', event => {
      settings.volume = Number(event.target.value);
      content.querySelector('#volume-value').value = settings.volume;
      saveSettings();
    });
    content.querySelector('#volume').addEventListener('change', chime);
    content.querySelector('#sounds').addEventListener('change', event => {
      settings.sounds = event.target.checked;
      saveSettings();
      chime();
    });
  }

  function activate(action) {
    chime();
    if (action === 'settings') { openSettings(); return; }
    if (action === 'play') {
      openPanel('Play', '<p>Your adventure awaits.</p><p>This is a main-menu preview. Gameplay has not been added yet.</p>');
      return;
    }
    if (action === 'custom') {
      openPanel('Custom Match', '<p>Custom matches will be available when gameplay is added.</p>');
      return;
    }
    if (action === 'quit') {
      farewell.hidden = false;
      document.querySelector('.main-menu').inert = true;
      document.querySelector('#return-button').focus();
    }
  }

  function returnToMenu() {
    farewell.hidden = true;
    document.querySelector('.main-menu').inert = false;
    select(selected, true);
  }

  buttons.forEach((button, i) => {
    button.addEventListener('pointerenter', () => select(i));
    button.addEventListener('focus', () => select(i));
    button.addEventListener('click', () => activate(button.dataset.action));
  });

  document.addEventListener('keydown', event => {
    if (dialog.open) return;
    if (!farewell.hidden) {
      if (event.key === 'Escape') { event.preventDefault(); returnToMenu(); }
      return;
    }
    const direction = { ArrowRight: 1, ArrowLeft: -1, ArrowDown: 1, ArrowUp: -1 }[event.key];
    if (direction) { event.preventDefault(); select(selected + direction, true); }
    else if (event.key === 'Home') { event.preventDefault(); select(0, true); }
    else if (event.key === 'End') { event.preventDefault(); select(buttons.length - 1, true); }
    else if (event.key === 'Enter' && !buttons.includes(document.activeElement)) {
      event.preventDefault(); buttons[selected].click();
    }
  });

  dialog.addEventListener('close', () => select(selected, true));
  document.querySelector('#return-button').addEventListener('click', returnToMenu);
})();
