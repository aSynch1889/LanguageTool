(() => {
  const STORE_KEY = "lt-lang";
  const APP_STORE_URL =
    "https://apps.apple.com/app/languagetool/id6742207195?mt=12";

  const state = {
    lang: "en",
    dict: null,
  };

  function detectLang() {
    const params = new URLSearchParams(window.location.search);
    const fromQuery = params.get("lang");
    if (fromQuery === "zh" || fromQuery === "en") return fromQuery;
    try {
      const saved = localStorage.getItem(STORE_KEY);
      if (saved === "zh" || saved === "en") return saved;
    } catch (_) {
      /* ignore */
    }
    const nav = (navigator.language || "en").toLowerCase();
    return nav.startsWith("zh") ? "zh" : "en";
  }

  async function loadDict(lang) {
    const res = await fetch(`/i18n/${lang}.json`, { cache: "no-cache" });
    if (!res.ok) throw new Error(`Failed to load i18n/${lang}.json`);
    return res.json();
  }

  function get(path) {
    return path.split(".").reduce((acc, key) => (acc == null ? acc : acc[key]), state.dict);
  }

  function applyText() {
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const key = el.getAttribute("data-i18n");
      const value = get(key);
      if (typeof value === "string") {
        if (key.endsWith("rights")) {
          el.textContent = value.replace("{year}", String(new Date().getFullYear()));
        } else {
          el.textContent = value;
        }
      }
    });

    // Only homepage should overwrite SEO title/description from shared meta.*
    if (document.documentElement.getAttribute("data-i18n-meta") === "home") {
      const title = get("meta.title");
      const description = get("meta.description");
      if (title) document.title = title;
      const meta = document.querySelector('meta[name="description"]');
      if (meta && description) meta.setAttribute("content", description);
    }
    document.documentElement.lang = state.lang === "zh" ? "zh-Hans" : "en";

    document.querySelectorAll("[data-store-link]").forEach((el) => {
      el.setAttribute("href", APP_STORE_URL);
    });

    // Locale-aware screenshots when available
    document.querySelectorAll("[data-img-en][data-img-zh]").forEach((img) => {
      const next = state.lang === "zh" ? img.getAttribute("data-img-zh") : img.getAttribute("data-img-en");
      if (next) img.setAttribute("src", next);
    });

    document.body.classList.remove("lang-fade");
    void document.body.offsetWidth;
    document.body.classList.add("lang-fade");
  }

  async function setLang(lang) {
    state.lang = lang;
    state.dict = await loadDict(lang);
    try {
      localStorage.setItem(STORE_KEY, lang);
    } catch (_) {
      /* ignore */
    }
    const url = new URL(window.location.href);
    url.searchParams.set("lang", lang);
    window.history.replaceState({}, "", url);
    applyText();
  }

  async function init() {
    const lang = detectLang();
    await setLang(lang);

    document.querySelectorAll("[data-lang-toggle]").forEach((btn) => {
      btn.addEventListener("click", () => {
        setLang(state.lang === "zh" ? "en" : "zh");
      });
    });
  }

  window.LTI18n = { init, setLang, getLang: () => state.lang };
})();
