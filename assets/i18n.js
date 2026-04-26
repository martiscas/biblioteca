/**
 * Bilingual UI: default Spanish; English via ?lang=en on the same HTML files.
 */

export function getPageLang() {
  const v = new URLSearchParams(window.location.search).get("lang");
  if (v === "en") return "en";
  return "es";
}

export function withLangQuery(href) {
  const lang = getPageLang();
  if (lang !== "en") return href;
  try {
    const u = new URL(href, window.location.href);
    if (!/^https?:$/i.test(u.protocol)) return href;
    u.searchParams.set("lang", "en");
    if (u.origin === window.location.origin) {
      return `${u.pathname}${u.search}${u.hash}`;
    }
    return u.toString();
  } catch {
    return href.includes("?") ? `${href}&lang=en` : `${href}?lang=en`;
  }
}

export function pickLocalized(obj, key, lang) {
  if (!obj || typeof obj !== "object") return undefined;
  if (lang !== "en") return obj[key];
  const enVal = obj[`${key}_en`];
  if (enVal !== undefined && enVal !== null && String(enVal).trim() !== "") {
    return enVal;
  }
  return obj[key];
}

export function pickLocalizedArray(obj, key, lang) {
  const enKey = `${key}_en`;
  if (lang === "en" && Array.isArray(obj[enKey]) && obj[enKey].length) {
    return obj[enKey];
  }
  const base = obj[key];
  return Array.isArray(base) ? base : [];
}

const STRINGS = {
  es: {
    skip: "Saltar al contenido",
    theme_toggle: "Modo de visualización: Claro/Oscuro",
    theme_to_light: "Cambiar a modo claro",
    theme_to_dark: "Cambiar a modo oscuro",
    lang_es: "Español",
    lang_en: "English",
    footer_line: "Library template —",
    footer_cv_link: "Sitio principal",
    library_title: "Biblioteca personal",
    library_intro: "Agrega en el archvio info/intro.html una descripción tuya.",
    library_profile: "Mi perfil en Goodreads",
    library_read: "Libros leídos",
    library_reviewed: "Libros reseñados",
    library_likes: "Likes totales en Goodreads",
    library_by_year: "Libros leídos por año",
    library_books_per_year: "libros",
    library_latest10: "Últimos 10 libros leídos",
    library_top10: "Mejores 10 reseñas (por likes)",
    library_show_all: "¿Mostrar todos los libros?",
    library_no_rating: "Sin calificación",
    library_by_author: "Por:",
    library_date: "Fecha:",
    library_review_likes: "Likes reseña:",
    library_rating_label: "Calificación",
    library_view_review_goodreads: "Ver reseña (GoodReads, necesita cuenta)",
    library_view_review_local: "Ver reseña (local)",
    library_review_links: "Enlaces de reseña",
    library_no_review: "(No hay reseña)",
    library_no_data: "Sin datos disponibles.",
    library_stats_error:
      "No se pudieron cargar las estadísticas de lectura. Compruebe que exista <code>info/library.json</code>.",
    library_all_title: "Todos los libros leídos",
    library_all_intro:
      "Listado completo ordenado del más reciente al más antiguo.",
    library_back: "← Volver a Biblioteca",
    library_list_error:
      "No se pudieron cargar los libros. Compruebe que exista <code>info/library.json</code>.",
    library_book_title_fallback: "Libro sin título",
  },
  en: {
    skip: "Skip to content",
    theme_toggle: "Display mode: Light/Dark",
    theme_to_light: "Switch to light mode",
    theme_to_dark: "Switch to dark mode",
    lang_es: "Español",
    lang_en: "English",
    footer_line: "Library template —",
    footer_cv_link: "Main site",
    library_title: "Personal library",
    library_intro: "Add a personal description in info/intro.html.",
    library_profile: "My Goodreads profile",
    library_read: "Books read",
    library_reviewed: "Books reviewed",
    library_likes: "Total likes on Goodreads",
    library_by_year: "Books read per year",
    library_books_per_year: "books",
    library_latest10: "Last 10 books read",
    library_top10: "Top 10 reviews (by likes)",
    library_show_all: "Show all books?",
    library_no_rating: "No rating",
    library_by_author: "By:",
    library_date: "Date:",
    library_review_likes: "Review likes:",
    library_rating_label: "Rating",
    library_view_review_goodreads: "View review on GoodReads (account required)",
    library_view_review_local: "View local review",
    library_review_links: "Review links",
    library_no_review: "(No review)",
    library_no_data: "No data available.",
    library_stats_error:
      "Could not load reading statistics. <code>info/library.json</code> must exist.",
    library_all_title: "All books read",
    library_all_intro:
      "Full list sorted from most recent to oldest.",
    library_back: "← Back to library",
    library_list_error:
      "Could not load books. <code>info/library.json</code> must exist.",
    library_book_title_fallback: "Untitled book",
  },
};

export function t(key, lang = getPageLang()) {
  const table = STRINGS[lang] ?? STRINGS.es;
  return table[key] ?? STRINGS.es[key] ?? key;
}

export function applyThemeAriaFromLang(lang = getPageLang()) {
  const isDark = document.body.classList.contains("dark-theme");
  const label = isDark ? t("theme_to_light", lang) : t("theme_to_dark", lang);
  document.querySelectorAll(".theme-button").forEach((btn) => {
    btn.setAttribute("aria-label", label);
  });
}
