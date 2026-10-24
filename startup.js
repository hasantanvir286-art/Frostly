document.addEventListener('DOMContentLoaded', () => {
  setTimeout(() => document.getElementById('startupLoader')?.classList.add('is-done'), 220);
}, { once: true });
setTimeout(() => document.getElementById('startupLoader')?.classList.add('is-done'), 3500);
