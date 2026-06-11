/* ═══════════════════════════════════════════════════════════════
   ZCU102 Showcase — app.js
   JavaScript feature demonstrations served from the board
   ═══════════════════════════════════════════════════════════════ */

'use strict';

/* ── Uptime Counter ────────────────────────────────────────────── */
const startTime = Date.now();

function updateUptime() {
  const seconds = Math.floor((Date.now() - startTime) / 1000);
  const el = document.getElementById('uptime-val');
  if (el) el.textContent = seconds.toLocaleString();
}

/* ── Real-time Clock ───────────────────────────────────────────── */
function updateClock() {
  const now  = new Date();
  const pad  = n => String(n).padStart(2, '0');
  const days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  const h = document.getElementById('clock-hours');
  const m = document.getElementById('clock-minutes');
  const s = document.getElementById('clock-seconds');
  const d = document.getElementById('clock-date');

  if (h) h.textContent = pad(now.getHours());
  if (m) m.textContent = pad(now.getMinutes());
  if (s) s.textContent = pad(now.getSeconds());
  if (d) d.textContent = `${days[now.getDay()]} ${now.getDate()} ${months[now.getMonth()]} ${now.getFullYear()}`;
}

/* ── Fetch API Demo ────────────────────────────────────────────── */
// Quotes about hardware, engineering, and embedded systems
const quotes = [
  { q: "The best performance improvement is the transition from the nonworking state to the working state.", a: "John Ousterhout" },
  { q: "Hardware is like ice cream — it melts when exposed to the real world.", a: "Unknown Engineer" },
  { q: "Programmable logic is freedom in silicon.", a: "Embedded Wisdom" },
  { q: "Any sufficiently advanced technology is indistinguishable from magic.", a: "Arthur C. Clarke" },
  { q: "The ZCU102 doesn't just run code — it runs possibilities.", a: "FPGA Philosophy" },
  { q: "Four Cortex-A53 cores, and still you find a way to block the main thread.", a: "JavaScript Developer" },
  { q: "USB Ethernet gadget: turning a development board into a network appliance.", a: "Embedded Linux Notes" },
  { q: "PCIe x4 to an NVMe — because fast storage is not optional, it is essential.", a: "Storage Engineer" },
  { q: "The best debugging tool is still careful thinking, coupled with judicious print statements.", a: "Brian Kernighan" },
  { q: "Simplicity is the soul of efficiency.", a: "Austin Freeman" },
];

let lastQuoteIndex = -1;

async function runFetch() {
  const el = document.getElementById('fetch-result');
  if (!el) return;

  el.textContent = 'Loading…';
  el.style.color = 'var(--text-dim)';

  // Simulate async fetch with setTimeout (no internet needed on board)
  await new Promise(r => setTimeout(r, 300 + Math.random() * 400));

  let idx;
  do { idx = Math.floor(Math.random() * quotes.length); } while (idx === lastQuoteIndex);
  lastQuoteIndex = idx;

  const q = quotes[idx];
  el.innerHTML = `<em>"${q.q}"</em><br><span style="color:var(--amber);font-size:0.7rem;margin-top:0.4rem;display:block">— ${q.a}</span>`;
  el.style.color = '#fff';
}

/* ── Canvas Particle Animation ─────────────────────────────────── */
function initCanvas() {
  const canvas = document.getElementById('canvas-demo');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');

  // Resize canvas to actual display size
  function resize() {
    canvas.width  = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;
  }
  resize();
  window.addEventListener('resize', resize);

  // Particle system representing data flowing through the FPGA
  const particles = Array.from({ length: 60 }, () => ({
    x:    Math.random() * canvas.width,
    y:    Math.random() * canvas.height,
    vx:   (Math.random() - 0.5) * 1.2,
    vy:   (Math.random() - 0.5) * 1.2,
    r:    Math.random() * 2 + 0.5,
    hue:  Math.random() > 0.5 ? 'amber' : 'teal',
    life: Math.random(),
  }));

  const AMBER = '#f5a623';
  const TEAL  = '#00e5c8';

  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Draw connections between nearby particles
    for (let i = 0; i < particles.length; i++) {
      for (let j = i + 1; j < particles.length; j++) {
        const dx   = particles[i].x - particles[j].x;
        const dy   = particles[i].y - particles[j].y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < 55) {
          ctx.beginPath();
          ctx.strokeStyle = `rgba(0,229,200,${(1 - dist / 55) * 0.25})`;
          ctx.lineWidth = 0.5;
          ctx.moveTo(particles[i].x, particles[i].y);
          ctx.lineTo(particles[j].x, particles[j].y);
          ctx.stroke();
        }
      }
    }

    // Draw particles
    particles.forEach(p => {
      p.x += p.vx;
      p.y += p.vy;

      if (p.x < 0 || p.x > canvas.width)  p.vx *= -1;
      if (p.y < 0 || p.y > canvas.height) p.vy *= -1;

      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fillStyle = p.hue === 'amber' ? AMBER : TEAL;
      ctx.globalAlpha = 0.8;
      ctx.fill();
      ctx.globalAlpha = 1;
    });

    requestAnimationFrame(draw);
  }

  draw();
}

/* ── Web Storage ───────────────────────────────────────────────── */
function initStorage() {
  const key = 'zcu102_visits';
  const visits = parseInt(localStorage.getItem(key) || '0') + 1;
  localStorage.setItem(key, visits);
  localStorage.setItem('zcu102_last', new Date().toLocaleString());

  const vc = document.getElementById('visit-count');
  const lv = document.getElementById('last-visit');
  if (vc) vc.textContent = visits;
  if (lv) lv.textContent = localStorage.getItem('zcu102_last') || '--';
}

