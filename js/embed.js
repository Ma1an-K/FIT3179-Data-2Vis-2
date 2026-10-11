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
document.querySelectorAll(".vis[data-spec]").forEach((el) => {
  vegaEmbed(el, el.dataset.spec, { actions: false, config: sharedConfig, renderer: "svg" })
    .then((res) => views.push(res.view))
    .catch((err) => {
      el.innerHTML = '<p class="caption">Chart failed to load: ' + err.message + "</p>";
      console.error(el.id, err);
    });
});

// Global decade lens: one <select> drives the "decade" param in every chart that declares it.
document.getElementById("decade").addEventListener("change", (e) => {
  views.forEach((v) => {
    try { v.signal("decade", e.target.value).run(); } catch (_) { /* chart has no decade param */ }
  });
});
