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

 String get title; String get language; List<BookContributor> get contributors; List<BookGenre> get genres; List<String> get keywords; BookContent? get annotation; BookSeries? get series; BookCover? get cover; Uri? get source; DateTime? get updatedAt; DateTime? get publishedAt;
/// Create a copy of BookMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookMetadataCopyWith<BookMetadata> get copyWith => _$BookMetadataCopyWithImpl<BookMetadata>(this as BookMetadata, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookMetadata&&(identical(other.title, title) || other.title == title)&&(identical(other.language, language) || other.language == language)&&const DeepCollectionEquality().equals(other.contributors, contributors)&&const DeepCollectionEquality().equals(other.genres, genres)&&const DeepCollectionEquality().equals(other.keywords, keywords)&&(identical(other.annotation, annotation) || other.annotation == annotation)&&(identical(other.series, series) || other.series == series)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.source, source) || other.source == source)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt));
}


@override
int get hashCode => Object.hash(runtimeType,title,language,const DeepCollectionEquality().hash(contributors),const DeepCollectionEquality().hash(genres),const DeepCollectionEquality().hash(keywords),annotation,series,cover,source,updatedAt,publishedAt);

@override
String toString() {
  return 'BookMetadata(title: $title, language: $language, contributors: $contributors, genres: $genres, keywords: $keywords, annotation: $annotation, series: $series, cover: $cover, source: $source, updatedAt: $updatedAt, publishedAt: $publishedAt)';
}


}

/// @nodoc
abstract mixin class $BookMetadataCopyWith<$Res>  {
  factory $BookMetadataCopyWith(BookMetadata value, $Res Function(BookMetadata) _then) = _$BookMetadataCopyWithImpl;
@useResult
$Res call({
 String title, String language, List<BookContributor> contributors, List<BookGenre> genres, List<String> keywords, BookContent? annotation, BookSeries? series, BookCover? cover, Uri? source, DateTime? updatedAt, DateTime? publishedAt
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
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? language = null,Object? contributors = null,Object? genres = null,Object? keywords = null,Object? annotation = freezed,Object? series = freezed,Object? cover = freezed,Object? source = freezed,Object? updatedAt = freezed,Object? publishedAt = freezed,}) {
  return _then(BookMetadata(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,contributors: null == contributors ? _self.contributors : contributors // ignore: cast_nullable_to_non_nullable
as List<BookContributor>,genres: null == genres ? _self.genres : genres // ignore: cast_nullable_to_non_nullable
as List<BookGenre>,keywords: null == keywords ? _self.keywords : keywords // ignore: cast_nullable_to_non_nullable
as List<String>,annotation: freezed == annotation ? _self.annotation : annotation // ignore: cast_nullable_to_non_nullable
as BookContent?,series: freezed == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as BookSeries?,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as BookCover?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as Uri?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
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
