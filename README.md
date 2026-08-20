# dart_book

Dart-библиотека для чтения, создания и конвертации электронных книг в форматах **EPUB** (EPUB 2 / 3) и **FB2** (FB2 2.0–2.2, FB2.zip).

В основе библиотеки лежит единая модель данных (`Book`), которая представляет книгу в виде дерева блоков и инлайновых элементов (AST), независимо от исходного формата.

---

## 📖 Поддержка форматов по версиям спецификаций

Легенда статусов:
- ✅ — **полная поддержка** (декодирование, сериализация, сохранение в AST);
- ⚠️ — **частичная поддержка** (с техническими оговорками или ограничениями);
- ❌ — **не поддерживается** (игнорируется, отбрасывается или не реализовано);
- — — **неприменимо**.

---

#### EPUB 2.0.1 (базовый набор)

| Функция спецификации EPUB 2.0.1 | Статус | Детали реализации в dart_book |
| --- | :---: | --- |
| OCF-контейнер (ZIP, `mimetype`, `META-INF/container.xml`) | ✅ | `mimetype` несжатый 1-й файл; автодетект формата по ZIP-сигнатуре |
| OPF-пакет: метаданные (`dc:title`, `dc:identifier`, `dc:language`, `dc:creator`, `dc:publisher`, `dc:date`) | ✅ | Чтение DC метаданных, издательства (`publishInfo.publisher`), ISBN, даты; энкодер пишет пакет 3.0 |
| OPF-пакет: `manifest` и `spine` | ⚠️ | Базовая структура; атрибут `fallback` и `linear="no"` игнорируются |
| Обложка EPUB 2 (`<meta name="cover">`) | ✅ | Извлекается декодером в `metadata.cover`; энкодер проставляет `properties="cover-image"` |
| Элемент `<guide>` | ❌ | Игнорируется декодером, не генерируется энкодером |
| Навигация NCX (`toc.ncx`) | ✅ | Полная поддержка: декодер читает NCX, энкодер генерирует `toc.ncx` (dual navigation) |
| XHTML 1.1 контент | ✅ | Полная поддержка тегов текста, заголовков, списков, цитат, стихов и таблиц |
| DTBook контент (`application/x-dtbook+xml`) | ❌ | Не поддерживается |
| CSS-стили | ⚠️ | Сохраняются как ресурс `BookResource`, селекторы к AST не применяются |
| Встроенные шрифты (TTF/OTF) | ✅ | Извлечение и сохранение шрифтов, включая деобфускацию IDPF / Adobe |
| Изображения (GIF/JPEG/PNG/SVG) | ✅ | Полная поддержка блочных/инлайн картинок и векторного SVG |
| Детекция DRM (`META-INF/encryption.xml`) | ✅ | Автоматическая деобфускация шрифтов; ошибка выбрасывается только на реальный DRM |

---

#### EPUB 3.0–3.2 (новшества относительно 2.0.1)

| Функция спецификации EPUB 3.0–3.2 | Статус | Детали реализации в dart_book |
| --- | :---: | --- |
| NAV XHTML + NCX (Dual Navigation) | ✅ | Поиск по `properties="nav"`, разбор `toc` и `landmarks`. Энкодер пишет `nav.xhtml` и `toc.ncx` |
| `epub:type` структурная семантика | ✅ | Сноски (`epub:type="noteref"`, `role="doc-noteref"`), типы NAV (`toc`, `landmarks`) |
| HTML5 XHTML-контент | ✅ | Семантические теги HTML5 (`section`, `article`, `figure`, `code`, `table` и др.) |
| MathML (`<math>`) | ✅ | Сохраняется в `BookMathBlock` с исходным MathML XML |
| SVG-контент (`<svg>`) | ✅ | Сохраняется в `BookSvgBlock`, внешние `.svg` извлекаются в ресурсы |
| Медиа `<audio>`/`<video>`/`<source>` | ✅ | Блоки и бинарные медиафайлы извлекаются декодером из манифеста и сохраняются энкодером |
| Обложка (`properties="cover-image"`) | ✅ | Полная поддержка: извлечение в `BookCover` декодером и запись энкодером |
| Media Overlays (SMIL 3.0) | ❌ | Парсер `EpubSmilDocument` реализован, но не подключен к декодеру/энкодеру |
| Fixed layout (`rendition:layout="pre-paginated"`) | ✅ | Поддержка `BookLayout.fixedLayout` в `BookMetadata` и OPF-метаданных |
| Шрифты WOFF / WOFF2 | ✅ | WOFF и WOFF2 извлекаются декодером и сохраняются энкодером |
| Обфускация шрифтов (IDPF / Adobe) | ✅ | Автоматическая деобфускация шрифтов IDPF (SHA-1) и Adobe (UUID XOR) |
| Скриптинг (`<script>`, JS) | ❌ | JS не исполняется; теги переводятся в `BookRawHtmlBlock` |
| Метаданные OPF (`properties`, `refines`, `link`) | ✅ | Чтение и запись `belongs-to-collection`, `source-language`, `dcterms:modified` |
| Коллекции и серии (`<collection>`) | ✅ | Чтение и генерация `<meta property="belongs-to-collection">`, `collection-type`, `group-position` |
| Core Media Types EPUB 3 | ✅ | Растровые изображения, SVG, шрифты (WOFF/WOFF2/TTF/OTF), аудио/видео (MP3, MP4, WebP) |

