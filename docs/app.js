/* Caelum marketing site — live APOD hero, starfield, reveals. */
(function () {
  "use strict";

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const FALLBACK_HERO = "https://cdn.esawebb.org/archives/images/screen/weic2205a.jpg";

  /* --- Footer year --- */
  document.getElementById("year").textContent = new Date().getFullYear();

  /* --- Nav shadow on scroll --- */
  const nav = document.getElementById("nav");
  const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 24);
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  /* --- Reveal on scroll --- */
  const io = new IntersectionObserver(
    (entries) => entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } }),
    { threshold: 0.12 }
  );
  document.querySelectorAll(".reveal").forEach((el) => io.observe(el));

  /* --- Live APOD hero --- */
  const heroBg = document.getElementById("hero-bg");
  const heroApod = document.getElementById("hero-apod");
  const ambientImg = document.getElementById("ambient-img");

  function setHero(url) {
    const img = new Image();
    img.onload = () => { heroBg.style.backgroundImage = `url("${url}")`; heroBg.classList.add("loaded"); };
    img.src = url;
  }

  fetch("https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY&thumbs=true")
    .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
    .then((d) => {
      const url = d.media_type === "image" ? (d.hdurl || d.url) : (d.thumbnail_url || FALLBACK_HERO);
      setHero(url);
      if (ambientImg && d.media_type === "image") ambientImg.src = d.url || url;
      heroApod.innerHTML = `Today · <span>${escapeHtml(d.title || "Astronomy Picture of the Day")}</span>`;
    })
    .catch(() => {
      setHero(FALLBACK_HERO);
      heroApod.innerHTML = `Featured · <span>The Cosmic Cliffs of Carina</span>`;
    });

  function escapeHtml(s) {
    return String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  }

  /* --- Sources grid --- */
  const G = {
    orbit: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="3"/><ellipse cx="12" cy="12" rx="10" ry="4.5" transform="rotate(-20 12 12)"/></svg>',
    star: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z"/></svg>',
    hex: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linejoin="round"><path d="M12 2l8.7 5v10L12 22l-8.7-5V7z"/></svg>',
    globe: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/></svg>',
    mount: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linejoin="round"><path d="M3 19l6-10 4 6 2-3 6 7z"/></svg>',
    book: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linejoin="round"><path d="M4 5a2 2 0 0 1 2-2h12v16H6a2 2 0 0 0-2 2z"/></svg>',
    photo: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="M21 17l-5-5-7 7"/></svg>',
    starc: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8l1.2 2.6L16 11l-2.1 1.6.7 2.8L12 13.9 9.4 15.4l.7-2.8L8 11l2.8-.4z"/></svg>',
  };
  const sources = [
    { n: "NASA APOD", s: "Astronomy Picture of the Day", g: G.star, star: true },
    { n: "ESA/Hubble", s: "Picture of the Week", g: G.hex },
    { n: "James Webb", s: "ESA/Webb", g: G.hex },
    { n: "ESO", s: "Picture of the Week", g: G.mount },
    { n: "NASA EPIC", s: "Earth from DSCOVR", g: G.globe },
    { n: "NASA Library", s: "Image & Video", g: G.book },
    { n: "Bing", s: "Photo of the Day", g: G.photo },
    { n: "Wikimedia", s: "Picture of the Day", g: G.globe },
    { n: "NASA Image of the Day", s: "The daily pick", g: G.globe },
    { n: "Caelum Curated", s: "Hand-picked", g: G.starc },
  ];
  const grid = document.getElementById("sources-grid");
  grid.innerHTML = sources
    .map((x) => `<div class="source ${x.star ? "star" : ""} reveal"><div class="glyph">${x.g}</div><b>${x.n}</b><span>${x.s}</span></div>`)
    .join("");
  grid.querySelectorAll(".reveal").forEach((el) => io.observe(el));

  /* --- Lightweight starfield --- */
  if (!reduceMotion) {
    const canvas = document.getElementById("stars");
    const ctx = canvas.getContext("2d");
    let stars = [];
    function resize() {
      canvas.width = window.innerWidth * devicePixelRatio;
      canvas.height = window.innerHeight * devicePixelRatio;
      const count = Math.min(180, Math.floor((window.innerWidth * window.innerHeight) / 9000));
      stars = Array.from({ length: count }, () => ({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        r: Math.random() * 1.3 * devicePixelRatio + 0.2,
        a: Math.random(),
        sp: Math.random() * 0.015 + 0.003,
      }));
    }
    function tick() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      for (const s of stars) {
        s.a += s.sp;
        const tw = 0.5 + 0.5 * Math.sin(s.a);
        ctx.globalAlpha = 0.15 + tw * 0.6;
        ctx.fillStyle = tw > 0.7 ? "#5EE7FF" : "#ffffff";
        ctx.beginPath();
        ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
        ctx.fill();
      }
      requestAnimationFrame(tick);
    }
    resize();
    window.addEventListener("resize", resize);
    tick();
  }
})();
