const fallbackTools = [];

const searchInput = document.getElementById("searchInput");
const cardsGrid = document.getElementById("cardsGrid");
const emptyState = document.getElementById("emptyState");
const categoryFilters = document.getElementById("categoryFilters");
const tagFilters = document.getElementById("tagFilters");
const template = document.getElementById("toolCardTemplate");
const resultsCount = document.getElementById("resultsCount");
const toggleStepsButton = document.getElementById("toggleSteps");
const quickSteps = document.getElementById("quickSteps");
const favoritesOnly = document.getElementById("favoritesOnly");
const statsRow = document.getElementById("statsRow");
const exportPlanButton = document.getElementById("exportPlan");
const wizardButtons = document.querySelectorAll(".wizard-btn");

let tools = [];
let activeCategory = "All";
let activeMode = "all";
const activeTags = new Set();
const favoriteKey = "go-tool-favorites";
const savedFavorites = JSON.parse(localStorage.getItem(favoriteKey) || "[]");
const favorites = new Set(savedFavorites);

async function loadTools() {
  try {
    const response = await fetch("./data/tools.generated.json", { cache: "no-store" });
    if (!response.ok) {
      throw new Error("tools.generated.json not available");
    }

    const payload = await response.json();
    const loaded = Array.isArray(payload) ? payload : payload.tools;
    if (!Array.isArray(loaded)) {
      throw new Error("Invalid tools payload");
    }

    tools = loaded;
  } catch {
    tools = fallbackTools;
  }
}

function getCategories() {
  return ["All", ...new Set(tools.map((item) => item.category))];
}

function getAllTags() {
  const set = new Set();
  tools.forEach((tool) => {
    (tool.tags || []).forEach((tag) => set.add(tag));
  });
  return Array.from(set).sort();
}

function riskLabel(risk) {
  if (risk === "high") return "Alto";
  if (risk === "medium") return "Medio";
  return "Baixo";
}

function updateStats(filtered) {
  const total = filtered.length;
  const highRisk = filtered.filter((item) => item.risk === "high").length;
  const safe = filtered.filter((item) => item.risk === "low").length;
  const fav = filtered.filter((item) => favorites.has(item.file)).length;

  statsRow.innerHTML = `
    <article class="stat-card"><p class="stat-label">Visiveis</p><p class="stat-value">${total}</p></article>
    <article class="stat-card"><p class="stat-label">Risco alto</p><p class="stat-value">${highRisk}</p></article>
    <article class="stat-card"><p class="stat-label">Seguros</p><p class="stat-value">${safe}</p></article>
    <article class="stat-card"><p class="stat-label">Favoritos</p><p class="stat-value">${fav}</p></article>
  `;
}

function renderFilters() {
  categoryFilters.innerHTML = "";
  getCategories().forEach((category) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = category;
    button.classList.toggle("active", category === activeCategory);

    button.addEventListener("click", () => {
      activeCategory = category;
      renderFilters();
      renderCards();
    });

    categoryFilters.appendChild(button);
  });
}

function renderTagFilters() {
  tagFilters.innerHTML = "";

  getAllTags().forEach((tag) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = tag;
    button.classList.toggle("active", activeTags.has(tag));

    button.addEventListener("click", () => {
      if (activeTags.has(tag)) {
        activeTags.delete(tag);
      } else {
        activeTags.add(tag);
      }
      renderTagFilters();
      renderCards();
    });

    tagFilters.appendChild(button);
  });
}

function filterTools() {
  const query = searchInput.value.trim().toLowerCase();

  return tools.filter((tool) => {
    const categoryMatch = activeCategory === "All" || tool.category === activeCategory;
    const modeMatch = activeMode === "all" || (tool.modes || []).includes(activeMode);
    const favoriteMatch = !favoritesOnly.checked || favorites.has(tool.file);
    const tags = tool.tags || [];
    const tagsMatch = Array.from(activeTags).every((tag) => tags.includes(tag));
    const text = `${tool.name} ${tool.file} ${tool.description} ${tool.type} ${tags.join(" ")}`.toLowerCase();
    return categoryMatch && modeMatch && favoriteMatch && tagsMatch && text.includes(query);
  });
}