---

#### EPUB 3.3 (W3C Recommendation)

| Функция спецификации EPUB 3.3 | Статус | Детали реализации в dart_book |
| --- | :---: | --- |
| Статус W3C Recommendation (OCF и OPF) | ✅ | Несжатый `mimetype`, `container.xml`, `version="3.0"`, `dcterms:modified` |
| Новые Core Media Types (WebP) | ✅ | Полная поддержка `image/webp` при чтении и записи |
| Core Media Types (Аудио: MP3, AAC, OPUS) | ✅ | Блоки `<audio>` и бинарные аудиоресурсы извлекаются и упаковываются |
| `epub:type` на элементах SVG | ⚠️ | SVG сохраняется транзитом в `BookSvgBlock` без семантического анализа |
| Multiple Renditions 1.1 | ⚠️ | `OcfContainer` читает список `<rootfile>`, но открывает только первый |
| EPUB Accessibility 1.1 (a11y метаданные) | ❌ | Метаданные доступности Schema.org и сертификация отсутствуют в модели |
| EPUB-CFI 1.1 (Канонические фрагменты) | ❌ | Синтаксис `epubcfi(...)` не реализован |
| TTS-расширения (SSML, PLS, CSS Speech) | ❌ | Атрибуты `ssml:ph` и PLS-словари не извлекаются |
| Рекомендации по Security & Privacy | — | Неприменимо (пассивный headless-парсер без исполнения кода) |

---

#### EPUB 3.4 (W3C Working Group Draft / CR)

| Функция спецификации EPUB 3.4 | Статус | Детали реализации в dart_book |
| --- | :---: | --- |
| Roll layout (вебтуны / вертикальный скролл) | ✅ | Поддержка `BookLayout.roll` в `BookMetadata` и `rendition:layout="roll"` |
| EPUB Annotations 1.0 (JSON-LD) | ❌ | Модель аннотаций W3C Web Annotation отсутствует |
| Свойство `pageBreakSource` (замена `source-of`) | ❌ | Не парсится и не генерируется |
| ITS 2.0 (i18n) атрибуты (`translate`, `dir`) | ⚠️ | Проходят транзитом только в raw-узлах `BookRawHtmlBlock` |
| Новые Core Media Types (AVIF, JPEG XL) | ✅ | Извлекаются в `BookResource`; поддержан маппинг расширений `.avif` и `.jxl` |
| OPUS в MP4 (`audio/mp4; codecs=opus`) | ✅ | Бинарные аудио-файлы извлекаются и сериализуются |
| Удаление устаревших свойств (`flow`/`orientation`) | — / ✅ | Энкодер не производит устаревшие rendition-свойства |
| EPUB Accessibility 1.2 обновления | ❌ | Новые метаданные доступности не поддерживаются |

---

#### FB2 2.0 (базовый набор)

