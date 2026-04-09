# Parking system (diploma)

Зогсоолын систем: **Flutter** хэрэглэгчийн апп, **static HTML/JS** админ вэб, **Docker** дээр ажилладаг **Node.js + PostgreSQL** backend.

Репозитор: [https://github.com/bluebell1114/parking_sysytem1](https://github.com/bluebell1114/parking_sysytem1)

## Юу юу байдаг вэ

| Хавтас | Үүрэг |
|--------|--------|
| **`mobile_bas2/`** | Docker Compose: PostgreSQL + REST API (`JWT`, бүртгэл, зогсоол, захиалга, түрийвч, төлбөр). Порт: API **4000**, DB **5434**. |
| **`parking-mobile/`** | Flutter апп (Android / Web / Windows). Газрын зураг: OpenStreetMap (`flutter_map`). Backend руу HTTP. |
| **`parking-website/`** | Админ вэб (`index.html`, `dashboard.html`, `js/app.js`). Static серверээр асаана. |

Өмнө Firebase ашиглаж байсан хэсгийг **нэг Docker API** руу нэгтгэсэн тул мобайл болон вэб **ижил өгөгдлийг** API-аас уншина.

## Backend асаах (заавал)

1. [Docker Desktop](https://www.docker.com/products/docker-desktop/) суусан байх.
2. Терминал:

```bash
cd mobile_bas2
docker compose up --build -d
```

3. Шалгах: хөтөчөөр `http://127.0.0.1:4000/health` — `{"ok":true}` гэж харагдана.

## Мобайл ажиллуулах

```bash
cd parking-mobile
flutter pub get
flutter run
```

- **Вэб (Chrome):** API хаяг: `http://127.0.0.1:4000`
- **Android эмулятор:** `10.0.2.2:4000` (апп дотор тохируулсан)
- **Бодит утас:** PC-тэй ижил сүлжээнд компьютерын LAN IP + `:4000` — шаардлагатай бол `flutter run --dart-define=API_BASE_URL=http://Таны_IP:4000`

## Вэб админ ажиллуулах

```bash
cd parking-website
npx --yes serve .
```

Хөтөчөөр гарсан хаяг (ихэвчлэн `http://localhost:3000`) нээнэ. Нэвтрэхийн өмнө **backend заавал** ассан байх.

## Нэвтрэх (жишээ)

- Анхны суулгах үед API **seed** хийгдэнэ: админ **`admin@greenpark.com` / `admin123`** (зөвхөн хоосон DB-д).
- Бусад хэрэглэгчийг аппын **Бүртгэл**-ээр үүсгэнэ.

## Техникийн товч

- **API:** Express, `bcrypt`, JWT, PostgreSQL транзакц (түрийвч, захиалга, зогсоолын сул орон).
- **Мобайл:** `shared_preferences` (session), `http`, `flutter_map`, `url_launcher` (банкны холбоос).

Эх хавтсанд үлдсэн хуучин нэг түвшний `.dart` файлууд түүхэн үлдэгдэл байж болно; идэвхтэй хөгжүүлэлт **`parking-mobile/`** болон **`parking-website/`** дотор хийгдэнэ.
