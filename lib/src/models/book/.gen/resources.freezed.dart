// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../resources.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookResource {

 String get id; String get mediaType; Uint8List get bytes; String? get fileName; Uri? get originalUri;
/// Create a copy of BookResource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookResourceCopyWith<BookResource> get copyWith => _$BookResourceCopyWithImpl<BookResource>(this as BookResource, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookResource&&(identical(other.id, id) || other.id == id)&&(identical(other.mediaType, mediaType) || other.mediaType == mediaType)&&const DeepCollectionEquality().equals(other.bytes, bytes)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.originalUri, originalUri) || other.originalUri == originalUri));
}


@override
int get hashCode => Object.hash(runtimeType,id,mediaType,const DeepCollectionEquality().hash(bytes),fileName,originalUri);

@override
String toString() {
  return 'BookResource(id: $id, mediaType: $mediaType, bytes: $bytes, fileName: $fileName, originalUri: $originalUri)';
}


}

/// @nodoc
abstract mixin class $BookResourceCopyWith<$Res>  {
  factory $BookResourceCopyWith(BookResource value, $Res Function(BookResource) _then) = _$BookResourceCopyWithImpl;
@useResult
$Res call({
 String id, String mediaType, Uint8List bytes, String? fileName, Uri? originalUri
});




}
/// @nodoc
class _$BookResourceCopyWithImpl<$Res>
    implements $BookResourceCopyWith<$Res> {
  _$BookResourceCopyWithImpl(this._self, this._then);

  final BookResource _self;
  final $Res Function(BookResource) _then;

/// Create a copy of BookResource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? mediaType = null,Object? bytes = null,Object? fileName = freezed,Object? originalUri = freezed,}) {
  return _then(BookResource(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mediaType: null == mediaType ? _self.mediaType : mediaType // ignore: cast_nullable_to_non_nullable
as String,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as Uint8List,fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,originalUri: freezed == originalUri ? _self.originalUri : originalUri // ignore: cast_nullable_to_non_nullable
as Uri?,
  ));
}

}



/// @nodoc
mixin _$BookResourceRef {

 String get id;
/// Create a copy of BookResourceRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookResourceRefCopyWith<BookResourceRef> get copyWith => _$BookResourceRefCopyWithImpl<BookResourceRef>(this as BookResourceRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookResourceRef&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'BookResourceRef(id: $id)';
}


}

/// @nodoc
abstract mixin class $BookResourceRefCopyWith<$Res>  {
  factory $BookResourceRefCopyWith(BookResourceRef value, $Res Function(BookResourceRef) _then) = _$BookResourceRefCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$BookResourceRefCopyWithImpl<$Res>
    implements $BookResourceRefCopyWith<$Res> {
  _$BookResourceRefCopyWithImpl(this._self, this._then);

  final BookResourceRef _self;
  final $Res Function(BookResourceRef) _then;

/// Create a copy of BookResourceRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(BookResourceRef(
null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
mixin _$BookResourceRequest {

 String get id; String? get source; Uri? get baseUri; bool get isInline;
/// Create a copy of BookResourceRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookResourceRequestCopyWith<BookResourceRequest> get copyWith => _$BookResourceRequestCopyWithImpl<BookResourceRequest>(this as BookResourceRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookResourceRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.source, source) || other.source == source)&&(identical(other.baseUri, baseUri) || other.baseUri == baseUri)&&(identical(other.isInline, isInline) || other.isInline == isInline));
}


@override
int get hashCode => Object.hash(runtimeType,id,source,baseUri,isInline);

@override
String toString() {
  return 'BookResourceRequest(id: $id, source: $source, baseUri: $baseUri, isInline: $isInline)';
}


}

/// @nodoc
abstract mixin class $BookResourceRequestCopyWith<$Res>  {
  factory $BookResourceRequestCopyWith(BookResourceRequest value, $Res Function(BookResourceRequest) _then) = _$BookResourceRequestCopyWithImpl;
@useResult
$Res call({
 String id, String? source, Uri? baseUri, bool isInline
});




}
/// @nodoc
class _$BookResourceRequestCopyWithImpl<$Res>
    implements $BookResourceRequestCopyWith<$Res> {
  _$BookResourceRequestCopyWithImpl(this._self, this._then);

  final BookResourceRequest _self;
  final $Res Function(BookResourceRequest) _then;

/// Create a copy of BookResourceRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? source = freezed,Object? baseUri = freezed,Object? isInline = null,}) {
  return _then(BookResourceRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,baseUri: freezed == baseUri ? _self.baseUri : baseUri // ignore: cast_nullable_to_non_nullable
as Uri?,isInline: null == isInline ? _self.isInline : isInline // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



// dart format on