| Функция спецификации FB2 2.0 | Статус | Детали реализации в dart_book |
| --- | :---: | --- |
| XML Namespaces (`fictionbook/2.0`, `xlink`) | ⚠️ | Энкодер генерирует `xmlns:l`, парсер проверяет `l:href` и `href` |
| `<title-info>`: `book-title`, `lang`, `annotation`, `keywords` | ✅ | Полная поддержка чтения, сериализации и сохранения в AST |
| `<title-info>`: `genre` | ✅ | Извлекаются все жанры в `BookGenre(code, name)` |
| `<title-info>`: `author` | ✅ | ФИО, псевдоним, `home-page` и `email` читаются декодером и пишутся энкодером |
| `<title-info>`: `date` | ✅ | Чтение и запись дат в `publishedAt` / `updatedAt` |
| `<title-info>`: `coverpage` | ✅ | Извлекается `<image l:href="#id"/>`, связывается с `BookCover` |
| `<title-info>`: `sequence` | ✅ | Полная поддержка списка серий книги (`List<BookSeries> series`) |
| `<title-info>`: `translator` | ✅ | Чтение и запись переводчиков в `BookContributor(role: translator)` |
| `<title-info>`: `src-lang` | ✅ | Извлечение и запись языка оригинала книги (`metadata.srcLang`) |
| `<document-info>` | ⚠️ | Читается `id` и `date`; энкодер пишет `id`, `version`, `date`, `program-used`, `src-url` |
| `<publish-info>` | ✅ | Полная поддержка издательства, города, года и ISBN (`metadata.publishInfo`) |
| `<custom-info>` | ⚠️ | Поддерживается только `info-type="sequence-url"` |
| `<body>` (основное и сноски) | ✅ | Основное тело — в `content.blocks`, `<body name="notes">` — в `content.footnotes` |
| `<section>`, `<title>`, `<subtitle>`, `<p>`, `<empty-line>` | ✅ | Иерархические разделы, подзаголовки, абзацы, пустые строки |
| `<image>` (блочный) | ✅ | Ссылка `#id`, атрибуты `alt`, `title`, `id` в `BookImageBlock` |
| `<poem>`, `<stanza>`, `<v>` | ✅ | Структура стихотворений (строфы, строки) |
| `<epigraph>` | ✅ | Чтение и сериализация эпиграфов (`<epigraph>`) и цитат (`<cite>`) |
| `<cite>`, `<text-author>` | ✅ | Цитаты и авторство цитаты |
| `<table>` (`tr`, `th`, `td`) | ✅ | Таблицы с поддержкой `colspan`, `rowspan`, `align` и `valign` |
| Инлайн: `strong`, `emphasis`, `a`, `image` | ✅ | Полужирный, курсив, ссылки/сноски, строчные картинки с `id`/`alt`/`title` |
| Инлайн: `<style name="...">` | ✅ | Пользовательские стили текста сохраняются в `BookNamedStyle` |
| `<binary id="..." content-type="...">` | ✅ | Base64 кодирование и декодирование встроенных ресурсов |
| Кодировки (UTF-8, Windows-1251) | ✅ | Полная 256-байтная таблица Windows-1251 (тире `—`, кавычки `«»`, `№`, `…` и спецсимволы) |
| Контейнер FB2.ZIP | ✅ | Чтение и запись `.fb2.zip` архивов |

---

#### FB2 2.1 (новшества относительно 2.0)

| Функция спецификации FB2 2.1 | Статус | Детали реализации в dart_book |
| --- | :---: | --- |
| `<src-title-info>` (переводные книги) | ✅ | Полная поддержка метаданных оригинала: название, язык, авторы (`srcTitleInfo`) |
| Инлайн `sub`, `sup`, `code`, `strikethrough` | ✅ | Полная поддержка декодирования и сериализации (`<code>`, `<sub>`, `<sup>`, `<strikethrough>`) |
| `<text-author>` как `styleType` | ⚠️ | Инлайн-стили в цитатах/эпиграфах ✅; в `<poem>` автор игнорируется |
| `<output>` (инструкции дистрибуции) | ❌ | Не поддерживается |
| Список жанров FB2 2.1 | ⚠️ | Прозрачный passthrough строковых кодов без словаря и валидации |
| Таблицы: `colspan`, `rowspan` | ✅ | Полная поддержка объединения столбцов и строк в таблицах |
| Таблицы: `align`, `valign` | ✅ | Полная поддержка выравнивания ячеек в `BookTableCell` |
| Атрибуты `id`, `title`, `alt` у `<image>` | ✅ | Полная поддержка в `BookImageBlock` и `BookImageInline` |

---

#### FB2 2.2 (новшества относительно 2.1)

| Функция спецификации FB2 2.2 | Статус | Детали реализации в dart_book |
| --- | :---: | --- |
| `<stylesheet type="...">` | ❌ | Кастомные таблицы стилей игнорируются |
| `<custom-info info-type="...">` | ⚠️ | Поддерживается только `info-type="sequence-url"` |
| Множественные `<body>` | ⚠️ | `notes` парсится в `content.footnotes`. Прочие именованные тела объединяются в `blocks` |
| Список жанров FB2 2.2 | ⚠️ | Прозрачный passthrough строковых кодов |
| Атрибут `<genre match="...">` | ❌ | Атрибут процента соответствия `match` игнорируется |
| Атрибуты `xml:lang` на узлах | ❌ | Читается только глобальный `<lang>` книги |
| Кастомные инлайн-стили `<style name="...">` | ✅ | Полная поддержка через `BookNamedStyle` (чтение и запись) |

---

## 🌳 Единая модель данных (AST)

