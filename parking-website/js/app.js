/**
 * Админ вэб: нэвтрэлт, зогсоол (Firestore — мобайл апптай ижил `parking_spots`).
 * parking.html дээр Firebase compat script-үүдийг app.js-аас өмнө ачаална.
 */

const firebaseConfig = {
  apiKey: "AIzaSyB2fr0MbQYyrJINgKO_si3BU1pVTUc-13Q",
  authDomain: "parking-3922f.firebaseapp.com",
  projectId: "parking-3922f",
  storageBucket: "parking-3922f.firebasestorage.app",
  messagingSenderId: "214141385001",
  appId: "1:214141385001:web:5ca3b53845203af3551f38",
  measurementId: "G-0H5EKX5CSV",
};

function getDb() {
  if (typeof firebase === "undefined" || !firebase.firestore) {
    return null;
  }
  if (!firebase.apps.length) {
    firebase.initializeApp(firebaseConfig);
  }
  return firebase.firestore();
}

function login() {
  const e = document.getElementById("email")?.value;
  const p = document.getElementById("password")?.value;

  if (e === "admin@greenpark.com" && p === "admin123") {
    localStorage.setItem("auth", "true");
    window.location = "dashboard.html";
  } else {
    alert("Буруу нэвтрэх мэдээлэл");
  }
}

function logout() {
  localStorage.removeItem("auth");
  window.location = "index.html";
}

function toggleDark() {
  document.body.classList.toggle("dark-mode");
}

function openModal() {
  const m = document.getElementById("modal");
  if (m) m.style.display = "flex";
}

function closeModal() {
  const m = document.getElementById("modal");
  if (m) m.style.display = "none";
}

let spotsUnsub = null;

function loadSpots() {
  const tbody = document.getElementById("parkingTable");
  if (!tbody) return;

  const db = getDb();
  if (!db) {
    tbody.innerHTML =
      "<tr><td colspan='4'>Firebase ачаалагдаагүй. parking.html дээр Firebase script шалгана уу.</td></tr>";
    return;
  }

  if (spotsUnsub) {
    spotsUnsub();
    spotsUnsub = null;
  }

  spotsUnsub = db.collection("parking_spots").onSnapshot(
    (snap) => {
      let html = "";
      snap.forEach((doc) => {
        const d = doc.data();
        const name = d.name ?? "Зогсоол";
        const price = d.pricePerHour ?? d.price ?? "—";
        const total = d.total ?? "—";
        const lat = d.lat ?? d.location?.lat ?? "—";
        const lng = d.lng ?? d.location?.lng ?? "—";
        html += `
      <tr>
        <td>${escapeHtml(String(name))}</td>
        <td>${escapeHtml(String(price))}</td>
        <td>${escapeHtml(String(total))}</td>
        <td>
          <small>${escapeHtml(String(lat))}, ${escapeHtml(String(lng))}</small><br>
          <button type="button" onclick="deleteSpot('${doc.id}')">Устгах</button>
        </td>
      </tr>`;
      });
      tbody.innerHTML = html || "<tr><td colspan='4'>Одоогоор зогсоол алга</td></tr>";
    },
    (err) => {
      console.error(err);
      tbody.innerHTML = `<tr><td colspan='4'>Firestore алдаа: ${escapeHtml(err.message)}. Console болон Firebase Rules шалгана уу.</td></tr>`;
    }
  );
}

function escapeHtml(s) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

