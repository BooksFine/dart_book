// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookMetadata {

 String get id; String get title; String get language; bool get isFinished; int? get textLength; List<BookContributor> get contributors; List<BookGenre> get genres; List<String> get keywords; BookContent? get annotation; List<BookSeries> get series; BookCover? get cover; Uri? get source; BookPublishInfo? get publishInfo; String? get srcLang; BookSourceTitleInfo? get srcTitleInfo; BookLayout get layout; DateTime? get updatedAt; DateTime? get publishedAt;
/// Create a copy of BookMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookMetadataCopyWith<BookMetadata> get copyWith => _$BookMetadataCopyWithImpl<BookMetadata>(this as BookMetadata, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookMetadata&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.language, language) || other.language == language)&&(identical(other.isFinished, isFinished) || other.isFinished == isFinished)&&(identical(other.textLength, textLength) || other.textLength == textLength)&&const DeepCollectionEquality().equals(other.contributors, contributors)&&const DeepCollectionEquality().equals(other.genres, genres)&&const DeepCollectionEquality().equals(other.keywords, keywords)&&(identical(other.annotation, annotation) || other.annotation == annotation)&&const DeepCollectionEquality().equals(other.series, series)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.source, source) || other.source == source)&&(identical(other.publishInfo, publishInfo) || other.publishInfo == publishInfo)&&(identical(other.srcLang, srcLang) || other.srcLang == srcLang)&&(identical(other.srcTitleInfo, srcTitleInfo) || other.srcTitleInfo == srcTitleInfo)&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,language,isFinished,textLength,const DeepCollectionEquality().hash(contributors),const DeepCollectionEquality().hash(genres),const DeepCollectionEquality().hash(keywords),annotation,const DeepCollectionEquality().hash(series),cover,source,publishInfo,srcLang,srcTitleInfo,layout,updatedAt,publishedAt);

@override
String toString() {
  return 'BookMetadata(id: $id, title: $title, language: $language, isFinished: $isFinished, textLength: $textLength, contributors: $contributors, genres: $genres, keywords: $keywords, annotation: $annotation, series: $series, cover: $cover, source: $source, publishInfo: $publishInfo, srcLang: $srcLang, srcTitleInfo: $srcTitleInfo, layout: $layout, updatedAt: $updatedAt, publishedAt: $publishedAt)';
}


}

