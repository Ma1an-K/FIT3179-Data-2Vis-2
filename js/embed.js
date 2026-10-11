// Loads every Vega-Lite spec referenced by a data-spec attribute.
// Shared config keeps typography and colours consistent across charts.
const sharedConfig = {
  background: "transparent",
  font: "Source Sans 3",
  title: { font: "Fraunces", fontSize: 18, fontWeight: 600, color: "#EDE6DA", anchor: "start", subtitleColor: "#9C9385", subtitleFontSize: 13 },
  axis: { labelColor: "#9C9385", titleColor: "#9C9385", gridColor: "#3A332C", domainColor: "#3A332C", tickColor: "#3A332C", labelFontSize: 12, titleFontSize: 12 },
  legend: { labelColor: "#9C9385", titleColor: "#9C9385", labelFontSize: 12, titleFontSize: 12 },
  view: { stroke: null }
};

const views = [];
const sel = document.getElementById("decade");
document.querySelectorAll(".vis[data-spec]").forEach((el) => {
  vegaEmbed(el, el.dataset.spec, { actions: false, config: sharedConfig, renderer: "svg" })
    .then((res) => {
      // Apply the current decade (late-loading charts, browser-restored select value).
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

// Global decade lens: one <select> drives the "decade" param in every chart that declares it.
sel.addEventListener("change", (e) => {
  views.forEach((v) => {
    try { v.signal("decade", e.target.value).run(); } catch (_) { /* chart has no decade param */ }
  });
});
