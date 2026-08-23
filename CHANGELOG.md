## 0.2.0

### Added
- **EPUB Navigation & Cover**: Native generation of dedicated `cover.xhtml`, `titlepage.xhtml` (with authors, series, and annotation), and in-flow Table of Contents (`nav.xhtml`) in `<spine>` for seamless e-reader rendering.
- **Visible Chapter Headings**: Automatic heading (`<h2>`) injection for chapters in EPUB without duplicating existing headings.
- **Unicode Line Separator Support**: Full support for `\u2028` (LS), `\u2029` (PS), `\u0085` (NEL), `\r`, and `\n` in `HtmlParser`.

### Changed & Fixed
- **HTML Paragraph Parsing**: Smart paragraph splitting on `<br>` and newlines inside `<p>` and nested inline tags (`<em>`, `<strong>`, `<span>`), preserving styling across split paragraphs.
- **Whitespace Handling**: Fixed premature whitespace trimming in HTML parser that caused adjacent dialogue and chat lines to merge.
- **EPUB Decoding**: Skip synthetic cover, title, and nav pages during decoding to preserve AST idempotence.

## 0.1.0

- Initial release.