function clearStorage() {
  localStorage.removeItem('zcu102_visits');
  localStorage.removeItem('zcu102_last');
  const vc = document.getElementById('visit-count');
  const lv = document.getElementById('last-visit');
  if (vc) vc.textContent = '0';
  if (lv) lv.textContent = 'Cleared';
  setTimeout(initStorage, 100);
}

/* ── DOM Manipulation — Animate Cores ─────────────────────────── */
const coreColors = {
  'dom-box-1': { bg: '#f5a623', text: '#000', label: 'A53',  glow: 'rgba(245,166,35,0.4)'  },
  'dom-box-2': { bg: '#00e5c8', text: '#000', label: 'R5F',  glow: 'rgba(0,229,200,0.4)'   },
  'dom-box-3': { bg: '#7c5cbf', text: '#fff', label: 'PL',   glow: 'rgba(124,92,191,0.4)'  },
  'dom-box-4': { bg: '#ff4757', text: '#fff', label: 'GPU',  glow: 'rgba(255,71,87,0.4)'   },
};

let coresAnimated = false;

function animateBoxes() {
  coresAnimated = !coresAnimated;

  Object.entries(coreColors).forEach(([id, cfg], i) => {
    const box = document.getElementById(id);
    if (!box) return;

    setTimeout(() => {
      if (coresAnimated) {
        box.style.background   = cfg.bg;
        box.style.color        = cfg.text;
        box.style.borderColor  = cfg.bg;
        box.style.boxShadow    = `0 0 16px ${cfg.glow}`;
        box.style.transform    = 'scale(1.1)';
        box.textContent        = cfg.label;
      } else {
        box.style.background   = '';
        box.style.color        = '';
        box.style.borderColor  = '';
        box.style.boxShadow    = '';
        box.style.transform    = '';
      }
    }, i * 120);
  });
}

/* ── Web Audio API ─────────────────────────────────────────────── */
let audioCtx = null;
let audioInterval = null;

function playTone() {
  if (audioInterval) {
    clearInterval(audioInterval);
    audioInterval = null;
    resetAudioBars();
    return;
  }

  try {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();

    const oscillator = audioCtx.createOscillator();
    const gainNode   = audioCtx.createGain();
    const analyser   = audioCtx.createAnalyser();

    oscillator.connect(gainNode);
    gainNode.connect(analyser);
    analyser.connect(audioCtx.destination);

    oscillator.type      = 'sine';
    oscillator.frequency.setValueAtTime(440, audioCtx.currentTime);
    gainNode.gain.setValueAtTime(0.05, audioCtx.currentTime);

    // Frequency sweep: 220Hz → 880Hz
    oscillator.frequency.exponentialRampToValueAtTime(880, audioCtx.currentTime + 1.5);
    gainNode.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 1.5);

    oscillator.start();
    oscillator.stop(audioCtx.currentTime + 1.5);

    analyser.fftSize = 32;
    const bufLen = analyser.frequencyBinCount;
    const data   = new Uint8Array(bufLen);
    const bars   = document.querySelectorAll('.audio-bar');

    audioInterval = setInterval(() => {
      analyser.getByteFrequencyData(data);
      bars.forEach((bar, i) => {
        const val = data[i % bufLen] || 0;
        const h   = Math.max(4, (val / 255) * 60);
        bar.style.height     = h + 'px';
        bar.style.background = `hsl(${170 + (i * 8)}, 80%, ${40 + val / 8}%)`;
      });
    }, 60);

    setTimeout(() => {
      clearInterval(audioInterval);
      audioInterval = null;
      resetAudioBars();
    }, 1600);

  } catch(e) {
    console.warn('Web Audio API not available:', e);
  }
}

function resetAudioBars() {
  document.querySelectorAll('.audio-bar').forEach(bar => {
    bar.style.height     = '4px';
    bar.style.background = '';
  });
}

/* ── Board Status Update ───────────────────────────────────────── */
function updateBoardStatus() {
  const el = document.getElementById('board-status');
  if (!el) return;
  const msgs = [
    'Board Online',
    'Serving HTTP',
    'CPU: A53 × 4',
    'USB Gadget Active',
    'NVMe Ready',
  ];
  let i = 0;
  setInterval(() => {
    i = (i + 1) % msgs.length;
    el.style.opacity = '0';
    setTimeout(() => {
      el.textContent = msgs[i];
      el.style.opacity = '1';
    }, 300);
  }, 3000);
}

/* ── Scroll Reveal ─────────────────────────────────────────────── */
function initScrollReveal() {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.style.opacity  = '1';
        entry.target.style.transform = 'translateY(0)';
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.1 });

  document.querySelectorAll('.js-card, .info-card').forEach(el => {
    el.style.opacity   = '0';
    el.style.transform = 'translateY(24px)';
    el.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
    observer.observe(el);
  });
}

/* ── Init ──────────────────────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', () => {
  // Clock + uptime — update every second
  updateClock();
  updateUptime();
  setInterval(updateClock,  1000);
  setInterval(updateUptime, 1000);

  // Canvas
  initCanvas();

  // Storage
  initStorage();

  // Board status rotating text
  updateBoardStatus();

  // Scroll reveal
  initScrollReveal();

  // Initial fetch quote on load
  setTimeout(runFetch, 800);
});