function saveFavorites() {
  localStorage.setItem(favoriteKey, JSON.stringify(Array.from(favorites)));
}

async function copyCommand(command, button) {
  try {
    await navigator.clipboard.writeText(command);
    const original = button.textContent;
    button.textContent = "Copiado";
    setTimeout(() => {
      button.textContent = original;
    }, 1200);
  } catch {
    button.textContent = "Falhou";
  }
}

function renderCards() {
  cardsGrid.innerHTML = "";
  const filtered = filterTools();
  emptyState.classList.toggle("hidden", filtered.length > 0);
  resultsCount.textContent = `${filtered.length} resultado(s)`;
  updateStats(filtered);

  filtered.forEach((tool, index) => {
    const clone = template.content.cloneNode(true);
    const card = clone.querySelector(".tool-card");
    const copyBtn = clone.querySelector(".copy-btn");
    const favBtn = clone.querySelector(".fav-btn");

    clone.querySelector(".chip").textContent = tool.category || "Other";
    clone.querySelector("h3").textContent = tool.name || "Untitled";
    clone.querySelector(".card-description").textContent = tool.description || "Sem descricao";
    clone.querySelector(".file-path").textContent = tool.file || "-";
    clone.querySelector(".tool-type").textContent = tool.type || "-";
    clone.querySelector(".run-command").textContent = tool.run || "-";

    const risk = tool.risk || "low";
    const riskEl = clone.querySelector(".risk-level");
    riskEl.textContent = riskLabel(risk);
    riskEl.className = `risk-level risk-badge risk-${risk}`;

    clone.querySelector(".admin-required").textContent = tool.admin ? "Sim" : "Nao";

    const tagsContainer = clone.querySelector(".tags");
    (tool.tags || []).forEach((tag) => {
      const item = document.createElement("span");
      item.className = "tag";
      item.textContent = tag;
      tagsContainer.appendChild(item);
    });

    const isFav = favorites.has(tool.file);
    favBtn.textContent = isFav ? "Favorito" : "Favoritar";

    copyBtn.addEventListener("click", () => copyCommand(tool.run, copyBtn));
    favBtn.addEventListener("click", () => {
      if (favorites.has(tool.file)) {
        favorites.delete(tool.file);
      } else {
        favorites.add(tool.file);
      }
      saveFavorites();
      renderCards();
    });

    card.style.animationDelay = `${index * 30}ms`;
    cardsGrid.appendChild(clone);
  });
}

function exportPlan() {
  const selected = filterTools();
  const lines = [
    "# GamingOptimizer Plan",
    "",
    `Data: ${new Date().toLocaleString()}`,
    `Total: ${selected.length}`,
    ""
  ];

  selected.forEach((tool, index) => {
    lines.push(`${index + 1}. ${tool.name}`);
    lines.push(`   - Categoria: ${tool.category}`);
    lines.push(`   - Risco: ${riskLabel(tool.risk || "low")}`);
    lines.push(`   - Admin: ${tool.admin ? "Sim" : "Nao"}`);
    lines.push(`   - Ficheiro: ${tool.file}`);
    lines.push(`   - Comando: ${tool.run}`);
    lines.push("");
  });

  const blob = new Blob([lines.join("\n")], { type: "text/markdown;charset=utf-8" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = "gamingoptimizer-plan.md";
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(link.href);
}

function activateMode(mode) {
  activeMode = mode;
  wizardButtons.forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.mode === mode);
  });
  renderCards();
}

toggleStepsButton.addEventListener("click", () => {
  quickSteps.classList.toggle("hidden");
  toggleStepsButton.textContent = quickSteps.classList.contains("hidden")
    ? "Mostrar Passos de Uso"
    : "Esconder Passos de Uso";
});

exportPlanButton.addEventListener("click", exportPlan);
favoritesOnly.addEventListener("change", renderCards);
searchInput.addEventListener("input", renderCards);

wizardButtons.forEach((btn) => {
  btn.addEventListener("click", () => activateMode(btn.dataset.mode));
});

(async function init() {
  await loadTools();
  renderFilters();
  renderTagFilters();
  activateMode("all");
})();
