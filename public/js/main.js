/* ===== HumSukhan Landing — Interactions ===== */

document.addEventListener('DOMContentLoaded', () => {
  initNav();
  initScrollAnimations();
  initHeroVideo();
  initDemoVideo();
  initSmoothScroll();
});

/* ===== Navigation ===== */
function initNav() {
  const nav = document.getElementById('nav');
  const hamburger = document.getElementById('hamburger');
  const navLinks = document.getElementById('navLinks');

  // Scroll effect
  window.addEventListener('scroll', () => {
    nav.classList.toggle('nav--scrolled', window.scrollY > 20);
  }, { passive: true });

  // Mobile menu
  function closeMobileMenu() {
    navLinks.classList.remove('nav__links--open');
    hamburger.setAttribute('aria-expanded', 'false');
    const spans = hamburger.querySelectorAll('span');
    spans[0].style.transform = '';
    spans[1].style.opacity = '';
    spans[2].style.transform = '';
  }

  hamburger.addEventListener('click', () => {
    const open = navLinks.classList.toggle('nav__links--open');
    hamburger.setAttribute('aria-expanded', String(open));
    // Animate hamburger
    const spans = hamburger.querySelectorAll('span');
    if (open) {
      spans[0].style.transform = 'rotate(45deg) translate(5px, 5px)';
      spans[1].style.opacity = '0';
      spans[2].style.transform = 'rotate(-45deg) translate(5px, -5px)';
    } else {
      spans[0].style.transform = '';
      spans[1].style.opacity = '';
      spans[2].style.transform = '';
    }
  });

  // Close mobile menu on link click
  navLinks.querySelectorAll('.nav__link').forEach(link => {
    link.addEventListener('click', closeMobileMenu);
  });

  // Active link tracking
  const sections = document.querySelectorAll('section[id]');
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const id = entry.target.id;
        navLinks.querySelectorAll('.nav__link').forEach(link => {
          link.classList.toggle('nav__link--active',
            link.getAttribute('href') === '#' + id);
        });
      }
    });
  }, { rootMargin: '-40% 0px -60% 0px' });
  sections.forEach(s => observer.observe(s));
}

/* ===== Scroll Reveal Animations ===== */
function initScrollAnimations() {
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Respect reduced motion preference: show everything immediately
  if (prefersReducedMotion) {
    document.querySelectorAll('.reveal').forEach(el => el.classList.add('reveal--visible'));
    return;
  }

  // Observer for individual reveals (hero, section headers, demo player, CTA)
  const individualObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('reveal--visible');
        individualObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -60px 0px' });

  // Apply stagger indices to grouped children (used by CSS transition-delay)
  document.querySelectorAll('.reveal--group').forEach(group => {
    group.querySelectorAll('.reveal').forEach((child, index) => {
      child.style.setProperty('--reveal-index', Math.min(index, 7));
    });
  });

  // Observer for grouped reveals (cards, steps, panels) with CSS-staggered delays
  const groupObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.querySelectorAll('.reveal').forEach(child => {
          child.classList.add('reveal--visible');
        });
        groupObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.08, rootMargin: '0px 0px -80px 0px' });

  // Observe individual reveals that are not inside a reveal--group
  document.querySelectorAll('.reveal:not(.reveal--group .reveal)').forEach(el => {
    individualObserver.observe(el);
  });

  // Observe group containers
  document.querySelectorAll('.reveal--group').forEach(group => {
    groupObserver.observe(group);
  });
}

/* ===== Shared mute-button toggle (hero + demo video) ===== */
const MUTE_ICON = `
  <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/>
  <line x1="23" y1="9" x2="17" y2="15"/>
  <line x1="17" y1="9" x2="23" y2="15"/>
`;
const UNMUTE_ICON = `
  <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/>
  <path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>
  <path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>
`;

function setupMuteToggle(video, muteBtn, iconSelector) {
  if (!video || !muteBtn) return;
  const muteIcon = muteBtn.querySelector(iconSelector);
  const muteLabel = muteBtn.querySelector('span');

  function updateMuteButton() {
    const label = video.muted ? 'Unmute' : 'Mute';
    muteLabel.textContent = label;
    muteBtn.setAttribute('aria-label', `${label} video`);
    muteIcon.innerHTML = video.muted ? MUTE_ICON : UNMUTE_ICON;
  }

  muteBtn.addEventListener('click', () => {
    video.muted = !video.muted;
    updateMuteButton();
  });

  // Keep button in sync if user changes mute via native controls
  video.addEventListener('volumechange', updateMuteButton);
}

/* ===== Hero Video ===== */
function initHeroVideo() {
  const video = document.getElementById('heroVideo');
  const muteBtn = document.getElementById('heroMuteBtn');
  setupMuteToggle(video, muteBtn, '.hero__mute-icon');
}

/* ===== Demo Video ===== */
function initDemoVideo() {
  const video = document.getElementById('demoVideo');
  const overlay = document.getElementById('demoOverlay');
  const playBtn = document.getElementById('demoPlayBtn');
  const muteBtn = document.getElementById('demoMuteBtn');
  if (!video || !overlay || !playBtn) return;

  function showUnavailableMessage() {
    overlay.innerHTML = `
      <div style="text-align:center;color:white;padding:24px;">
        <p style="font-size:1.2rem;font-weight:600;margin-bottom:8px;">Demo video coming soon</p>
        <p style="font-size:.9rem;opacity:.8;">The demo video will be available shortly.</p>
      </div>
    `;
  }

  // Play button interaction
  playBtn.addEventListener('click', () => {
    overlay.classList.add('demo__overlay--hidden');
    const playPromise = video.play();
    if (playPromise && typeof playPromise.catch === 'function') {
      playPromise.catch(() => {
        // Video missing or failed to load (e.g. asset not yet deployed)
        overlay.classList.remove('demo__overlay--hidden');
        showUnavailableMessage();
      });
    }
  });

  // Also handle the case where the <source> itself 404s
  video.addEventListener('error', () => {
    overlay.classList.remove('demo__overlay--hidden');
    showUnavailableMessage();
  });

  setupMuteToggle(video, muteBtn, '.demo__mute-icon');

  // Pause overlay restoration
  video.addEventListener('pause', () => {
    if (!video.ended) {
      overlay.classList.remove('demo__overlay--hidden');
    }
  });
  video.addEventListener('play', () => {
    overlay.classList.add('demo__overlay--hidden');
  });
}

/* ===== Smooth Scroll ===== */
function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const targetId = this.getAttribute('href');
      if (targetId.length <= 1) return; // guard against bare "#"
      const target = document.querySelector(targetId);
      if (target) {
        e.preventDefault();
        const offset = parseInt(getComputedStyle(document.documentElement).getPropertyValue('--nav-h')) || 72;
        const top = target.getBoundingClientRect().top + window.scrollY - offset;
        window.scrollTo({ top, behavior: 'smooth' });
      }
    });
  });
}
