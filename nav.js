(() => {
  const side = document.querySelector('.side');
  if (!side) return;
  const path = location.pathname.split('/').pop() || 'index.html';
  const routes = {
    Overview: 'index.html',
    Patients: 'patient.html',
    Insights: 'insights.html',
    Reports: 'insights.html',
    Settings: 'auth.html',
    'Import data': 'import.html'
  };
  const label = el => el.textContent.replace(/[▦♧◈▤⚙↥↪]/g, '').replace(/\s+/g, ' ').trim().replace(/\s+\d+$/, '');
  [...side.querySelectorAll('a')].forEach(a => {
    const key = label(a);
    if (routes[key]) a.href = routes[key];
    a.classList.toggle('active', a.href && a.href.endsWith(path));
  });
  if (!side.querySelector('[data-import-link]')) {
    const a = document.createElement('a');
    a.href = 'import.html'; a.dataset.importLink = ''; a.textContent = '↥　Import data';
    a.classList.toggle('active', path === 'import.html');
    side.insertBefore(a, side.querySelector('.bottom'));
  }
  document.querySelectorAll('.patient[data-name]').forEach(row => {
    row.title = 'Open patient detail';
    row.addEventListener('click', () => { location.href = `patient.html?name=${encodeURIComponent(row.dataset.name)}`; });
  });
  document.querySelectorAll('a').forEach(a => {
    if (!a.getAttribute('href') && /view all/i.test(a.textContent)) a.href = 'patient.html';
  });
})();
