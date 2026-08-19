# dart_book

Dart-библиотека для чтения, создания и конвертации электронных книг в форматах **EPUB** (EPUB 2 / 3) и **FB2** (FB2 2.0–2.2, FB2.zip).

В основе библиотеки лежит единая модель данных (`Book`), которая представляет книгу в виде дерева блоков и инлайновых элементов, независимо от исходного формата.

---

## Возможности

### 📖 Поддержка форматов по версиям спецификаций

Легенда статусов: ✅ — полная поддержка; ⚠️ — частичная (с оговорками); ❌ — не поддерживается; — — неприменимо.

#### EPUB 2.0.1 (базовый набор)

| Функция спецификации | Статус |
| --- | --- |
| OCF-контейнер (ZIP, `mimetype`, `META-INF/`) | ✅ |
| OPF-пакет: метаданные (DC), `manifest`, `spine` | ✅ |
| Элемент `<guide>` | ❌ |
| Навигация NCX (`toc.ncx`) | ✅ |
| XHTML 1.1 контент | ✅ |
| CSS-стили | ⚠️ хранятся как ресурс, не применяются |
| Встроенные шрифты (TTF/OTF) | ✅ |
| Изображения (GIF/JPEG/PNG/SVG) | ✅ |
| Детекция DRM (`META-INF/encryption.xml`) | ✅ |

#### EPUB 3.0–3.2 (новшества относительно 2.0.1)

| Функция спецификации | Статус |
| --- | --- |
| NAV XHTML вместо NCX | ✅ |
| `epub:type` структурная семантика | ⚠️ частично: `noteref`, типы NAV |
| HTML5 XHTML-контент | ✅ |
| MathML | ✅ |
| SVG-контент | ✅ |
| Медиа `<audio>`/`<video>` | ⚠️ блоки парсятся, ресурсы из манифеста не извлекаются |
| Media Overlays (SMIL) | ❌ парсер есть, к декодеру/энкодеру не подключён |
| Скриптинг (JavaScript) | ❌ |
| Fixed layout (`rendition:layout`/`spread`/`viewport`) | ❌ |
| Обфускация шрифтов | ❌ |
| Метаданные с `properties`/`refines` | ⚠️ только базовые `dc:*` |
| Новые core media types (WOFF, OPUS и др.) | ⚠️ WOFF извлекается, валидация типов не выполняется |

#### EPUB 3.3 (новшества относительно 3.2)

| Функция спецификации | Статус |
| --- | --- |
| Статус W3C Recommendation (первая REC-версия EPUB 3) | ✅ контейнер соответствует |
| `epub:type` на SVG | ⚠️ SVG хранится как сырой блок без анализа |
| Требования доступности (EPUB Accessibility) | ❌ |
| Рекомендации security/privacy | — неприменимо для парсера/энкодера |
| TTS-расширения (WG Note) | ❌ |

#### EPUB 3.4 (новшества относительно 3.3)

| Функция спецификации | Статус |
| --- | --- |
| Roll layout (вебтуны) | ❌ |
| EPUB Annotations 1.0 | ❌ |
| `pageBreakSource` property | ❌ |
| ITS (i18n) атрибуты в XHTML | ⚠️ проходят транзитом в сырых блоках |
| Новые core media types: AVIF, JPEG XL, OPUS в MP4 | ⚠️ хранятся как бинарные ресурсы |
| Удалены: `flow`/`orientation`/`spread` fixed-layout | — никогда не поддерживались |

#### FB2 2.0 (базовый набор)

| Функция спецификации | Статус |
| --- | --- |
| `description` / `title-info` | ✅ |
| `document-info` (id, version, date, src-url…) | ⚠️ при чтении извлекается только id; полный блок пишет энкодер |
| `publish-info` | ❌ |
| `genre` | ✅ |
| `author` (first/middle/last/nickname, home-page, email) | ✅ |
| `book-title`, `lang` | ✅ |
| `annotation` | ✅ |
| `keywords` | ✅ |
| `sequence` | ✅ |
| `coverpage` | ✅ |
| `custom-info` | ⚠️ только `sequence-url` |
| `body` / `section` / `title` / `subtitle` / `p` / `empty-line` | ✅ |
| `image` (блочная и инлайн) | ✅ |
| `binary` (base64) | ✅ |
| `poem` / `stanza` / `v` | ✅ |
| `epigraph` | ✅ |
| `cite` | ✅ |
| `table` (простая) | ✅ |
| `text-author` | ⚠️ только как атрибуция цитаты |
| Инлайн: `strong`, `emphasis`, `a`, `style` | ⚠️ strong/emphasis/a ✅, `style` ❌ |
| Кодировки UTF-8 / Windows-1251 | ✅ |
| FB2.zip | ✅ |