- **`Book`**: Корневой объект книги (`metadata`, `content`, `resources`).
- **`BookMetadata`**: Название, язык, авторы (`BookContributor`), переводчики, жанры (`BookGenre`), список серий (`series: List<BookSeries>`), сведения об издании (`publishInfo: BookPublishInfo`), язык и сведения об оригинале (`srcLang`, `srcTitleInfo`), режим верстки (`layout: BookLayout`), аннотация (`BookContent`), обложка (`BookCover`), даты обновления/публикации.
- **`BookBlock`**:
  - `BookSection` — раздел / глава (`title`, `blocks`, `children`).
  - `BookHeading` — заголовок (`level` от 1 до 6, `text`).
  - `BookParagraph` — абзац (`inlines`).
  - `BookQuote` — цитата / эпиграф (`blocks`, `citation`).
  - `BookList` — список (`ordered`, `items`).
  - `BookTable` — таблица (`rows` -> `cells` с поддержкой `colSpan`, `rowSpan`, `align`, `vAlign`).
  - `BookPoem` — стихотворение (`stanzas` -> `lines`).
  - `BookCodeBlock` — блок кода (`code`, `language`).
  - `BookImageBlock` — блочная иллюстрация (`id`, `ref`, `alt`, `title`).
  - `BookAudioBlock` / `BookVideoBlock` — медиа (`ref`, `controls`).
  - `BookMathBlock` — блок MathML (`mathml`).
  - `BookSvgBlock` — векторный SVG блок (`svg`).
  - `BookHorizontalRule` / `BookEmptyLine` — разделители.
  - `BookRawHtmlBlock` / `BookRawXmlBlock` — сырые блоки для сохранения нераспознанной разметки.
- **`BookInline`**:
  - `BookText` — текст.
  - `BookEmphasis` / `BookStrong` / `BookStrike` — курсив, полужирный, зачёркнутый.
  - `BookCodeSpan` — строчный код.
  - `BookNamedStyle` — именованный пользовательский стиль (`name`, `inlines`).
  - `BookLink` — ссылка (`href`, `children`).
  - `BookAnchor` — якорь внутри книги (`id`).
  - `BookImageInline` — строчная картинка (`id`, `ref`, `alt`, `title`).
  - `BookFootnoteRef` — ссылка на сноску (`id`, `label`).
  - `BookSuperscript` / `BookSubscript` — верхний / нижний индекс.
  - `BookLineBreak` — перенос строки (`<br/>`).
- **`BookResource`**: Бинарные данные (изображения, шрифты, стили, аудио) с MIME-типами и идентификаторами.

---

## 🛠 Основной API

### `DartBook`
Главная точка входа для загрузки и кодирования:
- `DartBook.load(bytes, {filename, options, resourceResolver})` — асинхронный разбор книги с автоопределением формата.
- `DartBook.loadIsolated(bytes, {filename, options, resourceResolver})` — разбор книги в отдельном изоляте (`Isolate.run`).
- `DartBook.encodeIsolated(book, extension, {options})` — кодирование книги в изоляте.

### Конвертеры
- `EpubConverter` (`EpubDecoder` / `EpubEncoder`):
  - `EpubConverter.bookToEpub(book)`
  - `EpubConverter.epubToBook(bytes, {options})`
- `Fb2Converter` (`Fb2Decoder` / `Fb2Encoder`):
  - `Fb2Converter.bookToFb2(book, {isZip = false, resourceResolver})`
  - `Fb2Converter.bookToFb2Zip(book, {resourceResolver})`
  - `Fb2Converter.fb2ToBook(bytes, {options})`
- `BookRegistry` — реестр декодеров и энкодеров (`findDecoder`, `findEncoder`, `registerDecoder`, `registerEncoder`).

---

## Опции и обработка ошибок

### `BookDecodingOptions`
```dart
const options = BookDecodingOptions(
  strictMode: true,              // Выбрасывать ошибки при нераспознанных элементах
  logger: (warn) => print(warn), // Callback для логов и предупреждений
);
```

### `BookEncodingOptions`
```dart
const options = BookEncodingOptions(
  documentId: 'DOC-12345',                           // ID документа
  programUsed: 'My App 1.0',                         // Название программы-генератора
  entryFilename: 'book.fb2',                         // Имя файла внутри архива для FB2.zip
  namingPolicy: BookResourceNamingPolicy.sequential, // Политика именования ресурсов
  pretty: true,                                      // Форматировать XML с отступами
  compressZip: true,                                 // Сжимать ли ZIP-архив
);
```

### Иерархия исключений
- `BookException` — базовое исключение библиотеки.
  - `BookFormatException` — поврежденный файл или неверная сигнатура.
  - `BookParseException` — ошибка синтаксического анализа разметки (содержит `tag` и `line`).
  - `BookMalformedMetadataException` — отсутствуют обязательные метаданные в strict-режиме.
  - `EpubException` — базовое исключение формата EPUB (наследует `BookException`).
    - `EpubEncryptedResourceException` — обнаружены зашифрованные ресурсы / DRM.
    - `EpubInvalidPackageException` — нарушение структуры OCF/OPF пакета.

---

## Запуск тестов и примеров

```bash
# Анализ кодовой базы
dart analyze

# Запуск тестов
dart test

# Запуск примера
dart run example/dart_book_example.dart
```

---

## Лицензия

MIT
