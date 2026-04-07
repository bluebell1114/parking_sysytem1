# Parking system — 2 тусдаа хэсэг

| Хавтас | Агуулга |
|--------|---------|
| **`parking-mobile/`** | Flutter апп (Android / Web / Windows). Ажиллуулах: `cd parking-mobile` → `flutter run` |
| **`parking-website/`** | Админ static вэб (`index.html`, `dashboard.html`, `js/`, `css/`). Сервер: `npx serve parking-website` |

Өмнө нь нэг дор байсан файлууд эдгээр хоёр хавтсанд шилжсэн.

**Бүтэц:** Зөвхөн `parking-mobile/` болон `parking-website/` ашиглана. Эх хавтсанд `build` үлдсэн бол түгжигдсэн процессоос шалтгаалж байж магадгүй — хаагаад устгана уу.

**Анхаар:** Бүх Flutter/Android код `parking-mobile/android` дотор.

## Мобайлд бүртгүүлсэн хэрэглэгч вэб дээр

- **Мобайл:** `parking-mobile/lib/register_page.dart` — бүртгэл амжилтын дараа Firestore **`users`** коллекцэд (`uid`, `email`, `name`, `createdAt`) бичнэ.
- **Вэб:** `parking-website/users.html` — **Хэрэглэгчид** цэс → `js/app.js` ижил төсөл **`parking-3922f`**-оос `users`-ийг real-time уншина.
- **Самбар:** `dashboard.html` дээр **Бүртгэлтэй хэрэглэгч** тоо шинэчлэгдэнэ.

Хэрэглэгч харагдахгүй бол Firebase Console → Firestore **Rules** дээр `users` уншихыг зөвшөөрнө үү (`parking-website/firestore.rules` жишээг хуулаад Publish). Хуучнаар зөвхөн Auth-д бүртгүүлсэн, Firestore-д бичээгүй хэрэглэгч жагсаалтад орохгүй — дахин бүртгүүлэх эсвэл гараар `users` документ нэмнэ.

## Мобайл нэвтрэхгүй байвал

- **Апп дээр бүртгүүлсэн имэйл + нууц үг** ашиглана (вэбийн `admin@greenpark.com` / `admin123` нь Firebase Auth-д автоматаар үүсдэггүй).
- Firebase Console → **Authentication** → **Sign-in method** → **Email/Password** идэвхтэй эсэхийг шалгана.
- Алдааны мессеж одоо дэлгэц дээр **монголоор** гарна (`invalid-credential`, `user-not-found` гэх мэт).
