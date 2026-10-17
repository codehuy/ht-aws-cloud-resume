// TODO (Phase 3): replace with your Function App URL once it exists,
// e.g. "https://func-cloudresume-api.azurewebsites.net/api/get_and_increment_count"
// TODO (Phase 4): once Front Door is in place, prefer calling it through
// your custom domain rather than the raw *.azurewebsites.net host.
const COUNTER_API_URL = "https://z3a0lb435b.execute-api.us-east-1.amazonaws.com/count";;

async function loadVisitorCount() {
  const el = document.getElementById("visitor-count");
  if (!el) return;

  // No backend yet in Phase 1 — fail quietly instead of throwing in the console.
  if (COUNTER_API_URL === "PLACEHOLDER_API_URL") {
    el.textContent = "—";
    return;
  }

  try {
    const response = await fetch(COUNTER_API_URL, { method: "GET" });
    if (!response.ok) throw new Error(`Request failed: ${response.status}`);
    const data = await response.json();
    el.textContent = data.count ?? "—";
  } catch (err) {
    console.warn("Could not load visitor count:", err);
    el.textContent = "—";
  }
}

document.addEventListener("DOMContentLoaded", loadVisitorCount);
