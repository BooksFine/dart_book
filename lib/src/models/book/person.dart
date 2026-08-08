// ignore_for_file: annotate_overrides

import 'package:freezed_annotation/freezed_annotation.dart';

part '.gen/person.freezed.dart';

/// Участник создания книги (автор, переводчик, редактор и т.д.).
@freezed
class BookContributor with _$BookContributor {
  /// Роль участника.
  final BookContributorRole role;

  /// Имя участника.
  final PersonName name;

  /// Ссылка на личную страницу / сайт.
  final Uri? homePage;

  /// Электронная почта.
  final String? email;

  const BookContributor({
    required this.role,
    required this.name,
    this.homePage,
    this.email,
  });
}

/// Роль участника создания книги.
enum BookContributorRole {
  /// Автор текста.
  author,

  /// Переводчик.
  translator,

  /// Редактор.
  editor,

  /// Иллюстратор.
  illustrator,

  /// Чтец (для аудиокниг).
  narrator,

  /// Составитель (для сборников).
  compiler,

  /// Иная роль.
  other,
}

/// Структурированное имя человека.
@freezed
class PersonName with _$PersonName {
  /// Имя (first name).
  final String? first;

  /// Отчество или второе имя (middle name).
  final String? middle;

  /// Фамилия (last name).
  final String? last;

  /// Псевдоним.
  final String? nickname;

  /// Явно заданное отображаемое имя (приоритетнее остальных полей).
  final String? display;

  const PersonName({
    this.first,
    this.middle,
    this.last,
    this.nickname,
    this.display,
  });

  String toDisplayString() {
    if (display != null && display!.trim().isNotEmpty) {
      return display!.trim();
    }

    final parts = <String>[];
    if (first != null && first!.trim().isNotEmpty) parts.add(first!.trim());
    if (middle != null && middle!.trim().isNotEmpty) parts.add(middle!.trim());
    if (last != null && last!.trim().isNotEmpty) parts.add(last!.trim());

    if (parts.isNotEmpty) {
      return parts.join(' ');
    }

    if (nickname != null && nickname!.trim().isNotEmpty) {
      return nickname!.trim();
    }

    return '';
  }
}
