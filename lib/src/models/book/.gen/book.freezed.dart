// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Book {

 String get id; BookMetadata get metadata; BookContent get content; List<BookResource> get resources;
/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookCopyWith<Book> get copyWith => _$BookCopyWithImpl<Book>(this as Book, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Book&&(identical(other.id, id) || other.id == id)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.content, content) || other.content == content)&&const DeepCollectionEquality().equals(other.resources, resources));
}


@override
int get hashCode => Object.hash(runtimeType,id,metadata,content,const DeepCollectionEquality().hash(resources));

@override
String toString() {
  return 'Book(id: $id, metadata: $metadata, content: $content, resources: $resources)';
}


}

/// @nodoc
abstract mixin class $BookCopyWith<$Res>  {
  factory $BookCopyWith(Book value, $Res Function(Book) _then) = _$BookCopyWithImpl;
@useResult
$Res call({
 String id, BookMetadata metadata, BookContent content, List<BookResource> resources
});




}
/// @nodoc
class _$BookCopyWithImpl<$Res>
    implements $BookCopyWith<$Res> {
  _$BookCopyWithImpl(this._self, this._then);

  final Book _self;
  final $Res Function(Book) _then;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? metadata = null,Object? content = null,Object? resources = null,}) {
  return _then(Book(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as BookMetadata,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as BookContent,resources: null == resources ? _self.resources : resources // ignore: cast_nullable_to_non_nullable
as List<BookResource>,
  ));
}

}



// dart format on