#### FB2 2.1 (новшества относительно 2.0)

| Функция спецификации | Статус |
| --- | --- |
| `src-title-info` (переводные книги) | ❌ |
| Инлайн `sub` / `sup` / `code` / `strikethrough` | ✅ |
| `text-author` как форматируемый тип (styleType) | ⚠️ парсится как инлайн-цитата |
| `output` (инструкции платной конвертации) | ❌ |
| Новый список жанров | ✅ |
| Таблицы с `colspan`/`rowspan`/`align`/`valign` | ❌ |
| Атрибуты `id`/`title` у `image` | ❌ не сохраняются |

#### FB2 2.2 (новшества относительно 2.1)

| Функция спецификации | Статус |
| --- | --- |
| `stylesheet` | ❌ |
| `custom-info` с `info-type` | ⚠️ только `sequence-url` |
| Несколько `<body>` (кроме main/notes) | ⚠️ `notes` распознаётся, прочие — как обычные секции |
| Расширения жанров | ❌ |

#### Конвертация

Чтение любого поддерживаемого формата в объект `Book` и сохранение в любой целевой формат (EPUB ↔ FB2 / FB2.zip). Энкодер EPUB генерирует пакет `version="3.0"` (совместим с 3.0–3.4, версия в пакете не меняется по спецификации).

### 🌳 Единая модель данных (AST)
- **Формато-независимое представление**: книга представляется структурой `Book` (`metadata`, `content`, `resources`).
- **Метаданные (`BookMetadata`)**: название, язык, авторы с ролями (`BookContributor`), жанры, серии, аннотация, обложка, даты.
- **Типизированные блоки (`BookBlock`)**: секции/главы, параграфы, заголовки (h1–h6), списки, таблицы, стихи, цитаты, код, медиа.
- **Строчные элементы (`BookInline`)**: текст, акценты (strong, em, strike), ссылки, якоря, встроенный код, формулы, надстрочные/подстрочные знаки, сноски.
- **Ресурсы (`BookResource`)**: хранение бинарных данных (изображения, шрифты, аудио) с MIME-типами и исходными путями.

### 🛠 Инструменты создания и скрейпинга
- **Поглавная сборка (`BookBuilder`)**: добавление глав из фрагментов HTML с автоматическим извлечением ссылок на медиа.
- **Сетевой пайплайн (`BookResourceResolver`)**: кастомная загрузка картинок с поддержкой любых HTTP-заголовков, cookie и авторизации.
- **Политики именования (`BookResourceNamingPolicy`)**: стандартизация имен файлов (сохранение оригинальных имен, порядковая нумерация `img_001.jpg`, хэширование ссылок или кастомная функция).
- **Парсер разметки (`HtmlParser`)**: преобразование HTML5-разметки в блоки `BookBlock`.

### ⚡ Производительность и надежность
- **Фоновый парсинг (`DartBook.loadIsolated`)**: выполнение декодирования в отдельном потоке (`Isolate.run`), исключающее фризы UI.
- **Гибкая валидация (`strictMode`)**:
  - `strictMode: true` — выброс типизированных исключений (`BookParseException`, `BookMalformedMetadataException`) при ошибках структуры.
  - `strictMode: false` — мягкий пропуск некритичных ошибок с отправкой сообщений в переданный `logger`.
- **Расширяемость (`BookRegistry`)**: возможность регистрировать собственные декодеры и энкодеры для добавления новых форматов.

---

## Основной API

### `DartBook`
Главная точка входа для загрузки книг.
- `load(bytes, {filename, options, resourceResolver})` — разбор книги в текущем изоляте с автоопределением формата.
- `loadIsolated(bytes, {filename, options, resourceResolver})` — разбор книги в отдельном изоляте (`Isolate.run`).

### Конвертеры
- `EpubConverter` / `EpubDecoder` / `EpubEncoder` — работа с форматом EPUB.
  - `EpubConverter.bookToEpub(book)`
  - `EpubConverter.epubToBook(bytes)`
- `Fb2Converter` / `Fb2Decoder` / `Fb2Encoder` — работа с форматом FB2.
  - `Fb2Converter.bookToFb2(book, {isZip = false})`
  - `Fb2Converter.bookToFb2Zip(book)`
  - `Fb2Converter.fb2ToBook(bytes)`
- `BookRegistry` — реестр декодеров и энкодеров. Позволяет регистрировать обработчики для новых форматов (`registerDecoder`, `registerEncoder`).