async function createSpot() {
  const db = getDb();
  if (!db) {
    alert("Firebase ачаалагдаагүй.");
    return;
  }

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

  const priceNum = Number(price);
  const totalNum = Number(total);
  const availNum = available ? Number(available) : totalNum;

  try {
    await db.collection("parking_spots").add({
      name,
      price: String(price),
      pricePerHour: Number.isFinite(priceNum) ? priceNum : 0,
      total: Number.isFinite(totalNum) ? totalNum : 0,
      available: Number.isFinite(availNum) ? availNum : 0,
      address,
      lat,
      lng,
      location: { lat, lng },
      status: "free",
      isAvailable: true,
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
    closeModal();
    alert("Firestore руу хадгалагдлаа — мобайл газрын зураг дээр харагдана.");
    document.getElementById("name").value = "";
    document.getElementById("price").value = "";
    document.getElementById("total").value = "";
    if (document.getElementById("address")) document.getElementById("address").value = "";
    if (document.getElementById("available")) document.getElementById("available").value = "";
  } catch (e) {
    console.error(e);
    alert("Хадгалахад алдаа: " + e.message);
  }
}

async function deleteSpot(id) {
  const db = getDb();
  if (!db) return;
  if (!confirm("Энэ зогсоолыг устгах уу?")) return;
  try {
    await db.collection("parking_spots").doc(id).delete();
  } catch (e) {
    alert("Устгахад алдаа: " + e.message);
  }
}

let usersUnsub = null;

function formatDate(ts) {
  if (!ts) return "—";
  try {
    const d = ts.toDate ? ts.toDate() : new Date(ts);
    return isNaN(d.getTime()) ? "—" : d.toLocaleString("mn-MN");
  } catch {
    return "—";
  }
}

function loadUsers() {
  const tbody = document.getElementById("usersTable");
  if (!tbody) return;

  const db = getDb();
  if (!db) {
    tbody.innerHTML =
      "<tr><td colspan='4'>Firebase ачаалагдаагүй.</td></tr>";
    return;
  }

  if (usersUnsub) {
    usersUnsub();
    usersUnsub = null;
  }

  usersUnsub = db.collection("users").onSnapshot(
    (snap) => {
      const rows = [];
      snap.forEach((doc) => {
        rows.push({ id: doc.id, ...doc.data() });
      });
      rows.sort((a, b) => {
        const ta =
          a.createdAt && a.createdAt.toMillis
            ? a.createdAt.toMillis()
            : 0;
        const tb =
          b.createdAt && b.createdAt.toMillis
            ? b.createdAt.toMillis()
            : 0;
        return tb - ta;
      });
      let html = "";
      for (const d of rows) {
        const name = d.name ?? "—";
        const email = d.email ?? "—";
        const uid = d.uid ?? d.id;
        const when = formatDate(d.createdAt);
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
    },
    (err) => {
      console.error(err);
      tbody.innerHTML = `<tr><td colspan='4'>Алдаа: ${escapeHtml(err.message)} — Firestore Rules-д <code>users</code> уншихыг зөвшөөрнө үү.</td></tr>`;
    }
  );
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

let bookingsUnsub = null;

/** Мобайлын төлбөрийн хүсэлтүүд — Firestore `payments` */
function loadBookings() {
  const tbody = document.getElementById("bookingTable");
  if (!tbody) return;

  const db = getDb();
  if (!db) {
    tbody.innerHTML =
      "<tr><td colspan='4'>Firebase ачаалагдаагүй. bookings.html дээр script шалгана уу.</td></tr>";
    return;
  }

  if (bookingsUnsub) {
    bookingsUnsub();
    bookingsUnsub = null;
  }

  bookingsUnsub = db.collection("payments").onSnapshot(
    (snap) => {
      const rows = [];
      snap.forEach((doc) => {
        rows.push({ id: doc.id, ...doc.data() });
      });
      rows.sort((a, b) => {
        const ta =
          a.createdAt && a.createdAt.toMillis
            ? a.createdAt.toMillis()
            : 0;
        const tb =
          b.createdAt && b.createdAt.toMillis
            ? b.createdAt.toMillis()
            : 0;
        return tb - ta;
      });
      let html = "";
      for (const r of rows) {
        const shortId =
          r.id.length > 10 ? r.id.slice(0, 8) + "…" : r.id;
        const user =
          r.userEmail && String(r.userEmail).trim()
            ? r.userEmail
            : r.userId ?? "—";
        const amt = r.amount != null ? r.amount : "—";
        const hours = r.hours != null ? `${r.hours} цаг` : "";
        const method = r.method ? String(r.method) : "";
        const dun =
          typeof amt === "number"
            ? `₮${amt}${hours ? " · " + hours : ""}${method ? " · " + method : ""}`
            : escapeHtml(String(amt));
        const st = paymentStatusMn(r.status);
        const when = formatDate(r.createdAt);
        html += `
      <tr>
        <td><code>${escapeHtml(shortId)}</code><br><small style="opacity:.85">${escapeHtml(when)}</small></td>
        <td>${escapeHtml(String(user))}</td>
        <td>${typeof amt === "number" ? escapeHtml(dun) : dun}</td>
        <td>${escapeHtml(st)}</td>
      </tr>`;
      }
      tbody.innerHTML =
        html ||
        "<tr><td colspan='4'>Төлбөрийн бичлэг алга. Аппаас төлбөрийн хүсэлт илгээнэ үү.</td></tr>";
    },
    (err) => {
      console.error(err);
      tbody.innerHTML = `<tr><td colspan='4'>Алдаа: ${escapeHtml(err.message)} — <code>payments</code> унших Rules шалгана уу.</td></tr>`;
    }
  );
}

function initDashboardStats() {
  const elSpots = document.getElementById("dashSpotsCount");
  const elUsers = document.getElementById("dashUsersCount");
  const elBookings = document.getElementById("dashBookingsCount");
  if (!elSpots && !elUsers && !elBookings) return;

  const db = getDb();
  if (!db) return;

  if (elSpots) {
    db.collection("parking_spots").onSnapshot((snap) => {
      elSpots.textContent = String(snap.size);
    });
  }
  if (elUsers) {
    db.collection("users").onSnapshot((snap) => {
      elUsers.textContent = String(snap.size);
    });
  }
  if (elBookings) {
    db.collection("payments").onSnapshot((snap) => {
      elBookings.textContent = String(snap.size);
    });
  }
}

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
