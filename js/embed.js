// Loads every Vega-Lite spec referenced by a data-spec attribute, drives the global decade lens,
// and writes the "N of M winners" count lines + empty-state captions from the same CSVs the charts read.
const sharedConfig = {
  background: "transparent",
  font: "'Source Sans 3', sans-serif",
  title: { font: "'Fraunces', serif", fontSize: 18, fontWeight: 600, color: "#1F1A15", anchor: "start", subtitleColor: "#6B6257", subtitleFontSize: 13 },
  axis: { labelColor: "#6B6257", titleColor: "#6B6257", gridColor: "#E6DFD3", domainColor: "#D9D1C4", tickColor: "#D9D1C4", labelFontSize: 12, titleFontSize: 12 },
  legend: { labelColor: "#6B6257", titleColor: "#6B6257", labelFontSize: 12, titleFontSize: 12 },
  view: { stroke: null }
};

const views = [];
const sel = document.getElementById("decade");
const inLens = (year, decade) => decade === "All" || Math.floor(year / 10) * 10 + "s" === decade;

document.querySelectorAll(".vis[data-spec]").forEach((el) => {
  const host = document.createElement("div");
  host.style.width = "100%";
  el.appendChild(host);
  vegaEmbed(host, el.dataset.spec, { actions: false, config: sharedConfig, renderer: "svg" })
    .then((res) => {
      try { res.view.signal("decade", sel.value).run(); } catch (_) { /* chart has no decade param */ }
      views.push(res.view);
    })
    .catch((err) => {
      const p = document.createElement("p");
      p.className = "caption";
      p.textContent = "Chart failed to load: " + err.message;
      el.replaceChildren(p);
      console.error(el.id, err);
    });
});

// Count lines. <p class="count" data-csv="data/flows.csv" data-noun="…" data-empty="vis-3-1">
// Rows are counted with the same decade rule the specs use; data-filter (optional) names a column that must be non-empty;
// data-where (optional, "col=value&col2=value2") keeps only rows where every listed column equals its value.
const csvCache = {};
const loadCsv = (url) => csvCache[url] || (csvCache[url] = fetch(url).then((r) => r.text()).then((t) => vega.read(t, { type: "csv", parse: "auto" })));
const counts = [...document.querySelectorAll("p.count[data-csv]")];
const winners = loadCsv("data/best_film_winners.csv");

function updateCounts(decade) {
  counts.forEach((p) => {
    Promise.all([loadCsv(p.dataset.csv), winners]).then(([rows, win]) => {
      const col = p.dataset.filter;
      const where = p.dataset.where ? p.dataset.where.split("&").map((c) => c.split("=")) : null;
      const keep = rows.filter((r) => inLens(+r.year, decade) && (!col || (r[col] !== null && r[col] !== "")) && (!where || where.every(([k, v]) => String(r[k]) === v)));
      const key = p.dataset.key || "film";
      const n = new Set(keep.map((r) => r[key])).size;
      const m = win.filter((r) => inLens(+r.year, decade)).length;
      const when = decade === "All" ? "across all years" : "in the " + decade;
      p.innerHTML = "<b>" + n + " of " + m + "</b> winners " + when + " " + p.dataset.noun + ".";
      const empty = p.dataset.empty && document.querySelector('.empty[data-for="' + p.dataset.empty + '"]');
      if (empty) empty.classList.toggle("show", n === 0);
    });
  });
}

sel.addEventListener("change", (e) => {
  views.forEach((v) => {
    try { v.signal("decade", e.target.value).run(); } catch (_) { /* chart has no decade param */ }
  });
  updateCounts(e.target.value);
});
updateCounts(sel.value);
