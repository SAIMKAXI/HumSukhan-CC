/* ===== HumSukhan Landing — Interactions ===== */

/* --- Config: demo video URL --- */
const DEMO_VIDEO_URL = ''; // e.g. 'assets/humsukhan_video.mp4'

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
  });

  // Mobile menu
  hamburger.addEventListener('click', () => {
    navLinks.classList.toggle('nav__links--open');
    const open = navLinks.classList.contains('nav__links--open');
    hamburger.setAttribute('aria-expanded', open);
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
    link.addEventListener('click', () => {
      navLinks.classList.remove('nav__links--open');
      const spans = hamburger.querySelectorAll('span');
      spans[0].style.transform = '';
      spans[1].style.opacity = '';
      spans[2].style.transform = '';
    });
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

/* ===== Hero Video ===== */
function initHeroVideo() {
  const video = document.getElementById('heroVideo');
  const muteBtn = document.getElementById('heroMuteBtn');
  if (!video || !muteBtn) return;

  const muteIcon = muteBtn.querySelector('.hero__mute-icon');
  const muteLabel = muteBtn.querySelector('span');

  function updateMuteButton() {
    if (video.muted) {
      muteLabel.textContent = 'Unmute';
      muteBtn.setAttribute('aria-label', 'Unmute video');
      muteIcon.innerHTML = `
        <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/>
        <line x1="23" y1="9" x2="17" y2="15"/>
        <line x1="17" y1="9" x2="23" y2="15"/>
      `;
    } else {
      muteLabel.textContent = 'Mute';
      muteBtn.setAttribute('aria-label', 'Mute video');
      muteIcon.innerHTML = `
        <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/>
        <path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>
        <path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>
      `;
    }
  }

  muteBtn.addEventListener('click', () => {
    video.muted = !video.muted;
    updateMuteButton();
  });

  // Keep button in sync if user changes mute via native controls
  video.addEventListener('volumechange', updateMuteButton);
}

/* ===== Demo Video ===== */
function initDemoVideo() {
  const video = document.getElementById('demoVideo');
  const overlay = document.getElementById('demoOverlay');
  const playBtn = document.getElementById('demoPlayBtn');
  const muteBtn = document.getElementById('demoMuteBtn');
  if (!video || !overlay || !playBtn) return;

  const source = video.querySelector('source');
  const hasVideo = source && source.src && source.src !== window.location.href;

  // Set video source from config if provided
  if (DEMO_VIDEO_URL && source) {
    source.src = DEMO_VIDEO_URL;
    video.load();
  }

  // Play button interaction
  playBtn.addEventListener('click', () => {
    if (hasVideo || DEMO_VIDEO_URL) {
      overlay.classList.add('demo__overlay--hidden');
      video.play();
    } else {
      // No video configured — show a friendly message
      overlay.innerHTML = `
        <div style="text-align:center;color:white;padding:24px;">
          <p style="font-size:1.2rem;font-weight:600;margin-bottom:8px;">Demo video coming soon</p>
          <p style="font-size:.9rem;opacity:.8;">The demo video will be available shortly.</p>
        </div>
      `;
      setTimeout(() => {
        overlay.innerHTML = `<button class="demo__play-btn" aria-label="Play demo video">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>
        </button>`;
        overlay.querySelector('.demo__play-btn').addEventListener('click', arguments.callee);
      }, 3000);
    }
  });

  // Unmute toggle
  if (muteBtn) {
    const muteIcon = muteBtn.querySelector('.demo__mute-icon');
    const muteLabel = muteBtn.querySelector('span');

    function updateMuteButton() {
      if (video.muted) {
        muteLabel.textContent = 'Unmute';
        muteBtn.setAttribute('aria-label', 'Unmute video');
        muteIcon.innerHTML = `
          <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/>
          <line x1="23" y1="9" x2="17" y2="15"/>
          <line x1="17" y1="9" x2="23" y2="15"/>
        `;
      } else {
        muteLabel.textContent = 'Mute';
        muteBtn.setAttribute('aria-label', 'Mute video');
        muteIcon.innerHTML = `
          <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/>
          <path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>
          <path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>
        `;
      }
    }

    muteBtn.addEventListener('click', () => {
      video.muted = !video.muted;
      updateMuteButton();
    });

    video.addEventListener('volumechange', updateMuteButton);
  }

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
      const target = document.querySelector(this.getAttribute('href'));
      if (target) {
        e.preventDefault();
        const offset = parseInt(getComputedStyle(document.documentElement).getPropertyValue('--nav-h')) || 72;
        const top = target.getBoundingClientRect().top + window.scrollY - offset;
        window.scrollTo({ top, behavior: 'smooth' });
      }
    });
  });
}

/* ===== Parallax on Hero (subtle) ===== */
window.addEventListener('scroll', () => {
  const hero = document.querySelector('.hero__phone-img');
  if (hero) {
    const scrolled = window.scrollY;
    if (scrolled < 800) {
      hero.style.transform = `translateY(${scrolled * 0.04}px)`;
    }
  }
}, { passive: true });
