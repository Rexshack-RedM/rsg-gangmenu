(() => {
  const app = document.getElementById('app');
  const view = document.getElementById('view');
  const titleEl = document.getElementById('title');
  const subtitleEl = document.getElementById('subtitle');
  const btnBack = document.getElementById('btnBack');
  const btnClose = document.getElementById('btnClose');

  const modalRoot = document.getElementById('modalRoot');
  const modalTitle = document.getElementById('modalTitle');
  const modalBody = document.getElementById('modalBody');
  const modalInputWrap = document.getElementById('modalInputWrap');
  const modalInput = document.getElementById('modalInput');
  const modalCancel = document.getElementById('modalCancel');
  const modalConfirm = document.getElementById('modalConfirm');

  let L = {};
  let stack = [];
  let modalCb = null;

  function post(name, data) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(() => {});
  }

  function money(n) {
    const s = String(Math.floor(Number(n) || 0));
    return s.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  }

  function setHeader(title, subtitle, showBack) {
    titleEl.textContent = title || L.menu || 'Gang Menu';
    subtitleEl.textContent = subtitle || '';
    btnBack.style.visibility = showBack ? 'visible' : 'hidden';
  }

  function rowEl(opts) {
    const row = document.createElement('div');
    row.className = 'row' + (opts.disabled ? ' disabled' : '') + (opts.danger ? ' danger' : '');
    if (opts.icon) {
      const badge = document.createElement('div');
      badge.className = 'badge-icon';
      badge.textContent = opts.icon;
      row.appendChild(badge);
    }
    if (opts.status) {
      const st = document.createElement('div');
      st.className = 'status';
      st.textContent = opts.status;
      row.appendChild(st);
    }
    const text = document.createElement('div');
    text.className = 'row-text';
    const t = document.createElement('div');
    t.className = 'row-title';
    t.textContent = opts.title || '';
    text.appendChild(t);
    if (opts.desc) {
      const d = document.createElement('div');
      d.className = 'row-desc';
      d.textContent = opts.desc;
      text.appendChild(d);
    }
    row.appendChild(text);
    if (opts.pill) {
      const p = document.createElement('div');
      p.className = 'pill';
      p.textContent = opts.pill;
      row.appendChild(p);
    }
    if (!opts.disabled && opts.onClick) {
      row.addEventListener('click', opts.onClick);
    }
    return row;
  }

  function clearView() {
    view.innerHTML = '';
  }

  function showMain(data) {
    stack = ['main'];
    setHeader(data.title || L.menu, data.subtitle || '', false);
    clearView();
    const items = [
      { key: 'members', title: L.members, desc: L.members_desc, icon: '☰' },
      { key: 'hire', title: L.hire, desc: L.hire_desc, icon: '＋' },
    ];
    if (data.showLocation) {
      items.push({ key: 'storage', title: L.storage, desc: L.storage_desc, icon: '▣' });
      items.push({ key: 'money', title: L.money, desc: L.money_desc, icon: '$' });
    }
    items.forEach((it) => {
      view.appendChild(rowEl({
        title: it.title,
        desc: it.desc,
        icon: it.icon,
        onClick: () => post('action', { type: it.key }),
      }));
    });
  }

  function showMembers(data) {
    stack.push('members');
    setHeader(L.members, data.gangLabel || '', true);
    clearView();
    const list = data.members || [];
    if (!list.length) {
      const h = document.createElement('div');
      h.className = 'hint';
      h.textContent = L.no_members;
      view.appendChild(h);
      return;
    }
    list.forEach((m) => {
      view.appendChild(rowEl({
        title: m.name,
        desc: `${m.gradeName} (${m.gradeLevel})`,
        status: m.online ? '🟢' : '❌',
        disabled: m.isSelf,
        onClick: () => post('action', { type: 'manage', citizenid: m.citizenid }),
      }));
    });
  }

  function showManage(data) {
    stack.push('manage');
    const emp = data.employee || {};
    setHeader(emp.name || L.members, L.grade, true);
    clearView();
    (data.grades || []).forEach((g) => {
      view.appendChild(rowEl({
        title: L.set_grade.replace('%s', g.name),
        desc: `${L.grade}: ${g.level}` + (g.current ? ` — ${L.current}` : ''),
        icon: '✎',
        disabled: g.disabled,
        onClick: () => post('action', { type: 'setGrade', citizenid: emp.citizenid, grade: g.level }),
      }));
    });
    view.appendChild(rowEl({
      title: L.fire,
      icon: '✕',
      danger: true,
      onClick: () => openModal({
        title: L.fire,
        body: L.fire_confirm.replace('%s', emp.name || ''),
        confirmText: L.fire,
        onConfirm: () => post('action', { type: 'fire', citizenid: emp.citizenid }),
      }),
    }));
  }

  function showHire(data) {
    stack.push('hire');
    setHeader(L.hire, '', true);
    clearView();
    const list = data.players || [];
    if (!list.length) {
      const h = document.createElement('div');
      h.className = 'hint';
      h.textContent = L.no_nearby;
      view.appendChild(h);
      return;
    }
    list.forEach((p) => {
      view.appendChild(rowEl({
        title: p.name,
        desc: `${L.citizenid}: ${p.citizenid} — ${L.id}: ${p.source}`,
        icon: '✓',
        onClick: () => post('action', { type: 'hirePlayer', source: p.source }),
      }));
    });
  }

  function showSociety(data) {
    stack.push('society');
    setHeader(L.money, '', true);
    clearView();

    const box = document.createElement('div');
    box.className = 'balance-box';
    box.innerHTML = `<div class="balance-label">${L.balance}</div><div class="balance-value">$${money(data.balance)}</div>`;
    view.appendChild(box);

    view.appendChild(rowEl({
      title: L.deposit,
      desc: L.deposit_desc,
      icon: '↓',
      disabled: (data.cash || 0) < 1,
      onClick: () => openModal({
        title: L.deposit,
        body: `${L.available}: $${money(data.cash)}`,
        input: true,
        max: Math.min(data.cash || 0, data.maxTransaction || 1000000),
        confirmText: L.deposit,
        onConfirm: (val) => post('action', { type: 'deposit', amount: val }),
      }),
    }));

    view.appendChild(rowEl({
      title: L.withdraw,
      desc: L.withdraw_desc,
      icon: '↑',
      disabled: (data.balance || 0) < 1,
      onClick: () => openModal({
        title: L.withdraw,
        body: `${L.available}: $${money(data.balance)}`,
        input: true,
        max: Math.min(data.balance || 0, data.maxTransaction || 1000000),
        confirmText: L.withdraw,
        onConfirm: (val) => post('action', { type: 'withdraw', amount: val }),
      }),
    }));
  }

  function openModal(opts) {
    modalTitle.textContent = opts.title || '';
    modalBody.textContent = opts.body || '';
    modalConfirm.textContent = opts.confirmText || L.confirm || 'Confirm';
    modalCancel.textContent = L.cancel || 'Cancel';
    if (opts.input) {
      modalInputWrap.classList.remove('hidden');
      modalInput.value = '';
      modalInput.max = opts.max || 999999999;
      modalInput.min = 1;
      setTimeout(() => modalInput.focus(), 50);
    } else {
      modalInputWrap.classList.add('hidden');
    }
    modalCb = opts;
    modalRoot.classList.remove('hidden');
  }

  function closeModal() {
    modalRoot.classList.add('hidden');
    modalCb = null;
  }

  modalCancel.addEventListener('click', () => {
    if (modalCb && modalCb.onCancel) modalCb.onCancel();
    if (modalCb && modalCb.invite) post('inviteResult', { accepted: false });
    closeModal();
  });

  modalConfirm.addEventListener('click', () => {
    if (!modalCb) return closeModal();
    if (modalCb.input) {
      const val = Math.floor(Number(modalInput.value));
      if (!val || val < 1) return;
      const max = Number(modalInput.max) || val;
      if (val > max) return;
      modalCb.onConfirm && modalCb.onConfirm(val);
    } else if (modalCb.invite) {
      post('inviteResult', { accepted: true });
    } else {
      modalCb.onConfirm && modalCb.onConfirm();
    }
    closeModal();
  });

  btnClose.addEventListener('click', () => post('close'));
  btnBack.addEventListener('click', () => post('action', { type: 'back' }));

  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      if (!modalRoot.classList.contains('hidden')) {
        modalCancel.click();
      } else if (!app.classList.contains('hidden')) {
        post('close');
      }
    }
  });

  window.addEventListener('message', (e) => {
    const msg = e.data || {};
    if (msg.action === 'close') {
      app.classList.add('hidden');
      closeModal();
      stack = [];
      return;
    }
    if (msg.locales) L = msg.locales;

    if (msg.action === 'open') {
      app.classList.remove('hidden');
      showMain(msg.data || {});
    } else if (msg.action === 'members') {
      app.classList.remove('hidden');
      showMembers(msg.data || {});
    } else if (msg.action === 'manage') {
      app.classList.remove('hidden');
      showManage(msg.data || {});
    } else if (msg.action === 'hire') {
      app.classList.remove('hidden');
      showHire(msg.data || {});
    } else if (msg.action === 'society') {
      app.classList.remove('hidden');
      showSociety(msg.data || {});
    } else if (msg.action === 'invite') {
      openModal({
        title: L.menu || 'Gang Menu',
        body: (L.invite || 'You have been invited to join %s. Accept?').replace('%s', msg.gangLabel || ''),
        confirmText: L.accept || 'Accept',
        invite: true,
      });
    } else if (msg.action === 'setStack') {
      stack = msg.stack || stack;
    }
  });
})();
