# Спецификации и соответствие стандартам (dart_book)

В данном документе приведена детальная матрица соответствия библиотеки `dart_book` официальным спецификациям электронных книг **IDPF / W3C EPUB** и **FictionBook (FB2)**.

Легенда статусов:
- ✅ — **полная поддержка** (декодирование, сериализация, сохранение в AST);
- ⚠️ — **частичная поддержка** (с техническими оговорками или ограничениями);
- ❌ — **не поддерживается** (игнорируется, отбрасывается или не реализовано);
- — — **неприменимо**.

---

## 1. Спецификации EPUB

### EPUB 2.0.1 (базовый набор)

| Функция спецификации EPUB 2.0.1 | Статус | Детали реализации в dart_book |
| --- | :---: | --- |
| OCF-контейнер (ZIP, `mimetype`, `META-INF/container.xml`) | ✅ | `mimetype` несжатый 1-й файл (offset 30/38); автодетект формата по ZIP-сигнатуре |
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

### EPUB 3.0–3.2 (новшества относительно 2.0.1)

| Функция спецификации EPUB 3.0–3.2 | Статус | Детали реализации в dart_book |
| --- | :---: | --- |
| NAV XHTML + NCX (Dual Navigation) | ✅ | Поиск по `properties="nav"`, разбор `toc` и `landmarks`. Энкодер пишет `nav.xhtml` и `toc.ncx` |
| `epub:type` структурная семантика | ✅ | Сноски (`epub:type="noteref"`, `role="doc-noteref"`), типы NAV (`toc`, `landmarks`) |
| HTML5 XHTML-контент | ✅ | Семантические теги HTML5 (`section`, `article`, `figure`, `code`, `table` и др.) |
| MathML (`<math>`) | ✅ | Сохраняется в `BookMathBlock` с исходным MathML XML |
| SVG-контент (`<svg>`) | ✅ | Сохраняется в `BookSvgBlock`, внешние `.svg` извлекаются в ресурсы |
| Медиа `<audio>`/`<video>`/`<source>` | ✅ | Блоки и бинарные медиафайлы извлекаются декодером из манифеста и сохраняются энкодером |
| Обложка (`properties="cover-image"`) | ✅ | Полная поддержка: извлечение в `BookCover` декодером и запись энкодером |
| Media Overlays (SMIL 3.0) | ⚠️ | Парсер `EpubSmilDocument` с полной поддержкой разбора таймкодов (`hh:mm:ss`, `mm:ss`, `ms`, `min`, `h`) и синхронизации аудио/текста |
| Fixed layout (`rendition:layout="pre-paginated"`) | ✅ | Поддержка `BookLayout.fixedLayout` в `BookMetadata` и OPF-метаданных |
| Шрифты WOFF / WOFF2 | ✅ | WOFF и WOFF2 извлекаются декодером и сохраняются энкодером |
| Обфускация шрифтов (IDPF / Adobe) | ✅ | Автоматическая деобфускация шрифтов IDPF (SHA-1) и Adobe (UUID XOR) |
| Скриптинг (`<script>`, JS) | ❌ | JS не исполняется; теги переводятся в `BookRawHtmlBlock` |
| Метаданные OPF (`properties`, `refines`, `link`) | ✅ | Чтение и запись `belongs-to-collection`, `source-language`, `dcterms:modified` |
| Коллекции и серии (`<collection>`) | ✅ | Чтение и генерация `<meta property="belongs-to-collection">`, `collection-type`, `group-position` |
| Core Media Types EPUB 3 | ✅ | Растровые изображения, SVG, шрифты (WOFF/WOFF2/TTF/OTF), аудио/видео (MP3, MP4, WebP) |

---

### EPUB 3.3 (W3C Recommendation)

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

### EPUB 3.4 (W3C Working Group Draft / CR)

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

## 2. Спецификации FictionBook (FB2)

### FB2 2.0 (базовый набор)

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
| `<cite>`, `<text-author>` | ✅ | Цитаты и авторство цитаты (включая множественных авторов) |
| `<table>` (`tr`, `th`, `td`) | ✅ | Таблицы с поддержкой `colspan`, `rowspan`, `align` и `valign` |
| Инлайн: `strong`, `emphasis`, `a`, `image` | ✅ | Полужирный, курсив, ссылки/сноски, строчные картинки с `id`/`alt`/`title` |
| Инлайн: `<style name="...">` | ✅ | Пользовательские стили текста сохраняются в `BookNamedStyle` |
| `<binary id="..." content-type="...">` | ✅ | Base64 кодирование и декодирование встроенных ресурсов |
| Кодировки (UTF-8, Windows-1251) | ✅ | Полная 256-байтная таблица Windows-1251 (тире `—`, кавычки `«»`, `№`, `…` и спецсимволы) |
| Контейнер FB2.ZIP | ✅ | Чтение и запись `.fb2.zip` архивов |

---

### FB2 2.1 (новшества относительно 2.0)

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

### FB2 2.2 (новшества относительно 2.1)

| Функция спецификации FB2 2.2 | Статус | Детали реализации в dart_book |
| --- | :---: | --- |
| `<stylesheet type="...">` | ❌ | Кастомные таблицы стилей игнорируются |
| `<custom-info info-type="...">` | ⚠️ | Поддерживается только `info-type="sequence-url"` |
| Множественные `<body>` | ⚠️ | `notes` парсится в `content.footnotes`. Прочие именованные тела объединяются в `blocks` |
| Список жанров FB2 2.2 | ⚠️ | Прозрачный passthrough строковых кодов |
| Атрибут `<genre match="...">` | ❌ | Атрибут процента соответствия `match` игнорируется |
| Атрибуты `xml:lang` на узлах | ❌ | Читается только глобальный `<lang>` книги |
| Кастомные инлайн-стили `<style name="...">` | ✅ | Полная поддержка через `BookNamedStyle` (чтение и запись) |
