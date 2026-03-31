
function login() {
  let e = document.getElementById("email")?.value;
  let p = document.getElementById("password")?.value;

  if(e==="admin@greenpark.com" && p==="admin123"){
    localStorage.setItem("auth","true");
    window.location="dashboard.html";
  } else {
    alert("Wrong credentials");
  }
}


function logout(){
  localStorage.removeItem("auth");
  window.location="index.html";
}


function openModal(){
  document.getElementById("modal").style.display="flex";
}

function closeModal(){
  document.getElementById("modal").style.display="none";
}


let spots = JSON.parse(localStorage.getItem("spots")) || [];


function saveSpots(){
  localStorage.setItem("spots", JSON.stringify(spots));
}


function loadSpots(){
  let html="";

  spots.forEach((s,i)=>{
    html += `
      <tr>
        <td>${s.name}</td>
        <td>$${s.price}</td>
        <td>${s.total}</td>
        <td>
          <button onclick="deleteSpot(${i})">Delete</button>
        </td>
      </tr>
    `;
  });

  document.getElementById("parkingTable").innerHTML = html;
}


function createSpot(){
  let name = document.getElementById("name").value;
  let price = document.getElementById("price").value;
  let total = document.getElementById("total").value;

  if(!name || !price || !total){
    alert("Бүх талбарыг бөглөнө үү!");
    return;
  }

  let newSpot = { name, price, total };

  spots.push(newSpot);
  localStorage.setItem("spots", JSON.stringify(spots));

  loadSpots();
  closeModal();

  alert("Амжилттай нэмэгдлээ ✅");
}


function deleteSpot(i){
  spots.splice(i,1);
  saveSpots();  
  loadSpots();
}


if(document.getElementById("parkingTable")){
  loadSpots();
}
function createSpot(){
  let name = document.getElementById("name")?.value;
  let price = document.getElementById("price")?.value;
  let total = document.getElementById("total")?.value;

  console.log(name, price, total); 

  if(!name || !price || !total){
    alert("Бүх талбарыг бөглөнө үү!");
    return;
  }

  let newSpot = {
    name: name,
    price: price,
    total: total
  };

  spots.push(newSpot);
  localStorage.setItem("spots", JSON.stringify(spots));

  loadSpots();

  closeModal();

  alert("Амжилттай нэмэгдлээ ✅");
}