/// @nodoc
abstract mixin class $BookMetadataCopyWith<$Res>  {
  factory $BookMetadataCopyWith(BookMetadata value, $Res Function(BookMetadata) _then) = _$BookMetadataCopyWithImpl;
@useResult
$Res call({
 String id, String title, String language, bool isFinished, int? textLength, List<BookContributor> contributors, List<BookGenre> genres, List<String> keywords, BookContent? annotation, List<BookSeries> series, BookCover? cover, Uri? source, BookPublishInfo? publishInfo, String? srcLang, BookSourceTitleInfo? srcTitleInfo, BookLayout layout, DateTime? updatedAt, DateTime? publishedAt
});




}
/// @nodoc
class _$BookMetadataCopyWithImpl<$Res>
    implements $BookMetadataCopyWith<$Res> {
  _$BookMetadataCopyWithImpl(this._self, this._then);

  final BookMetadata _self;
  final $Res Function(BookMetadata) _then;

/// Create a copy of BookMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? language = null,Object? isFinished = null,Object? textLength = freezed,Object? contributors = null,Object? genres = null,Object? keywords = null,Object? annotation = freezed,Object? series = null,Object? cover = freezed,Object? source = freezed,Object? publishInfo = freezed,Object? srcLang = freezed,Object? srcTitleInfo = freezed,Object? layout = null,Object? updatedAt = freezed,Object? publishedAt = freezed,}) {
  return _then(BookMetadata(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,isFinished: null == isFinished ? _self.isFinished : isFinished // ignore: cast_nullable_to_non_nullable
as bool,textLength: freezed == textLength ? _self.textLength : textLength // ignore: cast_nullable_to_non_nullable
as int?,contributors: null == contributors ? _self.contributors : contributors // ignore: cast_nullable_to_non_nullable
as List<BookContributor>,genres: null == genres ? _self.genres : genres // ignore: cast_nullable_to_non_nullable
as List<BookGenre>,keywords: null == keywords ? _self.keywords : keywords // ignore: cast_nullable_to_non_nullable
as List<String>,annotation: freezed == annotation ? _self.annotation : annotation // ignore: cast_nullable_to_non_nullable
as BookContent?,series: null == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as List<BookSeries>,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as BookCover?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as Uri?,publishInfo: freezed == publishInfo ? _self.publishInfo : publishInfo // ignore: cast_nullable_to_non_nullable
as BookPublishInfo?,srcLang: freezed == srcLang ? _self.srcLang : srcLang // ignore: cast_nullable_to_non_nullable
as String?,srcTitleInfo: freezed == srcTitleInfo ? _self.srcTitleInfo : srcTitleInfo // ignore: cast_nullable_to_non_nullable
as BookSourceTitleInfo?,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as BookLayout,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}



/// @nodoc
mixin _$BookPublishInfo {

 String? get publisher; String? get city; int? get year; String? get isbn;
/// Create a copy of BookPublishInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookPublishInfoCopyWith<BookPublishInfo> get copyWith => _$BookPublishInfoCopyWithImpl<BookPublishInfo>(this as BookPublishInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookPublishInfo&&(identical(other.publisher, publisher) || other.publisher == publisher)&&(identical(other.city, city) || other.city == city)&&(identical(other.year, year) || other.year == year)&&(identical(other.isbn, isbn) || other.isbn == isbn));
}


@override
int get hashCode => Object.hash(runtimeType,publisher,city,year,isbn);

@override
String toString() {
  return 'BookPublishInfo(publisher: $publisher, city: $city, year: $year, isbn: $isbn)';
}


}

/// @nodoc
abstract mixin class $BookPublishInfoCopyWith<$Res>  {
  factory $BookPublishInfoCopyWith(BookPublishInfo value, $Res Function(BookPublishInfo) _then) = _$BookPublishInfoCopyWithImpl;
@useResult
$Res call({
 String? publisher, String? city, int? year, String? isbn
});




}
/// @nodoc
class _$BookPublishInfoCopyWithImpl<$Res>
    implements $BookPublishInfoCopyWith<$Res> {
  _$BookPublishInfoCopyWithImpl(this._self, this._then);

  final BookPublishInfo _self;
  final $Res Function(BookPublishInfo) _then;

/// Create a copy of BookPublishInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? publisher = freezed,Object? city = freezed,Object? year = freezed,Object? isbn = freezed,}) {
  return _then(BookPublishInfo(
publisher: freezed == publisher ? _self.publisher : publisher // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,isbn: freezed == isbn ? _self.isbn : isbn // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
mixin _$BookSourceTitleInfo {

 String? get title; String? get language; List<BookContributor> get authors;
/// Create a copy of BookSourceTitleInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSourceTitleInfoCopyWith<BookSourceTitleInfo> get copyWith => _$BookSourceTitleInfoCopyWithImpl<BookSourceTitleInfo>(this as BookSourceTitleInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSourceTitleInfo&&(identical(other.title, title) || other.title == title)&&(identical(other.language, language) || other.language == language)&&const DeepCollectionEquality().equals(other.authors, authors));
}


@override
int get hashCode => Object.hash(runtimeType,title,language,const DeepCollectionEquality().hash(authors));

@override
String toString() {
  return 'BookSourceTitleInfo(title: $title, language: $language, authors: $authors)';
}


}

/// @nodoc
abstract mixin class $BookSourceTitleInfoCopyWith<$Res>  {
  factory $BookSourceTitleInfoCopyWith(BookSourceTitleInfo value, $Res Function(BookSourceTitleInfo) _then) = _$BookSourceTitleInfoCopyWithImpl;
@useResult
$Res call({
 String? title, String? language, List<BookContributor> authors
});




}
/// @nodoc
class _$BookSourceTitleInfoCopyWithImpl<$Res>
    implements $BookSourceTitleInfoCopyWith<$Res> {
  _$BookSourceTitleInfoCopyWithImpl(this._self, this._then);

  final BookSourceTitleInfo _self;
  final $Res Function(BookSourceTitleInfo) _then;

/// Create a copy of BookSourceTitleInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = freezed,Object? language = freezed,Object? authors = null,}) {
  return _then(BookSourceTitleInfo(
title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,authors: null == authors ? _self.authors : authors // ignore: cast_nullable_to_non_nullable
as List<BookContributor>,
  ));
}

}



/// @nodoc
mixin _$BookGenre {

 String get code; String? get name;
/// Create a copy of BookGenre
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookGenreCopyWith<BookGenre> get copyWith => _$BookGenreCopyWithImpl<BookGenre>(this as BookGenre, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookGenre&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,code,name);

@override
String toString() {
  return 'BookGenre(code: $code, name: $name)';
}


}

/// @nodoc
abstract mixin class $BookGenreCopyWith<$Res>  {
  factory $BookGenreCopyWith(BookGenre value, $Res Function(BookGenre) _then) = _$BookGenreCopyWithImpl;
@useResult
$Res call({
 String code, String? name
});




}
/// @nodoc
class _$BookGenreCopyWithImpl<$Res>
    implements $BookGenreCopyWith<$Res> {
  _$BookGenreCopyWithImpl(this._self, this._then);

  final BookGenre _self;
  final $Res Function(BookGenre) _then;

/// Create a copy of BookGenre
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = freezed,}) {
  return _then(BookGenre(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
mixin _$BookSeries {

 String get name; int? get number; Uri? get url;
/// Create a copy of BookSeries
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSeriesCopyWith<BookSeries> get copyWith => _$BookSeriesCopyWithImpl<BookSeries>(this as BookSeries, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSeries&&(identical(other.name, name) || other.name == name)&&(identical(other.number, number) || other.number == number)&&(identical(other.url, url) || other.url == url));
}


@override
int get hashCode => Object.hash(runtimeType,name,number,url);

@override
String toString() {
  return 'BookSeries(name: $name, number: $number, url: $url)';
}


}

/// @nodoc
abstract mixin class $BookSeriesCopyWith<$Res>  {
  factory $BookSeriesCopyWith(BookSeries value, $Res Function(BookSeries) _then) = _$BookSeriesCopyWithImpl;
@useResult
$Res call({
 String name, int? number, Uri? url
});




}
/// @nodoc
class _$BookSeriesCopyWithImpl<$Res>
    implements $BookSeriesCopyWith<$Res> {
  _$BookSeriesCopyWithImpl(this._self, this._then);

  final BookSeries _self;
  final $Res Function(BookSeries) _then;

/// Create a copy of BookSeries
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? number = freezed,Object? url = freezed,}) {
  return _then(BookSeries(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as Uri?,
  ));
}

}



/// @nodoc
mixin _$BookCover {

 BookResourceRef get ref; String? get alt;
/// Create a copy of BookCover
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookCoverCopyWith<BookCover> get copyWith => _$BookCoverCopyWithImpl<BookCover>(this as BookCover, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookCover&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.alt, alt) || other.alt == alt));
}


@override
int get hashCode => Object.hash(runtimeType,ref,alt);

@override
String toString() {
  return 'BookCover(ref: $ref, alt: $alt)';
}


}

/// @nodoc
abstract mixin class $BookCoverCopyWith<$Res>  {
  factory $BookCoverCopyWith(BookCover value, $Res Function(BookCover) _then) = _$BookCoverCopyWithImpl;
@useResult
$Res call({
 BookResourceRef ref, String? alt
});




}
/// @nodoc
class _$BookCoverCopyWithImpl<$Res>
    implements $BookCoverCopyWith<$Res> {
  _$BookCoverCopyWithImpl(this._self, this._then);

  final BookCover _self;
  final $Res Function(BookCover) _then;

/// Create a copy of BookCover
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ref = null,Object? alt = freezed,}) {
  return _then(BookCover(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as BookResourceRef,alt: freezed == alt ? _self.alt : alt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



// dart format on
