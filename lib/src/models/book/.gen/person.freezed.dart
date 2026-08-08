// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../person.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookContributor {

 BookContributorRole get role; PersonName get name; Uri? get homePage; String? get email;
/// Create a copy of BookContributor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookContributorCopyWith<BookContributor> get copyWith => _$BookContributorCopyWithImpl<BookContributor>(this as BookContributor, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookContributor&&(identical(other.role, role) || other.role == role)&&(identical(other.name, name) || other.name == name)&&(identical(other.homePage, homePage) || other.homePage == homePage)&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode => Object.hash(runtimeType,role,name,homePage,email);

@override
String toString() {
  return 'BookContributor(role: $role, name: $name, homePage: $homePage, email: $email)';
}


}

/// @nodoc
abstract mixin class $BookContributorCopyWith<$Res>  {
  factory $BookContributorCopyWith(BookContributor value, $Res Function(BookContributor) _then) = _$BookContributorCopyWithImpl;
@useResult
$Res call({
 BookContributorRole role, PersonName name, Uri? homePage, String? email
});




}
/// @nodoc
class _$BookContributorCopyWithImpl<$Res>
    implements $BookContributorCopyWith<$Res> {
  _$BookContributorCopyWithImpl(this._self, this._then);

  final BookContributor _self;
  final $Res Function(BookContributor) _then;

/// Create a copy of BookContributor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? name = null,Object? homePage = freezed,Object? email = freezed,}) {
  return _then(BookContributor(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as BookContributorRole,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as PersonName,homePage: freezed == homePage ? _self.homePage : homePage // ignore: cast_nullable_to_non_nullable
as Uri?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
mixin _$PersonName {

 String? get first; String? get middle; String? get last; String? get nickname; String? get display;
/// Create a copy of PersonName
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PersonNameCopyWith<PersonName> get copyWith => _$PersonNameCopyWithImpl<PersonName>(this as PersonName, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PersonName&&(identical(other.first, first) || other.first == first)&&(identical(other.middle, middle) || other.middle == middle)&&(identical(other.last, last) || other.last == last)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.display, display) || other.display == display));
}


@override
int get hashCode => Object.hash(runtimeType,first,middle,last,nickname,display);

@override
String toString() {
  return 'PersonName(first: $first, middle: $middle, last: $last, nickname: $nickname, display: $display)';
}


}

/// @nodoc
abstract mixin class $PersonNameCopyWith<$Res>  {
  factory $PersonNameCopyWith(PersonName value, $Res Function(PersonName) _then) = _$PersonNameCopyWithImpl;
@useResult
$Res call({
 String? first, String? middle, String? last, String? nickname, String? display
});




}
/// @nodoc
class _$PersonNameCopyWithImpl<$Res>
    implements $PersonNameCopyWith<$Res> {
  _$PersonNameCopyWithImpl(this._self, this._then);

  final PersonName _self;
  final $Res Function(PersonName) _then;

/// Create a copy of PersonName
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? first = freezed,Object? middle = freezed,Object? last = freezed,Object? nickname = freezed,Object? display = freezed,}) {
  return _then(PersonName(
first: freezed == first ? _self.first : first // ignore: cast_nullable_to_non_nullable
as String?,middle: freezed == middle ? _self.middle : middle // ignore: cast_nullable_to_non_nullable
as String?,last: freezed == last ? _self.last : last // ignore: cast_nullable_to_non_nullable
as String?,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,display: freezed == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



// dart format on