---

## Модель данных

### Структура `Book`
- **`metadata` (`BookMetadata`)**:
  - `title` — название книги.
  - `language` — код языка (`'ru'`, `'en'`).
  - `contributors` — список участников (`BookContributor`: автор, переводчик, редактор и др.).
  - `genres` — список жанров (`BookGenre`).
  - `keywords` — список тегов / ключевых слов.
  - `series` — серия книг (`BookSeries`: название, номер, ссылка).
  - `annotation` — аннотация (`BookContent`).
  - `cover` — обложка (`BookCover`).
  - `source` — исходный URI.
- **`content` (`BookContent`)**:
  - `blocks` — список блочных элементов (`List<BookBlock>`).
  - `footnotes` — список сносок (`List<BookFootnote>`).
- **`resources` (`List<BookResource>`)**:
  - Медиафайлы (изображения, шрифты, стили, аудио).

### Блочные элементы (`BookBlock`)
- `BookSection` — раздел / глава (`title`, `blocks`, `children`).
- `BookHeading` — заголовок (`level` от 1 до 6, `text`).
- `BookParagraph` — абзац (`inlines`).
- `BookQuote` — цитата / эпиграф (`blocks`, `citation`).
- `BookList` — список (`ordered`, `items`).
- `BookTable` — таблица (`rows` -> `cells` с поддержкой `colSpan` и `rowSpan`).
- `BookPoem` — стихотворение (`stanzas` -> `lines`).
- `BookImageBlock` — изображение (`ref`, `alt`, `title`).
- `BookAudioBlock` / `BookVideoBlock` — медиа (`ref`, `controls`).
- `BookMathBlock` — блок MathML формулы (`mathml`).
- `BookSvgBlock` — векторный блок SVG (`svg`).
- `BookCodeBlock` — блок исходного кода (`code`, `language`).
- `BookHorizontalRule` — горизонтальная линия (`<hr/>`).
- `BookEmptyLine` — пустая строка.

### Строчные элементы (`BookInline`)
- `BookText` — текст (`text`).
- `BookLineBreak` — перенос строки (`<br/>`).
- `BookEmphasis` — курсив (`children`).
- `BookStrong` — полужирный текст (`children`).
- `BookStrike` — зачёркнутый текст (`children`).
- `BookCodeSpan` — встроенный код (`code`).
- `BookLink` — ссылка (`href`, `children`).
- `BookAnchor` — якорь внутри книги (`id`).
- `BookImageInline` — строчная картинка (`ref`, `alt`).
- `BookFootnoteRef` — ссылка на сноску (`id`, `label`).
- `BookSuperscript` / `BookSubscript` — верхний / нижний индекс.

---

## Политики именования ресурсов (`BookResourceNamingPolicy`)

Используются при сборке книги или сохранении ресурсов:

- `BookResourceNamingPolicy.preserve` — оставляет исходное имя файла из URL (`chapter1_pic.png`).
- `BookResourceNamingPolicy.sequential` — генерирует порядковые имена (`img_001.png`, `img_002.jpg`).
- `BookResourceNamingPolicy.hash` — генерирует имя по хэшу адреса (`img_a3f89b1c.png`).
- `BookResourceNamingPolicy.custom(...)` — пользовательская функция генерации имени.

---

## Опции и обработка ошибок

### `BookDecodingOptions`
```dart
const options = BookDecodingOptions(
  strictMode: true,            // Выбрасывать ошибки при некорректной разметке
  logger: (warn) => print(warn), // Callback для логов/предупреждений
);
```

### `BookEncodingOptions`
```dart
const options = BookEncodingOptions(
  documentId: 'DOC-12345',                           // ID документа
  programUsed: 'My App 1.0',                         // Название программы-генератора
  entryFilename: 'book.fb2',                         // Имя файла внутри zip для FB2.zip
  namingPolicy: BookResourceNamingPolicy.sequential, // Политика именования ресурсов
  pretty: true,                                      // Форматировать ли XML с отступами
);
```

### Исключения
Все исключения наследуются от `BookException`:
- `BookFormatException` — ошибка формата или повреждённый архив.
- `BookParseException` — ошибка разбора разметки (содержит поля `tag` и `line`).
- `BookMalformedMetadataException` — отсутствуют обязательные метаданные.
- `EpubEncryptedResourceException` — обнаружены зашифрованные DRM-ресурсы в EPUB.
- `EpubInvalidPackageException` — нарушение структуры OCF/OPF пакета.

---

## Запуск примера

```bash
dart run example/dart_book_example.dart
```

---

## Лицензия

MIT
