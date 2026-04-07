// ================= LOGIN =================

function login() {
  let e = document.getElementById("email")?.value;
  let p = document.getElementById("password")?.value;

  if (e === "admin@greenpark.com" && p === "admin123") {
    localStorage.setItem("auth", "true");
    window.location = "dashboard.html";
  } else {
    alert("Wrong credentials");
  }
}

function logout() {
  localStorage.removeItem("auth");
  window.location = "index.html";
}

// ================= MODAL =================

function openModal() {
  document.getElementById("modal").style.display = "flex";
}

function closeModal() {
  document.getElementById("modal").style.display = "none";
}

// USER MODAL
function openUserModal() {
  document.getElementById("userModal").style.display = "flex";
}

function closeUserModal() {
  document.getElementById("userModal").style.display = "none";
}
// ================= LOGIN =================

function login() {
  let e = document.getElementById("email")?.value.trim();
  let p = document.getElementById("password")?.value.trim();

  console.log("LOGIN TRY:", e, p);

  if (e === "admin@greenpark.com" && p === "admin123") {
    localStorage.setItem("auth", "true");

    alert("Амжилттай нэвтэрлээ ✅");

    window.location.href = "dashboard.html";
  } else {
    alert("Имэйл эсвэл нууц үг буруу ❌");
  }
}

// ================= LOGOUT =================

function logout() {
  localStorage.removeItem("auth");
  window.location.href = "index.html";
}

// ================= хамгаалалт =================

if (!localStorage.getItem("auth") && !window.location.pathname.includes("index.html")) {
  window.location.href = "index.html";
}  

// ================= PARKING =================

// ================= ГАРАХ =================
function logout(){
  localStorage.removeItem("auth");
  window.location="index.html";
}

// ================= MODAL =================
function openModal(){
  document.getElementById("modal").style.display="flex";
}

function closeModal(){
  document.getElementById("modal").style.display="none";
}

// ================= DATA =================
let spots = JSON.parse(localStorage.getItem("spots")) || [];
let editIndex = -1;

// ================= LOAD =================
function loadSpots(){
  let html="";

  spots.forEach((s,i)=>{
    html += `
      <tr>
        <td>${s.name}</td>
        <td>${s.zone} бүс</td>
        <td>${s.address}</td>
        <td>${s.price}₮</td>
        <td>${s.total}</td>
        <td>
          <button onclick="editSpot(${i})">✏️</button>
          <button onclick="deleteSpot(${i})">🗑</button>
        </td>
      </tr>
    `;
  });

  document.getElementById("parkingTable").innerHTML = html;
}

// ================= ADD / EDIT =================
function createSpot(){
  let name = document.getElementById("name").value;
  let zone = document.getElementById("zone").value;
  let address = document.getElementById("address").value;
  let price = document.getElementById("price").value;
  let total = document.getElementById("total").value;

  if(!name || !price || !total || !address){
    alert("⚠️ Бүх талбарыг бөглөнө үү!");
    return;
  }

  let newSpot = { name, zone, address, price, total };

  if(editIndex === -1){
    spots.push(newSpot);
  } else {
    spots[editIndex] = newSpot;
    editIndex = -1;
  }

  localStorage.setItem("spots", JSON.stringify(spots));

  loadSpots();
  closeModal();

  alert("✅ Амжилттай хадгалагдлаа");
}

// ================= EDIT =================
function editSpot(i){
  let s = spots[i];

  document.getElementById("name").value = s.name;
  document.getElementById("zone").value = s.zone;
  document.getElementById("address").value = s.address;
  document.getElementById("price").value = s.price;
  document.getElementById("total").value = s.total;

  editIndex = i;

  openModal();
}

// ================= DELETE =================
function deleteSpot(i){
  if(confirm("Устгах уу?")){
    spots.splice(i,1);
    localStorage.setItem("spots", JSON.stringify(spots));
    loadSpots();
  }
}

// ================= AUTO =================
document.addEventListener("DOMContentLoaded", loadSpots);
// ================= USERS =================

let users = JSON.parse(localStorage.getItem("users")) || [];
let editUserIndex = -1;

function saveUsers() {
  localStorage.setItem("users", JSON.stringify(users));
}

function loadUsers() {
  let table = document.getElementById("userTable");
  if (!table) return;

  let html = "";

  users.forEach((u, i) => {
    html += `
      <tr>
        <td>${u.name}</td>
        <td>${u.email}</td>
        <td>${u.phone || ""}</td>
        <td>
          <button onclick="editUser(${i})">Edit</button>
          <button onclick="deleteUser(${i})">Delete</button>
        </td>
      </tr>
    `;
  });

  table.innerHTML = html;
}

// ADD + EDIT
function saveUser() {
  let name = document.getElementById("u_name").value;
  let email = document.getElementById("u_email").value;
  let phone = document.getElementById("u_phone").value;

  if (!name || !email || !phone) {
    alert("Бүх талбарыг бөглөнө үү!");
    return;
  }

  let user = { name, email, phone };

  if (editUserIndex === -1) {
    users.push(user);
  } else {
    users[editUserIndex] = user;
    editUserIndex = -1;
  }

  saveUsers();
  loadUsers();
  closeUserModal();
}

// EDIT
function editUser(i) {
  let u = users[i];

  document.getElementById("u_name").value = u.name;
  document.getElementById("u_email").value = u.email;
  document.getElementById("u_phone").value = u.phone || "";

  editUserIndex = i;

  openUserModal();
}

// DELETE
function deleteUser(i) {
  if (confirm("Устгах уу?")) {
    users.splice(i, 1);
    saveUsers();
    loadUsers();
  }
}

// ================= AUTO LOAD =================

document.addEventListener("DOMContentLoaded", () => {
  loadSpots();
  loadUsers();
});