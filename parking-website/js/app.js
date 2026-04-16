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
        const id = d.id ?? "";
        const when = formatDate(d.created_at);
        html += `
      <tr style="cursor:pointer" onclick="openUserDetails('${escapeHtml(String(id))}')">
        <td>${escapeHtml(String(name))}</td>
        <td>${escapeHtml(String(email))}</td>
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

function closeUserModal(ev) {
  if (ev && ev.target && ev.target.id !== "userModal") return;
  const m = document.getElementById("userModal");
  if (m) m.style.display = "none";
}

async function openUserDetails(userId) {
  const id = String(userId || "").trim();
  if (!id) return;
  const m = document.getElementById("userModal");
  const body = document.getElementById("userModalBody");
  if (!m || !body) return;
  m.style.display = "flex";
  body.innerHTML = "<p>Ачаалж байна…</p>";
  try {
    const d = await fetchJson(`/admin/users/${encodeURIComponent(id)}/details`, {
      auth: true,
    });
    const user = d.user || {};
    const cars = Array.isArray(d.cars) ? d.cars : [];
    const active = d.activeBooking || null;

    const carsHtml =
      cars.length === 0
        ? "<p><b>Машин:</b> бүртгэлгүй</p>"
        : `<div><b>Машинууд:</b><ul style="margin:8px 0 0 18px;">${cars
            .map((c) => {
              const nm = (c.name ?? "Машин").toString();
              const pl = (c.plate ?? "—").toString();
              return `<li>${escapeHtml(nm)} — <code>${escapeHtml(pl)}</code></li>`;
            })
            .join("")}</ul></div>`;

    let activeHtml = "<p><b>Одоогоор зогсож буй:</b> байхгүй</p>";
    if (active) {
      const spot = active.spot_name ?? "—";
      const plate = active.car_plate ?? "—";
      const started = formatDate(active.started_at);
      const hours = active.hours ?? "—";
      const amount =
        typeof active.amount === "number" ? `₮${active.amount}` : active.amount ?? "—";
      activeHtml = `
        <div style="margin-top:12px;">
          <b>Одоогоор зогсож буй:</b>
          <div style="margin-top:8px; opacity:.95">
            <div>Зогсоол: ${escapeHtml(String(spot))}</div>
            <div>Машин: <code>${escapeHtml(String(plate))}</code></div>
            <div>Эхэлсэн: ${escapeHtml(String(started))}</div>
            <div>Хугацаа: ${escapeHtml(String(hours))} цаг</div>
            <div>Дүн: <b>${escapeHtml(String(amount))}</b></div>
          </div>
        </div>`;
    }

    body.innerHTML = `
      <div style="display:grid; grid-template-columns: 1fr 1fr; gap:12px;">
        <div>
          <b>Нэр:</b> ${escapeHtml(String(user.name ?? "—"))}<br>
          <b>Имэйл:</b> ${escapeHtml(String(user.email ?? "—"))}<br>
          <b>Бүртгүүлсэн:</b> ${escapeHtml(formatDate(user.created_at))}<br>
        </div>
        <div>
          <b>Wallet:</b> ${escapeHtml(
            user.wallet_balance != null ? `₮${user.wallet_balance}` : "—"
          )}<br>
          <b>Админ:</b> ${user.is_admin ? "Тийм" : "Үгүй"}<br>
        </div>
      </div>
      <hr style="margin:14px 0; opacity:.25">
      ${carsHtml}
      ${activeHtml}
      <p style="margin-top:12px; opacity:.7; font-size:12px;">
        Нууц үг харагдахгүй (аюулгүй байдлын үүднээс).
      </p>
    `;
  } catch (e) {
    console.error(e);
    body.innerHTML = `<p>Алдаа: ${escapeHtml(e.message || String(e))}</p>`;
  }
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
  tbody.innerHTML = "<tr><td colspan='5'>Ачаалж байна…</td></tr>";

  fetchJson("/admin/bookings", { auth: true })
    .then((r) => {
      const rows = Array.isArray(r.items) ? r.items : [];
      let html = "";
      for (const b of rows) {
        const user = b.user_email ? String(b.user_email) : "—";
        const car = b.car_plate ? String(b.car_plate) : "—";
        const spot = b.spot_name ? String(b.spot_name) : "—";
        const amt = b.amount != null ? b.amount : "—";
        const hours = b.hours != null ? `${b.hours} цаг` : "";
        const method = b.payment_method ? String(b.payment_method) : "";
        const dun =
          typeof amt === "number"
            ? `₮${amt}${hours ? " · " + hours : ""}${method ? " · " + method : ""}`
            : escapeHtml(String(amt));
        const st =
          b.status === "paid"
            ? "Баталгаажсан"
            : b.status === "active"
              ? "Идэвхтэй"
              : b.status === "cancelled"
                ? "Цуцлагдсан"
                : String(b.status || "—");
        html += `
      <tr>
        <td>${escapeHtml(String(user))}</td>
        <td><code>${escapeHtml(String(car))}</code></td>
        <td>${escapeHtml(String(spot))}</td>
        <td>${typeof amt === "number" ? escapeHtml(dun) : dun}</td>
        <td>${escapeHtml(st)}</td>
      </tr>`;
      }
      tbody.innerHTML =
        html ||
        "<tr><td colspan='5'>Одоогоор захиалга алга.</td></tr>";
    })
    .catch((err) => {
      console.error(err);
      tbody.innerHTML = `<tr><td colspan='5'>Алдаа: ${escapeHtml(
        err.message
      )}</td></tr>`;
    });
}

function loadTopupRequests() {
  const tbody = document.getElementById("topupTable");
  if (!tbody) return;
  tbody.innerHTML = "<tr><td colspan='4'>Ачаалж байна…</td></tr>";

  fetchJson("/admin/payments/pending", { auth: true })
    .then((r) => {
      const rows = Array.isArray(r.items) ? r.items : [];
      const topups = rows.filter((p) => String(p.note || "").startsWith("topup:"));
      let html = "";
      for (const p of topups) {
        const id = String(p.id || "");
        const user = p.user_email ? String(p.user_email) : p.user_ref ?? "—";
        const amt = p.amount != null ? p.amount : "—";
        const method = p.method ? String(p.method) : "";
        const when = formatDate(p.created_at);
        html += `
      <tr>
        <td>${escapeHtml(user)}</td>
        <td>${escapeHtml(typeof amt === "number" ? `₮${amt}${method ? " · " + method : ""}` : String(amt))}</td>
        <td><small style="opacity:.85">${escapeHtml(when)}</small></td>
        <td>
          <button type="button" onclick="approvePayment('${escapeHtml(id)}')">Зөвшөөрөх</button>
          <button type="button" onclick="rejectPayment('${escapeHtml(id)}')" style="margin-left:8px;">Татгалзах</button>
        </td>
      </tr>`;
      }
      tbody.innerHTML = html || "<tr><td colspan='4'>Pending хүсэлт алга.</td></tr>";
    })
    .catch((err) => {
      console.error(err);
      tbody.innerHTML = `<tr><td colspan='4'>Алдаа: ${escapeHtml(err.message)}</td></tr>`;
    });
}

async function approvePayment(id) {
  try {
    await fetchJson(`/admin/payments/${encodeURIComponent(id)}`, {
      method: "PATCH",
      auth: true,
      body: { action: "approve" },
    });
    loadTopupRequests();
  } catch (e) {
    alert("Зөвшөөрөхөд алдаа: " + e.message);
  }
}

async function rejectPayment(id) {
  try {
    await fetchJson(`/admin/payments/${encodeURIComponent(id)}`, {
      method: "PATCH",
      auth: true,
      body: { action: "reject" },
    });
    loadTopupRequests();
  } catch (e) {
    alert("Татгалзахад алдаа: " + e.message);
  }
}

function copyText(txt) {
  const t = String(txt || "");
  if (!t) return;
  if (navigator.clipboard?.writeText) {
    navigator.clipboard.writeText(t).catch(() => {});
  } else {
    const el = document.createElement("textarea");
    el.value = t;
    document.body.appendChild(el);
    el.select();
    try { document.execCommand("copy"); } catch {}
    document.body.removeChild(el);
  }
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

if (document.getElementById("topupTable")) {
  loadTopupRequests();
}

if (
  document.getElementById("dashSpotsCount") ||
  document.getElementById("dashUsersCount") ||
  document.getElementById("dashBookingsCount")
) {
  initDashboardStats();
}
