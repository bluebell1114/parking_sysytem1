/**
 * Admin web (static) — Docker `mobile_bas2` API.
 *
 * API default: http://localhost:4000
 * Override: localStorage.setItem('API_BASE_URL','http://<ip>:4000')
 */

const API_BASE_URL =
  (localStorage.getItem("API_BASE_URL") || "http://localhost:4000").replace(
    /\/$/,
    ""
  );

const LS_TOKEN = "api_jwt";
const LS_USER = "api_user";

function getToken() {
  return localStorage.getItem(LS_TOKEN) || "";
}

function setSession(token, user) {
  localStorage.setItem(LS_TOKEN, token);
  localStorage.setItem(LS_USER, JSON.stringify(user || {}));
}

function clearSession() {
  localStorage.removeItem(LS_TOKEN);
  localStorage.removeItem(LS_USER);
}

function isLoginPage() {
  return (
    location.pathname.endsWith("/index.html") ||
    location.pathname === "/" ||
    location.pathname.endsWith("/index")
  );
}

function requireAuth() {
  if (isLoginPage()) return;
  const t = getToken();
  if (!t) {
    window.location = "index.html";
  }
}

async function fetchJson(path, { method = "GET", body, auth = false } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (auth) {
    const t = getToken();
    if (t) headers["Authorization"] = `Bearer ${t}`;
  }
  const res = await fetch(`${API_BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = {};
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    json = {};
  }
  if (!res.ok) {
    const msg = json.error || text || `HTTP ${res.status}`;
    throw new Error(msg);
  }
  return json;
}

async function login() {
  const e = document.getElementById("email")?.value?.trim() || "";
  const p = document.getElementById("password")?.value || "";
  try {
    const r = await fetchJson("/auth/login", {
      method: "POST",
      body: { email: e, password: p },
    });
    if (!r.token || !r.user) throw new Error("invalid_response");
    if (r.user.isAdmin !== true) throw new Error("admin_only");
    setSession(r.token, r.user);
    window.location = "dashboard.html";
  } catch (err) {
    console.error(err);
    alert(
      err.message === "admin_only"
        ? "Та админ биш байна!"
        : "Нэвтрэхэд алдаа: " + err.message
    );
  }
}

function logout() {
  clearSession();
  window.location = "index.html";
}

function toggleDark() {
  document.body.classList.toggle("dark-mode");
}

function openModal() {
  const m = document.getElementById("modal");
  if (m) m.style.display = "flex";
  setTimeout(initSpotPicker, 0);
}

function closeModal() {
  const m = document.getElementById("modal");
  if (m) m.style.display = "none";
}

// ---------- Spot location picker (Leaflet / OSM) ----------
let spotPickerMap = null;
let spotPickerMarker = null;

function initSpotPicker() {
  const el = document.getElementById("spotMap");
  if (!el) return;
  if (typeof L === "undefined") return;

  if (spotPickerMap) {
    try {
      spotPickerMap.invalidateSize();
    } catch {}
    syncPickerFromInputs();
    return;
  }

  const ub = [47.918873, 106.917701];
  spotPickerMap = L.map(el, { zoomControl: true }).setView(ub, 13);
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution: "&copy; OpenStreetMap",
  }).addTo(spotPickerMap);

  spotPickerMarker = L.marker(ub, { draggable: true }).addTo(spotPickerMap);
  spotPickerMarker.on("dragend", () => {
    const p = spotPickerMarker.getLatLng();
    setLatLngInputs(p.lat, p.lng);
  });

  spotPickerMap.on("click", (e) => {
    const { lat, lng } = e.latlng;
    spotPickerMarker.setLatLng([lat, lng]);
    setLatLngInputs(lat, lng);
  });

  syncPickerFromInputs();
  setTimeout(() => {
    try {
      spotPickerMap.invalidateSize();
    } catch {}
  }, 50);
}

function setLatLngInputs(lat, lng) {
  const latEl = document.getElementById("lat");
  const lngEl = document.getElementById("lng");
  if (latEl) latEl.value = String(lat.toFixed(6));
  if (lngEl) lngEl.value = String(lng.toFixed(6));
}

function syncPickerFromInputs() {
  if (!spotPickerMap || !spotPickerMarker) return;
  const latStr = document.getElementById("lat")?.value?.trim();
  const lngStr = document.getElementById("lng")?.value?.trim();
  const lat = parseFloat(latStr || "");
  const lng = parseFloat(lngStr || "");
  if (Number.isFinite(lat) && Number.isFinite(lng)) {
    spotPickerMarker.setLatLng([lat, lng]);
    spotPickerMap.setView([lat, lng], Math.max(spotPickerMap.getZoom(), 14));
  }
}

function loadSpots() {
  const tbody = document.getElementById("parkingTable");
  if (!tbody) return;
  tbody.innerHTML =
    "<tr><td colspan='4'>Ачаалж байна…</td></tr>";

  fetchJson("/spots")
    .then((r) => {
      const rows = Array.isArray(r.items) ? r.items : [];
      let html = "";
      for (const d of rows) {
        const id = d.id;
        const name = d.name ?? "Зогсоол";
        const price = d.price_per_hour ?? d.pricePerHour ?? d.price ?? "—";
        const total = d.total ?? "—";
        const lat = d.lat ?? "—";
        const lng = d.lng ?? "—";
        html += `
      <tr>
        <td>${escapeHtml(String(name))}</td>
        <td>${escapeHtml(String(price))}</td>
        <td>${escapeHtml(String(total))}</td>
        <td>
          <small>${escapeHtml(String(lat))}, ${escapeHtml(String(lng))}</small><br>
          <button type="button" onclick="deleteSpot('${escapeHtml(
            String(id)
          )}')">Устгах</button>
        </td>
      </tr>`;
      }
      tbody.innerHTML =
        html || "<tr><td colspan='4'>Одоогоор зогсоол алга</td></tr>";
    })
    .catch((err) => {
      console.error(err);
      tbody.innerHTML = `<tr><td colspan='4'>Алдаа: ${escapeHtml(
        err.message
      )}</td></tr>`;
    });
}

function escapeHtml(s) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

async function createSpot() {
  const name = document.getElementById("name")?.value?.trim();
  const price = document.getElementById("price")?.value?.trim();
  const total = document.getElementById("total")?.value?.trim();
  const address = document.getElementById("address")?.value?.trim() ?? "";
  const available = document.getElementById("available")?.value?.trim();
  const latStr = document.getElementById("lat")?.value?.trim();
  const lngStr = document.getElementById("lng")?.value?.trim();

  if (!name || !price || !total) {
    alert("Нэр, үнэ, нийт зогсоолыг бөглөнө үү!");
    return;
  }

  const lat = parseFloat(latStr || "47.918873");
  const lng = parseFloat(lngStr || "106.917701");
  if (Number.isNaN(lat) || Number.isNaN(lng)) {
    alert("Өргөрөг / уртраг тоо байх ёстой.");
    return;
  }
  // Keep within Mongolia-ish bounds so it appears on your UB-centered map
  if (lat < 40 || lat > 60 || lng < 80 || lng > 130) {
    alert("Өргөрөг/уртраг буруу байна. Газрын зураг дээрээс сонгоно уу.");
    return;
  }

  const priceNum = Number(price);
  const totalNum = Number(total);
  const availNum = available ? Number(available) : totalNum;

  try {
    await fetchJson("/admin/spots", {
      method: "POST",
      auth: true,
      body: {
        name,
        lat,
        lng,
        address,
        price_per_hour: Number.isFinite(priceNum) ? priceNum : 0,
        total: Number.isFinite(totalNum) ? totalNum : 0,
        available: Number.isFinite(availNum) ? availNum : 0,
        status: "free",
        is_available: true,
      },
    });
    closeModal();
    alert("Docker API руу хадгалагдлаа — мобайл газрын зураг дээр харагдана.");
    document.getElementById("name").value = "";
    document.getElementById("price").value = "";
    document.getElementById("total").value = "";
    if (document.getElementById("address")) document.getElementById("address").value = "";
    if (document.getElementById("available")) document.getElementById("available").value = "";
    loadSpots();
  } catch (e) {
    console.error(e);
    alert("Хадгалахад алдаа: " + e.message);
  }
}

async function deleteSpot(id) {
  if (!confirm("Энэ зогсоолыг устгах уу?")) return;
  try {
    await fetchJson(`/admin/spots/${encodeURIComponent(id)}`, {
      method: "DELETE",
      auth: true,
    });
    loadSpots();
  } catch (e) {
    alert("Устгахад алдаа: " + e.message);
  }
}

function formatDate(ts) {
  if (!ts) return "—";
  try {
    const d = new Date(ts);
    return isNaN(d.getTime()) ? "—" : d.toLocaleString("mn-MN");
  } catch {
    return "—";
  }
}

function loadUsers() {
  const tbody = document.getElementById("usersTable");
  if (!tbody) return;
  tbody.innerHTML = "<tr><td colspan='4'>Ачаалж байна…</td></tr>";

  fetchJson("/admin/users", { auth: true })
    .then((r) => {
      const rows = Array.isArray(r.items) ? r.items : [];
      let html = "";
      for (const d of rows) {
        const name = d.name ?? "—";
        const email = d.email ?? "—";
        const uid = d.id ?? "—";
        const when = formatDate(d.created_at);
        html += `
      <tr>
        <td>${escapeHtml(String(name))}</td>
        <td>${escapeHtml(String(email))}</td>
        <td><small>${escapeHtml(String(uid))}</small></td>
        <td>${escapeHtml(when)}</td>
      </tr>`;
      }
      tbody.innerHTML =
        html || "<tr><td colspan='4'>Одоогоор бүртгэл алга</td></tr>";
    })
    .catch((err) => {
      console.error(err);
      tbody.innerHTML = `<tr><td colspan='4'>Алдаа: ${escapeHtml(
        err.message
      )}</td></tr>`;
    });
}

function paymentStatusMn(status) {
  switch (status) {
    case "pending":
      return "Хүлээгдэж буй";
    case "approved":
      return "Баталгаажсан";
    case "rejected":
      return "Татгалзсан";
    default:
      return status ? String(status) : "—";
  }
}

function loadBookings() {
  const tbody = document.getElementById("bookingTable");
  if (!tbody) return;
  tbody.innerHTML = "<tr><td colspan='4'>Ачаалж байна…</td></tr>";

  fetchJson("/admin/payments", { auth: true })
    .then((r) => {
      const rows = Array.isArray(r.items) ? r.items : [];
      let html = "";
      for (const pay of rows) {
        const id = String(pay.id || "");
        const shortId = id.length > 10 ? id.slice(0, 8) + "…" : id;
        const user =
          pay.user_email && String(pay.user_email).trim()
            ? pay.user_email
            : pay.user_ref ?? "—";
        const amt = pay.amount != null ? pay.amount : "—";
        const hours = pay.hours != null ? `${pay.hours} цаг` : "";
        const method = pay.method ? String(pay.method) : "";
        const dun =
          typeof amt === "number"
            ? `₮${amt}${hours ? " · " + hours : ""}${
                method ? " · " + method : ""
              }`
            : escapeHtml(String(amt));
        const st = paymentStatusMn(pay.status);
        const when = formatDate(pay.created_at);
        html += `
      <tr>
        <td><code>${escapeHtml(shortId)}</code><br><small style="opacity:.85">${escapeHtml(
          when
        )}</small></td>
        <td>${escapeHtml(String(user))}</td>
        <td>${typeof amt === "number" ? escapeHtml(dun) : dun}</td>
        <td>${escapeHtml(st)}</td>
      </tr>`;
      }
      tbody.innerHTML =
        html ||
        "<tr><td colspan='4'>Төлбөрийн бичлэг алга. Аппаас төлбөрийн хүсэлт илгээнэ үү.</td></tr>";
    })
    .catch((err) => {
      console.error(err);
      tbody.innerHTML = `<tr><td colspan='4'>Алдаа: ${escapeHtml(
        err.message
      )}</td></tr>`;
    });
}

function initDashboardStats() {
  const elSpots = document.getElementById("dashSpotsCount");
  const elUsers = document.getElementById("dashUsersCount");
  const elBookings = document.getElementById("dashBookingsCount");
  if (!elSpots && !elUsers && !elBookings) return;

  Promise.all([
    fetchJson("/spots"),
    fetchJson("/admin/users", { auth: true }),
    fetchJson("/admin/payments", { auth: true }),
  ])
    .then(([spots, users, pays]) => {
      if (elSpots) elSpots.textContent = String((spots.items || []).length);
      if (elUsers) elUsers.textContent = String((users.items || []).length);
      if (elBookings)
        elBookings.textContent = String((pays.items || []).length);
    })
    .catch((e) => console.error(e));
}

// Guard pages (except index)
requireAuth();

if (document.getElementById("parkingTable")) {
  loadSpots();
}

if (document.getElementById("usersTable")) {
  loadUsers();
}

if (document.getElementById("bookingTable")) {
  loadBookings();
}

if (
  document.getElementById("dashSpotsCount") ||
  document.getElementById("dashUsersCount") ||
  document.getElementById("dashBookingsCount")
) {
  initDashboardStats();
}
