// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UserProfile {

 String get id; String get name; String get email; String get accessStatus; String? get avatarUrl;
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileCopyWith<UserProfile> get copyWith => _$UserProfileCopyWithImpl<UserProfile>(this as UserProfile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.accessStatus, accessStatus) || other.accessStatus == accessStatus)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,email,accessStatus,avatarUrl);

@override
String toString() {
  return 'UserProfile(id: $id, name: $name, email: $email, accessStatus: $accessStatus, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $UserProfileCopyWith<$Res>  {
  factory $UserProfileCopyWith(UserProfile value, $Res Function(UserProfile) _then) = _$UserProfileCopyWithImpl;
@useResult
$Res call({
 String id, String name, String email, String accessStatus, String? avatarUrl
});




}
/// @nodoc
class _$UserProfileCopyWithImpl<$Res>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._self, this._then);

  final UserProfile _self;
  final $Res Function(UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? email = null,Object? accessStatus = null,Object? avatarUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,accessStatus: null == accessStatus ? _self.accessStatus : accessStatus // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserProfile].
extension UserProfilePatterns on UserProfile {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfile value)  $default,){
final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfile value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String email,  String accessStatus,  String? avatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.accessStatus,_that.avatarUrl);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String email,  String accessStatus,  String? avatarUrl)  $default,) {final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that.id,_that.name,_that.email,_that.accessStatus,_that.avatarUrl);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String email,  String accessStatus,  String? avatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.accessStatus,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc


class _UserProfile extends UserProfile {
  const _UserProfile({required this.id, required this.name, required this.email, required this.accessStatus, this.avatarUrl}): super._();


@override final  String id;
@override final  String name;
@override final  String email;
@override final  String accessStatus;
@override final  String? avatarUrl;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileCopyWith<_UserProfile> get copyWith => __$UserProfileCopyWithImpl<_UserProfile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.accessStatus, accessStatus) || other.accessStatus == accessStatus)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,email,accessStatus,avatarUrl);

@override
String toString() {
  return 'UserProfile(id: $id, name: $name, email: $email, accessStatus: $accessStatus, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$UserProfileCopyWith<$Res> implements $UserProfileCopyWith<$Res> {
  factory _$UserProfileCopyWith(_UserProfile value, $Res Function(_UserProfile) _then) = __$UserProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String email, String accessStatus, String? avatarUrl
});




}
/// @nodoc
class __$UserProfileCopyWithImpl<$Res>
    implements _$UserProfileCopyWith<$Res> {
  __$UserProfileCopyWithImpl(this._self, this._then);

  final _UserProfile _self;
  final $Res Function(_UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? email = null,Object? accessStatus = null,Object? avatarUrl = freezed,}) {
  return _then(_UserProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,accessStatus: null == accessStatus ? _self.accessStatus : accessStatus // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$AccessState {

 AccessStatus get status; UserProfile? get profile; String? get message;
/// Create a copy of AccessState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccessStateCopyWith<AccessState> get copyWith => _$AccessStateCopyWithImpl<AccessState>(this as AccessState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccessState&&(identical(other.status, status) || other.status == status)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,status,profile,message);

@override
String toString() {
  return 'AccessState(status: $status, profile: $profile, message: $message)';
}


}

/// @nodoc
abstract mixin class $AccessStateCopyWith<$Res>  {
  factory $AccessStateCopyWith(AccessState value, $Res Function(AccessState) _then) = _$AccessStateCopyWithImpl;
@useResult
$Res call({
 AccessStatus status, UserProfile? profile, String? message
});


$UserProfileCopyWith<$Res>? get profile;

}
/// @nodoc
class _$AccessStateCopyWithImpl<$Res>
    implements $AccessStateCopyWith<$Res> {
  _$AccessStateCopyWithImpl(this._self, this._then);

  final AccessState _self;
  final $Res Function(AccessState) _then;

/// Create a copy of AccessState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? profile = freezed,Object? message = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AccessStatus,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as UserProfile?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AccessState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserProfileCopyWith<$Res>? get profile {
    if (_self.profile == null) {
    return null;
  }

  return $UserProfileCopyWith<$Res>(_self.profile!, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}


/// Adds pattern-matching-related methods to [AccessState].
extension AccessStatePatterns on AccessState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccessState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccessState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccessState value)  $default,){
final _that = this;
switch (_that) {
case _AccessState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccessState value)?  $default,){
final _that = this;
switch (_that) {
case _AccessState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AccessStatus status,  UserProfile? profile,  String? message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccessState() when $default != null:
return $default(_that.status,_that.profile,_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AccessStatus status,  UserProfile? profile,  String? message)  $default,) {final _that = this;
switch (_that) {
case _AccessState():
return $default(_that.status,_that.profile,_that.message);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AccessStatus status,  UserProfile? profile,  String? message)?  $default,) {final _that = this;
switch (_that) {
case _AccessState() when $default != null:
return $default(_that.status,_that.profile,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _AccessState implements AccessState {
  const _AccessState({required this.status, this.profile, this.message});


@override final  AccessStatus status;
@override final  UserProfile? profile;
@override final  String? message;

/// Create a copy of AccessState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccessStateCopyWith<_AccessState> get copyWith => __$AccessStateCopyWithImpl<_AccessState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccessState&&(identical(other.status, status) || other.status == status)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,status,profile,message);

@override
String toString() {
  return 'AccessState(status: $status, profile: $profile, message: $message)';
}


}

/// @nodoc
abstract mixin class _$AccessStateCopyWith<$Res> implements $AccessStateCopyWith<$Res> {
  factory _$AccessStateCopyWith(_AccessState value, $Res Function(_AccessState) _then) = __$AccessStateCopyWithImpl;
@override @useResult
$Res call({
 AccessStatus status, UserProfile? profile, String? message
});


@override $UserProfileCopyWith<$Res>? get profile;

}
/// @nodoc
class __$AccessStateCopyWithImpl<$Res>
    implements _$AccessStateCopyWith<$Res> {
  __$AccessStateCopyWithImpl(this._self, this._then);

  final _AccessState _self;
  final $Res Function(_AccessState) _then;

/// Create a copy of AccessState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? profile = freezed,Object? message = freezed,}) {
  return _then(_AccessState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AccessStatus,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as UserProfile?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AccessState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserProfileCopyWith<$Res>? get profile {
    if (_self.profile == null) {
    return null;
  }

  return $UserProfileCopyWith<$Res>(_self.profile!, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}

/// @nodoc
mixin _$AgendaEvent {

 String get id; String get title; String get description; DateTime get date; bool get allDay; String get googleStatus; String get syncStatus;
/// Create a copy of AgendaEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgendaEventCopyWith<AgendaEvent> get copyWith => _$AgendaEventCopyWithImpl<AgendaEvent>(this as AgendaEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgendaEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.date, date) || other.date == date)&&(identical(other.allDay, allDay) || other.allDay == allDay)&&(identical(other.googleStatus, googleStatus) || other.googleStatus == googleStatus)&&(identical(other.syncStatus, syncStatus) || other.syncStatus == syncStatus));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,description,date,allDay,googleStatus,syncStatus);

@override
String toString() {
  return 'AgendaEvent(id: $id, title: $title, description: $description, date: $date, allDay: $allDay, googleStatus: $googleStatus, syncStatus: $syncStatus)';
}


}

/// @nodoc
abstract mixin class $AgendaEventCopyWith<$Res>  {
  factory $AgendaEventCopyWith(AgendaEvent value, $Res Function(AgendaEvent) _then) = _$AgendaEventCopyWithImpl;
@useResult
$Res call({
 String id, String title, String description, DateTime date, bool allDay, String googleStatus, String syncStatus
});




}
/// @nodoc
class _$AgendaEventCopyWithImpl<$Res>
    implements $AgendaEventCopyWith<$Res> {
  _$AgendaEventCopyWithImpl(this._self, this._then);

  final AgendaEvent _self;
  final $Res Function(AgendaEvent) _then;

/// Create a copy of AgendaEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = null,Object? date = null,Object? allDay = null,Object? googleStatus = null,Object? syncStatus = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,allDay: null == allDay ? _self.allDay : allDay // ignore: cast_nullable_to_non_nullable
as bool,googleStatus: null == googleStatus ? _self.googleStatus : googleStatus // ignore: cast_nullable_to_non_nullable
as String,syncStatus: null == syncStatus ? _self.syncStatus : syncStatus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AgendaEvent].
extension AgendaEventPatterns on AgendaEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgendaEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgendaEvent() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgendaEvent value)  $default,){
final _that = this;
switch (_that) {
case _AgendaEvent():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgendaEvent value)?  $default,){
final _that = this;
switch (_that) {
case _AgendaEvent() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String description,  DateTime date,  bool allDay,  String googleStatus,  String syncStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgendaEvent() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.date,_that.allDay,_that.googleStatus,_that.syncStatus);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String description,  DateTime date,  bool allDay,  String googleStatus,  String syncStatus)  $default,) {final _that = this;
switch (_that) {
case _AgendaEvent():
return $default(_that.id,_that.title,_that.description,_that.date,_that.allDay,_that.googleStatus,_that.syncStatus);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String description,  DateTime date,  bool allDay,  String googleStatus,  String syncStatus)?  $default,) {final _that = this;
switch (_that) {
case _AgendaEvent() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.date,_that.allDay,_that.googleStatus,_that.syncStatus);case _:
  return null;

}
}

}

/// @nodoc


class _AgendaEvent extends AgendaEvent {
  const _AgendaEvent({required this.id, required this.title, required this.description, required this.date, required this.allDay, required this.googleStatus, required this.syncStatus}): super._();


@override final  String id;
@override final  String title;
@override final  String description;
@override final  DateTime date;
@override final  bool allDay;
@override final  String googleStatus;
@override final  String syncStatus;

/// Create a copy of AgendaEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgendaEventCopyWith<_AgendaEvent> get copyWith => __$AgendaEventCopyWithImpl<_AgendaEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgendaEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.date, date) || other.date == date)&&(identical(other.allDay, allDay) || other.allDay == allDay)&&(identical(other.googleStatus, googleStatus) || other.googleStatus == googleStatus)&&(identical(other.syncStatus, syncStatus) || other.syncStatus == syncStatus));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,description,date,allDay,googleStatus,syncStatus);

@override
String toString() {
  return 'AgendaEvent(id: $id, title: $title, description: $description, date: $date, allDay: $allDay, googleStatus: $googleStatus, syncStatus: $syncStatus)';
}


}

/// @nodoc
abstract mixin class _$AgendaEventCopyWith<$Res> implements $AgendaEventCopyWith<$Res> {
  factory _$AgendaEventCopyWith(_AgendaEvent value, $Res Function(_AgendaEvent) _then) = __$AgendaEventCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String description, DateTime date, bool allDay, String googleStatus, String syncStatus
});




}
/// @nodoc
class __$AgendaEventCopyWithImpl<$Res>
    implements _$AgendaEventCopyWith<$Res> {
  __$AgendaEventCopyWithImpl(this._self, this._then);

  final _AgendaEvent _self;
  final $Res Function(_AgendaEvent) _then;

/// Create a copy of AgendaEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? date = null,Object? allDay = null,Object? googleStatus = null,Object? syncStatus = null,}) {
  return _then(_AgendaEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,allDay: null == allDay ? _self.allDay : allDay // ignore: cast_nullable_to_non_nullable
as bool,googleStatus: null == googleStatus ? _self.googleStatus : googleStatus // ignore: cast_nullable_to_non_nullable
as String,syncStatus: null == syncStatus ? _self.syncStatus : syncStatus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$Commitment {

 String get id; String get type; String get title; String get description; DateTime get date; double get confidence; String get status; bool get requiresReview; String? get time; String? get emailSubject; String? get connectionId;
/// Create a copy of Commitment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommitmentCopyWith<Commitment> get copyWith => _$CommitmentCopyWithImpl<Commitment>(this as Commitment, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Commitment&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.date, date) || other.date == date)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.status, status) || other.status == status)&&(identical(other.requiresReview, requiresReview) || other.requiresReview == requiresReview)&&(identical(other.time, time) || other.time == time)&&(identical(other.emailSubject, emailSubject) || other.emailSubject == emailSubject)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,title,description,date,confidence,status,requiresReview,time,emailSubject,connectionId);

@override
String toString() {
  return 'Commitment(id: $id, type: $type, title: $title, description: $description, date: $date, confidence: $confidence, status: $status, requiresReview: $requiresReview, time: $time, emailSubject: $emailSubject, connectionId: $connectionId)';
}


}

/// @nodoc
abstract mixin class $CommitmentCopyWith<$Res>  {
  factory $CommitmentCopyWith(Commitment value, $Res Function(Commitment) _then) = _$CommitmentCopyWithImpl;
@useResult
$Res call({
 String id, String type, String title, String description, DateTime date, double confidence, String status, bool requiresReview, String? time, String? emailSubject, String? connectionId
});




}
/// @nodoc
class _$CommitmentCopyWithImpl<$Res>
    implements $CommitmentCopyWith<$Res> {
  _$CommitmentCopyWithImpl(this._self, this._then);

  final Commitment _self;
  final $Res Function(Commitment) _then;

/// Create a copy of Commitment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? title = null,Object? description = null,Object? date = null,Object? confidence = null,Object? status = null,Object? requiresReview = null,Object? time = freezed,Object? emailSubject = freezed,Object? connectionId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,requiresReview: null == requiresReview ? _self.requiresReview : requiresReview // ignore: cast_nullable_to_non_nullable
as bool,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String?,emailSubject: freezed == emailSubject ? _self.emailSubject : emailSubject // ignore: cast_nullable_to_non_nullable
as String?,connectionId: freezed == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Commitment].
extension CommitmentPatterns on Commitment {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Commitment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Commitment() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Commitment value)  $default,){
final _that = this;
switch (_that) {
case _Commitment():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Commitment value)?  $default,){
final _that = this;
switch (_that) {
case _Commitment() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  String title,  String description,  DateTime date,  double confidence,  String status,  bool requiresReview,  String? time,  String? emailSubject,  String? connectionId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Commitment() when $default != null:
return $default(_that.id,_that.type,_that.title,_that.description,_that.date,_that.confidence,_that.status,_that.requiresReview,_that.time,_that.emailSubject,_that.connectionId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  String title,  String description,  DateTime date,  double confidence,  String status,  bool requiresReview,  String? time,  String? emailSubject,  String? connectionId)  $default,) {final _that = this;
switch (_that) {
case _Commitment():
return $default(_that.id,_that.type,_that.title,_that.description,_that.date,_that.confidence,_that.status,_that.requiresReview,_that.time,_that.emailSubject,_that.connectionId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  String title,  String description,  DateTime date,  double confidence,  String status,  bool requiresReview,  String? time,  String? emailSubject,  String? connectionId)?  $default,) {final _that = this;
switch (_that) {
case _Commitment() when $default != null:
return $default(_that.id,_that.type,_that.title,_that.description,_that.date,_that.confidence,_that.status,_that.requiresReview,_that.time,_that.emailSubject,_that.connectionId);case _:
  return null;

}
}

}

/// @nodoc


class _Commitment implements Commitment {
  const _Commitment({required this.id, required this.type, required this.title, required this.description, required this.date, required this.confidence, required this.status, required this.requiresReview, this.time, this.emailSubject, this.connectionId});


@override final  String id;
@override final  String type;
@override final  String title;
@override final  String description;
@override final  DateTime date;
@override final  double confidence;
@override final  String status;
@override final  bool requiresReview;
@override final  String? time;
@override final  String? emailSubject;
@override final  String? connectionId;

/// Create a copy of Commitment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommitmentCopyWith<_Commitment> get copyWith => __$CommitmentCopyWithImpl<_Commitment>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Commitment&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.date, date) || other.date == date)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.status, status) || other.status == status)&&(identical(other.requiresReview, requiresReview) || other.requiresReview == requiresReview)&&(identical(other.time, time) || other.time == time)&&(identical(other.emailSubject, emailSubject) || other.emailSubject == emailSubject)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,title,description,date,confidence,status,requiresReview,time,emailSubject,connectionId);

@override
String toString() {
  return 'Commitment(id: $id, type: $type, title: $title, description: $description, date: $date, confidence: $confidence, status: $status, requiresReview: $requiresReview, time: $time, emailSubject: $emailSubject, connectionId: $connectionId)';
}


}

/// @nodoc
abstract mixin class _$CommitmentCopyWith<$Res> implements $CommitmentCopyWith<$Res> {
  factory _$CommitmentCopyWith(_Commitment value, $Res Function(_Commitment) _then) = __$CommitmentCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String title, String description, DateTime date, double confidence, String status, bool requiresReview, String? time, String? emailSubject, String? connectionId
});




}
/// @nodoc
class __$CommitmentCopyWithImpl<$Res>
    implements _$CommitmentCopyWith<$Res> {
  __$CommitmentCopyWithImpl(this._self, this._then);

  final _Commitment _self;
  final $Res Function(_Commitment) _then;

/// Create a copy of Commitment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? title = null,Object? description = null,Object? date = null,Object? confidence = null,Object? status = null,Object? requiresReview = null,Object? time = freezed,Object? emailSubject = freezed,Object? connectionId = freezed,}) {
  return _then(_Commitment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,requiresReview: null == requiresReview ? _self.requiresReview : requiresReview // ignore: cast_nullable_to_non_nullable
as bool,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String?,emailSubject: freezed == emailSubject ? _self.emailSubject : emailSubject // ignore: cast_nullable_to_non_nullable
as String?,connectionId: freezed == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$DashboardSummary {

 int get daysUsingAgenKin; int get emailsToday; int get totalEmails; int get pendingReviews; int get eventsCreated; String get planName;
/// Create a copy of DashboardSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardSummaryCopyWith<DashboardSummary> get copyWith => _$DashboardSummaryCopyWithImpl<DashboardSummary>(this as DashboardSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardSummary&&(identical(other.daysUsingAgenKin, daysUsingAgenKin) || other.daysUsingAgenKin == daysUsingAgenKin)&&(identical(other.emailsToday, emailsToday) || other.emailsToday == emailsToday)&&(identical(other.totalEmails, totalEmails) || other.totalEmails == totalEmails)&&(identical(other.pendingReviews, pendingReviews) || other.pendingReviews == pendingReviews)&&(identical(other.eventsCreated, eventsCreated) || other.eventsCreated == eventsCreated)&&(identical(other.planName, planName) || other.planName == planName));
}


@override
int get hashCode => Object.hash(runtimeType,daysUsingAgenKin,emailsToday,totalEmails,pendingReviews,eventsCreated,planName);

@override
String toString() {
  return 'DashboardSummary(daysUsingAgenKin: $daysUsingAgenKin, emailsToday: $emailsToday, totalEmails: $totalEmails, pendingReviews: $pendingReviews, eventsCreated: $eventsCreated, planName: $planName)';
}


}

/// @nodoc
abstract mixin class $DashboardSummaryCopyWith<$Res>  {
  factory $DashboardSummaryCopyWith(DashboardSummary value, $Res Function(DashboardSummary) _then) = _$DashboardSummaryCopyWithImpl;
@useResult
$Res call({
 int daysUsingAgenKin, int emailsToday, int totalEmails, int pendingReviews, int eventsCreated, String planName
});




}
/// @nodoc
class _$DashboardSummaryCopyWithImpl<$Res>
    implements $DashboardSummaryCopyWith<$Res> {
  _$DashboardSummaryCopyWithImpl(this._self, this._then);

  final DashboardSummary _self;
  final $Res Function(DashboardSummary) _then;

/// Create a copy of DashboardSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? daysUsingAgenKin = null,Object? emailsToday = null,Object? totalEmails = null,Object? pendingReviews = null,Object? eventsCreated = null,Object? planName = null,}) {
  return _then(_self.copyWith(
daysUsingAgenKin: null == daysUsingAgenKin ? _self.daysUsingAgenKin : daysUsingAgenKin // ignore: cast_nullable_to_non_nullable
as int,emailsToday: null == emailsToday ? _self.emailsToday : emailsToday // ignore: cast_nullable_to_non_nullable
as int,totalEmails: null == totalEmails ? _self.totalEmails : totalEmails // ignore: cast_nullable_to_non_nullable
as int,pendingReviews: null == pendingReviews ? _self.pendingReviews : pendingReviews // ignore: cast_nullable_to_non_nullable
as int,eventsCreated: null == eventsCreated ? _self.eventsCreated : eventsCreated // ignore: cast_nullable_to_non_nullable
as int,planName: null == planName ? _self.planName : planName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DashboardSummary].
extension DashboardSummaryPatterns on DashboardSummary {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DashboardSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DashboardSummary() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DashboardSummary value)  $default,){
final _that = this;
switch (_that) {
case _DashboardSummary():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DashboardSummary value)?  $default,){
final _that = this;
switch (_that) {
case _DashboardSummary() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int daysUsingAgenKin,  int emailsToday,  int totalEmails,  int pendingReviews,  int eventsCreated,  String planName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DashboardSummary() when $default != null:
return $default(_that.daysUsingAgenKin,_that.emailsToday,_that.totalEmails,_that.pendingReviews,_that.eventsCreated,_that.planName);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int daysUsingAgenKin,  int emailsToday,  int totalEmails,  int pendingReviews,  int eventsCreated,  String planName)  $default,) {final _that = this;
switch (_that) {
case _DashboardSummary():
return $default(_that.daysUsingAgenKin,_that.emailsToday,_that.totalEmails,_that.pendingReviews,_that.eventsCreated,_that.planName);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int daysUsingAgenKin,  int emailsToday,  int totalEmails,  int pendingReviews,  int eventsCreated,  String planName)?  $default,) {final _that = this;
switch (_that) {
case _DashboardSummary() when $default != null:
return $default(_that.daysUsingAgenKin,_that.emailsToday,_that.totalEmails,_that.pendingReviews,_that.eventsCreated,_that.planName);case _:
  return null;

}
}

}

/// @nodoc


class _DashboardSummary implements DashboardSummary {
  const _DashboardSummary({required this.daysUsingAgenKin, required this.emailsToday, required this.totalEmails, required this.pendingReviews, required this.eventsCreated, required this.planName});


@override final  int daysUsingAgenKin;
@override final  int emailsToday;
@override final  int totalEmails;
@override final  int pendingReviews;
@override final  int eventsCreated;
@override final  String planName;

/// Create a copy of DashboardSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DashboardSummaryCopyWith<_DashboardSummary> get copyWith => __$DashboardSummaryCopyWithImpl<_DashboardSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DashboardSummary&&(identical(other.daysUsingAgenKin, daysUsingAgenKin) || other.daysUsingAgenKin == daysUsingAgenKin)&&(identical(other.emailsToday, emailsToday) || other.emailsToday == emailsToday)&&(identical(other.totalEmails, totalEmails) || other.totalEmails == totalEmails)&&(identical(other.pendingReviews, pendingReviews) || other.pendingReviews == pendingReviews)&&(identical(other.eventsCreated, eventsCreated) || other.eventsCreated == eventsCreated)&&(identical(other.planName, planName) || other.planName == planName));
}


@override
int get hashCode => Object.hash(runtimeType,daysUsingAgenKin,emailsToday,totalEmails,pendingReviews,eventsCreated,planName);

@override
String toString() {
  return 'DashboardSummary(daysUsingAgenKin: $daysUsingAgenKin, emailsToday: $emailsToday, totalEmails: $totalEmails, pendingReviews: $pendingReviews, eventsCreated: $eventsCreated, planName: $planName)';
}


}

/// @nodoc
abstract mixin class _$DashboardSummaryCopyWith<$Res> implements $DashboardSummaryCopyWith<$Res> {
  factory _$DashboardSummaryCopyWith(_DashboardSummary value, $Res Function(_DashboardSummary) _then) = __$DashboardSummaryCopyWithImpl;
@override @useResult
$Res call({
 int daysUsingAgenKin, int emailsToday, int totalEmails, int pendingReviews, int eventsCreated, String planName
});




}
/// @nodoc
class __$DashboardSummaryCopyWithImpl<$Res>
    implements _$DashboardSummaryCopyWith<$Res> {
  __$DashboardSummaryCopyWithImpl(this._self, this._then);

  final _DashboardSummary _self;
  final $Res Function(_DashboardSummary) _then;

/// Create a copy of DashboardSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? daysUsingAgenKin = null,Object? emailsToday = null,Object? totalEmails = null,Object? pendingReviews = null,Object? eventsCreated = null,Object? planName = null,}) {
  return _then(_DashboardSummary(
daysUsingAgenKin: null == daysUsingAgenKin ? _self.daysUsingAgenKin : daysUsingAgenKin // ignore: cast_nullable_to_non_nullable
as int,emailsToday: null == emailsToday ? _self.emailsToday : emailsToday // ignore: cast_nullable_to_non_nullable
as int,totalEmails: null == totalEmails ? _self.totalEmails : totalEmails // ignore: cast_nullable_to_non_nullable
as int,pendingReviews: null == pendingReviews ? _self.pendingReviews : pendingReviews // ignore: cast_nullable_to_non_nullable
as int,eventsCreated: null == eventsCreated ? _self.eventsCreated : eventsCreated // ignore: cast_nullable_to_non_nullable
as int,planName: null == planName ? _self.planName : planName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$GmailConnection {

 String get id; String get email; bool get connected; String get status; bool get calendarActive; int get pendingTasks; int get errorTasks; DateTime? get lastReadAt; String? get lastError;
/// Create a copy of GmailConnection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GmailConnectionCopyWith<GmailConnection> get copyWith => _$GmailConnectionCopyWithImpl<GmailConnection>(this as GmailConnection, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GmailConnection&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.status, status) || other.status == status)&&(identical(other.calendarActive, calendarActive) || other.calendarActive == calendarActive)&&(identical(other.pendingTasks, pendingTasks) || other.pendingTasks == pendingTasks)&&(identical(other.errorTasks, errorTasks) || other.errorTasks == errorTasks)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.lastError, lastError) || other.lastError == lastError));
}


@override
int get hashCode => Object.hash(runtimeType,id,email,connected,status,calendarActive,pendingTasks,errorTasks,lastReadAt,lastError);

@override
String toString() {
  return 'GmailConnection(id: $id, email: $email, connected: $connected, status: $status, calendarActive: $calendarActive, pendingTasks: $pendingTasks, errorTasks: $errorTasks, lastReadAt: $lastReadAt, lastError: $lastError)';
}


}

/// @nodoc
abstract mixin class $GmailConnectionCopyWith<$Res>  {
  factory $GmailConnectionCopyWith(GmailConnection value, $Res Function(GmailConnection) _then) = _$GmailConnectionCopyWithImpl;
@useResult
$Res call({
 String id, String email, bool connected, String status, bool calendarActive, int pendingTasks, int errorTasks, DateTime? lastReadAt, String? lastError
});




}
/// @nodoc
class _$GmailConnectionCopyWithImpl<$Res>
    implements $GmailConnectionCopyWith<$Res> {
  _$GmailConnectionCopyWithImpl(this._self, this._then);

  final GmailConnection _self;
  final $Res Function(GmailConnection) _then;

/// Create a copy of GmailConnection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? connected = null,Object? status = null,Object? calendarActive = null,Object? pendingTasks = null,Object? errorTasks = null,Object? lastReadAt = freezed,Object? lastError = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,calendarActive: null == calendarActive ? _self.calendarActive : calendarActive // ignore: cast_nullable_to_non_nullable
as bool,pendingTasks: null == pendingTasks ? _self.pendingTasks : pendingTasks // ignore: cast_nullable_to_non_nullable
as int,errorTasks: null == errorTasks ? _self.errorTasks : errorTasks // ignore: cast_nullable_to_non_nullable
as int,lastReadAt: freezed == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GmailConnection].
extension GmailConnectionPatterns on GmailConnection {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GmailConnection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GmailConnection() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GmailConnection value)  $default,){
final _that = this;
switch (_that) {
case _GmailConnection():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GmailConnection value)?  $default,){
final _that = this;
switch (_that) {
case _GmailConnection() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email,  bool connected,  String status,  bool calendarActive,  int pendingTasks,  int errorTasks,  DateTime? lastReadAt,  String? lastError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GmailConnection() when $default != null:
return $default(_that.id,_that.email,_that.connected,_that.status,_that.calendarActive,_that.pendingTasks,_that.errorTasks,_that.lastReadAt,_that.lastError);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email,  bool connected,  String status,  bool calendarActive,  int pendingTasks,  int errorTasks,  DateTime? lastReadAt,  String? lastError)  $default,) {final _that = this;
switch (_that) {
case _GmailConnection():
return $default(_that.id,_that.email,_that.connected,_that.status,_that.calendarActive,_that.pendingTasks,_that.errorTasks,_that.lastReadAt,_that.lastError);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email,  bool connected,  String status,  bool calendarActive,  int pendingTasks,  int errorTasks,  DateTime? lastReadAt,  String? lastError)?  $default,) {final _that = this;
switch (_that) {
case _GmailConnection() when $default != null:
return $default(_that.id,_that.email,_that.connected,_that.status,_that.calendarActive,_that.pendingTasks,_that.errorTasks,_that.lastReadAt,_that.lastError);case _:
  return null;

}
}

}

/// @nodoc


class _GmailConnection implements GmailConnection {
  const _GmailConnection({required this.id, required this.email, required this.connected, required this.status, required this.calendarActive, required this.pendingTasks, required this.errorTasks, this.lastReadAt, this.lastError});


@override final  String id;
@override final  String email;
@override final  bool connected;
@override final  String status;
@override final  bool calendarActive;
@override final  int pendingTasks;
@override final  int errorTasks;
@override final  DateTime? lastReadAt;
@override final  String? lastError;

/// Create a copy of GmailConnection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GmailConnectionCopyWith<_GmailConnection> get copyWith => __$GmailConnectionCopyWithImpl<_GmailConnection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GmailConnection&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.status, status) || other.status == status)&&(identical(other.calendarActive, calendarActive) || other.calendarActive == calendarActive)&&(identical(other.pendingTasks, pendingTasks) || other.pendingTasks == pendingTasks)&&(identical(other.errorTasks, errorTasks) || other.errorTasks == errorTasks)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.lastError, lastError) || other.lastError == lastError));
}


@override
int get hashCode => Object.hash(runtimeType,id,email,connected,status,calendarActive,pendingTasks,errorTasks,lastReadAt,lastError);

@override
String toString() {
  return 'GmailConnection(id: $id, email: $email, connected: $connected, status: $status, calendarActive: $calendarActive, pendingTasks: $pendingTasks, errorTasks: $errorTasks, lastReadAt: $lastReadAt, lastError: $lastError)';
}


}

/// @nodoc
abstract mixin class _$GmailConnectionCopyWith<$Res> implements $GmailConnectionCopyWith<$Res> {
  factory _$GmailConnectionCopyWith(_GmailConnection value, $Res Function(_GmailConnection) _then) = __$GmailConnectionCopyWithImpl;
@override @useResult
$Res call({
 String id, String email, bool connected, String status, bool calendarActive, int pendingTasks, int errorTasks, DateTime? lastReadAt, String? lastError
});




}
/// @nodoc
class __$GmailConnectionCopyWithImpl<$Res>
    implements _$GmailConnectionCopyWith<$Res> {
  __$GmailConnectionCopyWithImpl(this._self, this._then);

  final _GmailConnection _self;
  final $Res Function(_GmailConnection) _then;

/// Create a copy of GmailConnection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? connected = null,Object? status = null,Object? calendarActive = null,Object? pendingTasks = null,Object? errorTasks = null,Object? lastReadAt = freezed,Object? lastError = freezed,}) {
  return _then(_GmailConnection(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,calendarActive: null == calendarActive ? _self.calendarActive : calendarActive // ignore: cast_nullable_to_non_nullable
as bool,pendingTasks: null == pendingTasks ? _self.pendingTasks : pendingTasks // ignore: cast_nullable_to_non_nullable
as int,errorTasks: null == errorTasks ? _self.errorTasks : errorTasks // ignore: cast_nullable_to_non_nullable
as int,lastReadAt: freezed == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$CalendarConnection {

 bool get connected; int get pendingEvents; int get errorEvents; String? get connectionId; String? get email; DateTime? get lastSyncAt;
/// Create a copy of CalendarConnection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalendarConnectionCopyWith<CalendarConnection> get copyWith => _$CalendarConnectionCopyWithImpl<CalendarConnection>(this as CalendarConnection, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalendarConnection&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.pendingEvents, pendingEvents) || other.pendingEvents == pendingEvents)&&(identical(other.errorEvents, errorEvents) || other.errorEvents == errorEvents)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.email, email) || other.email == email)&&(identical(other.lastSyncAt, lastSyncAt) || other.lastSyncAt == lastSyncAt));
}


@override
int get hashCode => Object.hash(runtimeType,connected,pendingEvents,errorEvents,connectionId,email,lastSyncAt);

@override
String toString() {
  return 'CalendarConnection(connected: $connected, pendingEvents: $pendingEvents, errorEvents: $errorEvents, connectionId: $connectionId, email: $email, lastSyncAt: $lastSyncAt)';
}


}

/// @nodoc
abstract mixin class $CalendarConnectionCopyWith<$Res>  {
  factory $CalendarConnectionCopyWith(CalendarConnection value, $Res Function(CalendarConnection) _then) = _$CalendarConnectionCopyWithImpl;
@useResult
$Res call({
 bool connected, int pendingEvents, int errorEvents, String? connectionId, String? email, DateTime? lastSyncAt
});




}
/// @nodoc
class _$CalendarConnectionCopyWithImpl<$Res>
    implements $CalendarConnectionCopyWith<$Res> {
  _$CalendarConnectionCopyWithImpl(this._self, this._then);

  final CalendarConnection _self;
  final $Res Function(CalendarConnection) _then;

/// Create a copy of CalendarConnection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? connected = null,Object? pendingEvents = null,Object? errorEvents = null,Object? connectionId = freezed,Object? email = freezed,Object? lastSyncAt = freezed,}) {
  return _then(_self.copyWith(
connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,pendingEvents: null == pendingEvents ? _self.pendingEvents : pendingEvents // ignore: cast_nullable_to_non_nullable
as int,errorEvents: null == errorEvents ? _self.errorEvents : errorEvents // ignore: cast_nullable_to_non_nullable
as int,connectionId: freezed == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,lastSyncAt: freezed == lastSyncAt ? _self.lastSyncAt : lastSyncAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [CalendarConnection].
extension CalendarConnectionPatterns on CalendarConnection {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CalendarConnection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CalendarConnection() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CalendarConnection value)  $default,){
final _that = this;
switch (_that) {
case _CalendarConnection():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CalendarConnection value)?  $default,){
final _that = this;
switch (_that) {
case _CalendarConnection() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool connected,  int pendingEvents,  int errorEvents,  String? connectionId,  String? email,  DateTime? lastSyncAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CalendarConnection() when $default != null:
return $default(_that.connected,_that.pendingEvents,_that.errorEvents,_that.connectionId,_that.email,_that.lastSyncAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool connected,  int pendingEvents,  int errorEvents,  String? connectionId,  String? email,  DateTime? lastSyncAt)  $default,) {final _that = this;
switch (_that) {
case _CalendarConnection():
return $default(_that.connected,_that.pendingEvents,_that.errorEvents,_that.connectionId,_that.email,_that.lastSyncAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool connected,  int pendingEvents,  int errorEvents,  String? connectionId,  String? email,  DateTime? lastSyncAt)?  $default,) {final _that = this;
switch (_that) {
case _CalendarConnection() when $default != null:
return $default(_that.connected,_that.pendingEvents,_that.errorEvents,_that.connectionId,_that.email,_that.lastSyncAt);case _:
  return null;

}
}

}

/// @nodoc


class _CalendarConnection implements CalendarConnection {
  const _CalendarConnection({required this.connected, required this.pendingEvents, required this.errorEvents, this.connectionId, this.email, this.lastSyncAt});


@override final  bool connected;
@override final  int pendingEvents;
@override final  int errorEvents;
@override final  String? connectionId;
@override final  String? email;
@override final  DateTime? lastSyncAt;

/// Create a copy of CalendarConnection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CalendarConnectionCopyWith<_CalendarConnection> get copyWith => __$CalendarConnectionCopyWithImpl<_CalendarConnection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CalendarConnection&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.pendingEvents, pendingEvents) || other.pendingEvents == pendingEvents)&&(identical(other.errorEvents, errorEvents) || other.errorEvents == errorEvents)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.email, email) || other.email == email)&&(identical(other.lastSyncAt, lastSyncAt) || other.lastSyncAt == lastSyncAt));
}


@override
int get hashCode => Object.hash(runtimeType,connected,pendingEvents,errorEvents,connectionId,email,lastSyncAt);

@override
String toString() {
  return 'CalendarConnection(connected: $connected, pendingEvents: $pendingEvents, errorEvents: $errorEvents, connectionId: $connectionId, email: $email, lastSyncAt: $lastSyncAt)';
}


}

/// @nodoc
abstract mixin class _$CalendarConnectionCopyWith<$Res> implements $CalendarConnectionCopyWith<$Res> {
  factory _$CalendarConnectionCopyWith(_CalendarConnection value, $Res Function(_CalendarConnection) _then) = __$CalendarConnectionCopyWithImpl;
@override @useResult
$Res call({
 bool connected, int pendingEvents, int errorEvents, String? connectionId, String? email, DateTime? lastSyncAt
});




}
/// @nodoc
class __$CalendarConnectionCopyWithImpl<$Res>
    implements _$CalendarConnectionCopyWith<$Res> {
  __$CalendarConnectionCopyWithImpl(this._self, this._then);

  final _CalendarConnection _self;
  final $Res Function(_CalendarConnection) _then;

/// Create a copy of CalendarConnection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? connected = null,Object? pendingEvents = null,Object? errorEvents = null,Object? connectionId = freezed,Object? email = freezed,Object? lastSyncAt = freezed,}) {
  return _then(_CalendarConnection(
connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,pendingEvents: null == pendingEvents ? _self.pendingEvents : pendingEvents // ignore: cast_nullable_to_non_nullable
as int,errorEvents: null == errorEvents ? _self.errorEvents : errorEvents // ignore: cast_nullable_to_non_nullable
as int,connectionId: freezed == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,lastSyncAt: freezed == lastSyncAt ? _self.lastSyncAt : lastSyncAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$ConnectionsState {

 List<GmailConnection> get gmailAccounts; int get gmailUsed; int get gmailLimit; CalendarConnection get calendar; bool get autoSync; bool get autoCreateEvents; double get confidenceThreshold;
/// Create a copy of ConnectionsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionsStateCopyWith<ConnectionsState> get copyWith => _$ConnectionsStateCopyWithImpl<ConnectionsState>(this as ConnectionsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionsState&&const DeepCollectionEquality().equals(other.gmailAccounts, gmailAccounts)&&(identical(other.gmailUsed, gmailUsed) || other.gmailUsed == gmailUsed)&&(identical(other.gmailLimit, gmailLimit) || other.gmailLimit == gmailLimit)&&(identical(other.calendar, calendar) || other.calendar == calendar)&&(identical(other.autoSync, autoSync) || other.autoSync == autoSync)&&(identical(other.autoCreateEvents, autoCreateEvents) || other.autoCreateEvents == autoCreateEvents)&&(identical(other.confidenceThreshold, confidenceThreshold) || other.confidenceThreshold == confidenceThreshold));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(gmailAccounts),gmailUsed,gmailLimit,calendar,autoSync,autoCreateEvents,confidenceThreshold);

@override
String toString() {
  return 'ConnectionsState(gmailAccounts: $gmailAccounts, gmailUsed: $gmailUsed, gmailLimit: $gmailLimit, calendar: $calendar, autoSync: $autoSync, autoCreateEvents: $autoCreateEvents, confidenceThreshold: $confidenceThreshold)';
}


}

/// @nodoc
abstract mixin class $ConnectionsStateCopyWith<$Res>  {
  factory $ConnectionsStateCopyWith(ConnectionsState value, $Res Function(ConnectionsState) _then) = _$ConnectionsStateCopyWithImpl;
@useResult
$Res call({
 List<GmailConnection> gmailAccounts, int gmailUsed, int gmailLimit, CalendarConnection calendar, bool autoSync, bool autoCreateEvents, double confidenceThreshold
});


$CalendarConnectionCopyWith<$Res> get calendar;

}
/// @nodoc
class _$ConnectionsStateCopyWithImpl<$Res>
    implements $ConnectionsStateCopyWith<$Res> {
  _$ConnectionsStateCopyWithImpl(this._self, this._then);

  final ConnectionsState _self;
  final $Res Function(ConnectionsState) _then;

/// Create a copy of ConnectionsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gmailAccounts = null,Object? gmailUsed = null,Object? gmailLimit = null,Object? calendar = null,Object? autoSync = null,Object? autoCreateEvents = null,Object? confidenceThreshold = null,}) {
  return _then(_self.copyWith(
gmailAccounts: null == gmailAccounts ? _self.gmailAccounts : gmailAccounts // ignore: cast_nullable_to_non_nullable
as List<GmailConnection>,gmailUsed: null == gmailUsed ? _self.gmailUsed : gmailUsed // ignore: cast_nullable_to_non_nullable
as int,gmailLimit: null == gmailLimit ? _self.gmailLimit : gmailLimit // ignore: cast_nullable_to_non_nullable
as int,calendar: null == calendar ? _self.calendar : calendar // ignore: cast_nullable_to_non_nullable
as CalendarConnection,autoSync: null == autoSync ? _self.autoSync : autoSync // ignore: cast_nullable_to_non_nullable
as bool,autoCreateEvents: null == autoCreateEvents ? _self.autoCreateEvents : autoCreateEvents // ignore: cast_nullable_to_non_nullable
as bool,confidenceThreshold: null == confidenceThreshold ? _self.confidenceThreshold : confidenceThreshold // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of ConnectionsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CalendarConnectionCopyWith<$Res> get calendar {

  return $CalendarConnectionCopyWith<$Res>(_self.calendar, (value) {
    return _then(_self.copyWith(calendar: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConnectionsState].
extension ConnectionsStatePatterns on ConnectionsState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConnectionsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConnectionsState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConnectionsState value)  $default,){
final _that = this;
switch (_that) {
case _ConnectionsState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConnectionsState value)?  $default,){
final _that = this;
switch (_that) {
case _ConnectionsState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<GmailConnection> gmailAccounts,  int gmailUsed,  int gmailLimit,  CalendarConnection calendar,  bool autoSync,  bool autoCreateEvents,  double confidenceThreshold)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConnectionsState() when $default != null:
return $default(_that.gmailAccounts,_that.gmailUsed,_that.gmailLimit,_that.calendar,_that.autoSync,_that.autoCreateEvents,_that.confidenceThreshold);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<GmailConnection> gmailAccounts,  int gmailUsed,  int gmailLimit,  CalendarConnection calendar,  bool autoSync,  bool autoCreateEvents,  double confidenceThreshold)  $default,) {final _that = this;
switch (_that) {
case _ConnectionsState():
return $default(_that.gmailAccounts,_that.gmailUsed,_that.gmailLimit,_that.calendar,_that.autoSync,_that.autoCreateEvents,_that.confidenceThreshold);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<GmailConnection> gmailAccounts,  int gmailUsed,  int gmailLimit,  CalendarConnection calendar,  bool autoSync,  bool autoCreateEvents,  double confidenceThreshold)?  $default,) {final _that = this;
switch (_that) {
case _ConnectionsState() when $default != null:
return $default(_that.gmailAccounts,_that.gmailUsed,_that.gmailLimit,_that.calendar,_that.autoSync,_that.autoCreateEvents,_that.confidenceThreshold);case _:
  return null;

}
}

}

/// @nodoc


class _ConnectionsState extends ConnectionsState {
  const _ConnectionsState({required final  List<GmailConnection> gmailAccounts, required this.gmailUsed, required this.gmailLimit, required this.calendar, required this.autoSync, required this.autoCreateEvents, required this.confidenceThreshold}): _gmailAccounts = gmailAccounts,super._();


 final  List<GmailConnection> _gmailAccounts;
@override List<GmailConnection> get gmailAccounts {
  if (_gmailAccounts is EqualUnmodifiableListView) return _gmailAccounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_gmailAccounts);
}

@override final  int gmailUsed;
@override final  int gmailLimit;
@override final  CalendarConnection calendar;
@override final  bool autoSync;
@override final  bool autoCreateEvents;
@override final  double confidenceThreshold;

/// Create a copy of ConnectionsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConnectionsStateCopyWith<_ConnectionsState> get copyWith => __$ConnectionsStateCopyWithImpl<_ConnectionsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConnectionsState&&const DeepCollectionEquality().equals(other._gmailAccounts, _gmailAccounts)&&(identical(other.gmailUsed, gmailUsed) || other.gmailUsed == gmailUsed)&&(identical(other.gmailLimit, gmailLimit) || other.gmailLimit == gmailLimit)&&(identical(other.calendar, calendar) || other.calendar == calendar)&&(identical(other.autoSync, autoSync) || other.autoSync == autoSync)&&(identical(other.autoCreateEvents, autoCreateEvents) || other.autoCreateEvents == autoCreateEvents)&&(identical(other.confidenceThreshold, confidenceThreshold) || other.confidenceThreshold == confidenceThreshold));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_gmailAccounts),gmailUsed,gmailLimit,calendar,autoSync,autoCreateEvents,confidenceThreshold);

@override
String toString() {
  return 'ConnectionsState(gmailAccounts: $gmailAccounts, gmailUsed: $gmailUsed, gmailLimit: $gmailLimit, calendar: $calendar, autoSync: $autoSync, autoCreateEvents: $autoCreateEvents, confidenceThreshold: $confidenceThreshold)';
}


}

/// @nodoc
abstract mixin class _$ConnectionsStateCopyWith<$Res> implements $ConnectionsStateCopyWith<$Res> {
  factory _$ConnectionsStateCopyWith(_ConnectionsState value, $Res Function(_ConnectionsState) _then) = __$ConnectionsStateCopyWithImpl;
@override @useResult
$Res call({
 List<GmailConnection> gmailAccounts, int gmailUsed, int gmailLimit, CalendarConnection calendar, bool autoSync, bool autoCreateEvents, double confidenceThreshold
});


@override $CalendarConnectionCopyWith<$Res> get calendar;

}
/// @nodoc
class __$ConnectionsStateCopyWithImpl<$Res>
    implements _$ConnectionsStateCopyWith<$Res> {
  __$ConnectionsStateCopyWithImpl(this._self, this._then);

  final _ConnectionsState _self;
  final $Res Function(_ConnectionsState) _then;

/// Create a copy of ConnectionsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gmailAccounts = null,Object? gmailUsed = null,Object? gmailLimit = null,Object? calendar = null,Object? autoSync = null,Object? autoCreateEvents = null,Object? confidenceThreshold = null,}) {
  return _then(_ConnectionsState(
gmailAccounts: null == gmailAccounts ? _self._gmailAccounts : gmailAccounts // ignore: cast_nullable_to_non_nullable
as List<GmailConnection>,gmailUsed: null == gmailUsed ? _self.gmailUsed : gmailUsed // ignore: cast_nullable_to_non_nullable
as int,gmailLimit: null == gmailLimit ? _self.gmailLimit : gmailLimit // ignore: cast_nullable_to_non_nullable
as int,calendar: null == calendar ? _self.calendar : calendar // ignore: cast_nullable_to_non_nullable
as CalendarConnection,autoSync: null == autoSync ? _self.autoSync : autoSync // ignore: cast_nullable_to_non_nullable
as bool,autoCreateEvents: null == autoCreateEvents ? _self.autoCreateEvents : autoCreateEvents // ignore: cast_nullable_to_non_nullable
as bool,confidenceThreshold: null == confidenceThreshold ? _self.confidenceThreshold : confidenceThreshold // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of ConnectionsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CalendarConnectionCopyWith<$Res> get calendar {

  return $CalendarConnectionCopyWith<$Res>(_self.calendar, (value) {
    return _then(_self.copyWith(calendar: value));
  });
}
}

/// @nodoc
mixin _$AppResult<T> {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppResult<T>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AppResult<$T>()';
}


}

/// @nodoc
class $AppResultCopyWith<T,$Res>  {
$AppResultCopyWith(AppResult<T> _, $Res Function(AppResult<T>) __);
}


/// Adds pattern-matching-related methods to [AppResult].
extension AppResultPatterns<T> on AppResult<T> {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AppSuccess<T> value)?  success,TResult Function( AppFailure<T> value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AppSuccess() when success != null:
return success(_that);case AppFailure() when failure != null:
return failure(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AppSuccess<T> value)  success,required TResult Function( AppFailure<T> value)  failure,}){
final _that = this;
switch (_that) {
case AppSuccess():
return success(_that);case AppFailure():
return failure(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AppSuccess<T> value)?  success,TResult? Function( AppFailure<T> value)?  failure,}){
final _that = this;
switch (_that) {
case AppSuccess() when success != null:
return success(_that);case AppFailure() when failure != null:
return failure(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( T value)?  success,TResult Function( String message)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AppSuccess() when success != null:
return success(_that.value);case AppFailure() when failure != null:
return failure(_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( T value)  success,required TResult Function( String message)  failure,}) {final _that = this;
switch (_that) {
case AppSuccess():
return success(_that.value);case AppFailure():
return failure(_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( T value)?  success,TResult? Function( String message)?  failure,}) {final _that = this;
switch (_that) {
case AppSuccess() when success != null:
return success(_that.value);case AppFailure() when failure != null:
return failure(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class AppSuccess<T> implements AppResult<T> {
  const AppSuccess(this.value);


 final  T value;

/// Create a copy of AppResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSuccessCopyWith<T, AppSuccess<T>> get copyWith => _$AppSuccessCopyWithImpl<T, AppSuccess<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSuccess<T>&&const DeepCollectionEquality().equals(other.value, value));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'AppResult<$T>.success(value: $value)';
}


}

/// @nodoc
abstract mixin class $AppSuccessCopyWith<T,$Res> implements $AppResultCopyWith<T, $Res> {
  factory $AppSuccessCopyWith(AppSuccess<T> value, $Res Function(AppSuccess<T>) _then) = _$AppSuccessCopyWithImpl;
@useResult
$Res call({
 T value
});




}
/// @nodoc
class _$AppSuccessCopyWithImpl<T,$Res>
    implements $AppSuccessCopyWith<T, $Res> {
  _$AppSuccessCopyWithImpl(this._self, this._then);

  final AppSuccess<T> _self;
  final $Res Function(AppSuccess<T>) _then;

/// Create a copy of AppResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? value = freezed,}) {
  return _then(AppSuccess<T>(
freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as T,
  ));
}


}

/// @nodoc


class AppFailure<T> implements AppResult<T> {
  const AppFailure(this.message);


 final  String message;

/// Create a copy of AppResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppFailureCopyWith<T, AppFailure<T>> get copyWith => _$AppFailureCopyWithImpl<T, AppFailure<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppFailure<T>&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'AppResult<$T>.failure(message: $message)';
}


}

/// @nodoc
abstract mixin class $AppFailureCopyWith<T,$Res> implements $AppResultCopyWith<T, $Res> {
  factory $AppFailureCopyWith(AppFailure<T> value, $Res Function(AppFailure<T>) _then) = _$AppFailureCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$AppFailureCopyWithImpl<T,$Res>
    implements $AppFailureCopyWith<T, $Res> {
  _$AppFailureCopyWithImpl(this._self, this._then);

  final AppFailure<T> _self;
  final $Res Function(AppFailure<T>) _then;

/// Create a copy of AppResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(AppFailure<T>(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$HomeOverview {

 DashboardSummary get summary; List<Commitment> get commitments; ConnectionsState get connections;
/// Create a copy of HomeOverview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HomeOverviewCopyWith<HomeOverview> get copyWith => _$HomeOverviewCopyWithImpl<HomeOverview>(this as HomeOverview, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HomeOverview&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other.commitments, commitments)&&(identical(other.connections, connections) || other.connections == connections));
}


@override
int get hashCode => Object.hash(runtimeType,summary,const DeepCollectionEquality().hash(commitments),connections);

@override
String toString() {
  return 'HomeOverview(summary: $summary, commitments: $commitments, connections: $connections)';
}


}

/// @nodoc
abstract mixin class $HomeOverviewCopyWith<$Res>  {
  factory $HomeOverviewCopyWith(HomeOverview value, $Res Function(HomeOverview) _then) = _$HomeOverviewCopyWithImpl;
@useResult
$Res call({
 DashboardSummary summary, List<Commitment> commitments, ConnectionsState connections
});


$DashboardSummaryCopyWith<$Res> get summary;$ConnectionsStateCopyWith<$Res> get connections;

}
/// @nodoc
class _$HomeOverviewCopyWithImpl<$Res>
    implements $HomeOverviewCopyWith<$Res> {
  _$HomeOverviewCopyWithImpl(this._self, this._then);

  final HomeOverview _self;
  final $Res Function(HomeOverview) _then;

/// Create a copy of HomeOverview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? summary = null,Object? commitments = null,Object? connections = null,}) {
  return _then(_self.copyWith(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as DashboardSummary,commitments: null == commitments ? _self.commitments : commitments // ignore: cast_nullable_to_non_nullable
as List<Commitment>,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as ConnectionsState,
  ));
}
/// Create a copy of HomeOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DashboardSummaryCopyWith<$Res> get summary {

  return $DashboardSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of HomeOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConnectionsStateCopyWith<$Res> get connections {

  return $ConnectionsStateCopyWith<$Res>(_self.connections, (value) {
    return _then(_self.copyWith(connections: value));
  });
}
}


/// Adds pattern-matching-related methods to [HomeOverview].
extension HomeOverviewPatterns on HomeOverview {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HomeOverview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HomeOverview() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HomeOverview value)  $default,){
final _that = this;
switch (_that) {
case _HomeOverview():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HomeOverview value)?  $default,){
final _that = this;
switch (_that) {
case _HomeOverview() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DashboardSummary summary,  List<Commitment> commitments,  ConnectionsState connections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HomeOverview() when $default != null:
return $default(_that.summary,_that.commitments,_that.connections);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DashboardSummary summary,  List<Commitment> commitments,  ConnectionsState connections)  $default,) {final _that = this;
switch (_that) {
case _HomeOverview():
return $default(_that.summary,_that.commitments,_that.connections);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DashboardSummary summary,  List<Commitment> commitments,  ConnectionsState connections)?  $default,) {final _that = this;
switch (_that) {
case _HomeOverview() when $default != null:
return $default(_that.summary,_that.commitments,_that.connections);case _:
  return null;

}
}

}

/// @nodoc


class _HomeOverview implements HomeOverview {
  const _HomeOverview({required this.summary, required final  List<Commitment> commitments, required this.connections}): _commitments = commitments;


@override final  DashboardSummary summary;
 final  List<Commitment> _commitments;
@override List<Commitment> get commitments {
  if (_commitments is EqualUnmodifiableListView) return _commitments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_commitments);
}

@override final  ConnectionsState connections;

/// Create a copy of HomeOverview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HomeOverviewCopyWith<_HomeOverview> get copyWith => __$HomeOverviewCopyWithImpl<_HomeOverview>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HomeOverview&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other._commitments, _commitments)&&(identical(other.connections, connections) || other.connections == connections));
}


@override
int get hashCode => Object.hash(runtimeType,summary,const DeepCollectionEquality().hash(_commitments),connections);

@override
String toString() {
  return 'HomeOverview(summary: $summary, commitments: $commitments, connections: $connections)';
}


}

/// @nodoc
abstract mixin class _$HomeOverviewCopyWith<$Res> implements $HomeOverviewCopyWith<$Res> {
  factory _$HomeOverviewCopyWith(_HomeOverview value, $Res Function(_HomeOverview) _then) = __$HomeOverviewCopyWithImpl;
@override @useResult
$Res call({
 DashboardSummary summary, List<Commitment> commitments, ConnectionsState connections
});


@override $DashboardSummaryCopyWith<$Res> get summary;@override $ConnectionsStateCopyWith<$Res> get connections;

}
/// @nodoc
class __$HomeOverviewCopyWithImpl<$Res>
    implements _$HomeOverviewCopyWith<$Res> {
  __$HomeOverviewCopyWithImpl(this._self, this._then);

  final _HomeOverview _self;
  final $Res Function(_HomeOverview) _then;

/// Create a copy of HomeOverview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? summary = null,Object? commitments = null,Object? connections = null,}) {
  return _then(_HomeOverview(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as DashboardSummary,commitments: null == commitments ? _self._commitments : commitments // ignore: cast_nullable_to_non_nullable
as List<Commitment>,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as ConnectionsState,
  ));
}

/// Create a copy of HomeOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DashboardSummaryCopyWith<$Res> get summary {

  return $DashboardSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of HomeOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConnectionsStateCopyWith<$Res> get connections {

  return $ConnectionsStateCopyWith<$Res>(_self.connections, (value) {
    return _then(_self.copyWith(connections: value));
  });
}
}

/// @nodoc
mixin _$CommitmentsOverview {

 List<Commitment> get commitments; Map<String, String> get emailsByConnection;
/// Create a copy of CommitmentsOverview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommitmentsOverviewCopyWith<CommitmentsOverview> get copyWith => _$CommitmentsOverviewCopyWithImpl<CommitmentsOverview>(this as CommitmentsOverview, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommitmentsOverview&&const DeepCollectionEquality().equals(other.commitments, commitments)&&const DeepCollectionEquality().equals(other.emailsByConnection, emailsByConnection));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(commitments),const DeepCollectionEquality().hash(emailsByConnection));

@override
String toString() {
  return 'CommitmentsOverview(commitments: $commitments, emailsByConnection: $emailsByConnection)';
}


}

/// @nodoc
abstract mixin class $CommitmentsOverviewCopyWith<$Res>  {
  factory $CommitmentsOverviewCopyWith(CommitmentsOverview value, $Res Function(CommitmentsOverview) _then) = _$CommitmentsOverviewCopyWithImpl;
@useResult
$Res call({
 List<Commitment> commitments, Map<String, String> emailsByConnection
});




}
/// @nodoc
class _$CommitmentsOverviewCopyWithImpl<$Res>
    implements $CommitmentsOverviewCopyWith<$Res> {
  _$CommitmentsOverviewCopyWithImpl(this._self, this._then);

  final CommitmentsOverview _self;
  final $Res Function(CommitmentsOverview) _then;

/// Create a copy of CommitmentsOverview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? commitments = null,Object? emailsByConnection = null,}) {
  return _then(_self.copyWith(
commitments: null == commitments ? _self.commitments : commitments // ignore: cast_nullable_to_non_nullable
as List<Commitment>,emailsByConnection: null == emailsByConnection ? _self.emailsByConnection : emailsByConnection // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [CommitmentsOverview].
extension CommitmentsOverviewPatterns on CommitmentsOverview {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommitmentsOverview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommitmentsOverview() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommitmentsOverview value)  $default,){
final _that = this;
switch (_that) {
case _CommitmentsOverview():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommitmentsOverview value)?  $default,){
final _that = this;
switch (_that) {
case _CommitmentsOverview() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Commitment> commitments,  Map<String, String> emailsByConnection)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommitmentsOverview() when $default != null:
return $default(_that.commitments,_that.emailsByConnection);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Commitment> commitments,  Map<String, String> emailsByConnection)  $default,) {final _that = this;
switch (_that) {
case _CommitmentsOverview():
return $default(_that.commitments,_that.emailsByConnection);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Commitment> commitments,  Map<String, String> emailsByConnection)?  $default,) {final _that = this;
switch (_that) {
case _CommitmentsOverview() when $default != null:
return $default(_that.commitments,_that.emailsByConnection);case _:
  return null;

}
}

}

/// @nodoc


class _CommitmentsOverview implements CommitmentsOverview {
  const _CommitmentsOverview({required final  List<Commitment> commitments, required final  Map<String, String> emailsByConnection}): _commitments = commitments,_emailsByConnection = emailsByConnection;


 final  List<Commitment> _commitments;
@override List<Commitment> get commitments {
  if (_commitments is EqualUnmodifiableListView) return _commitments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_commitments);
}

 final  Map<String, String> _emailsByConnection;
@override Map<String, String> get emailsByConnection {
  if (_emailsByConnection is EqualUnmodifiableMapView) return _emailsByConnection;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_emailsByConnection);
}


/// Create a copy of CommitmentsOverview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommitmentsOverviewCopyWith<_CommitmentsOverview> get copyWith => __$CommitmentsOverviewCopyWithImpl<_CommitmentsOverview>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommitmentsOverview&&const DeepCollectionEquality().equals(other._commitments, _commitments)&&const DeepCollectionEquality().equals(other._emailsByConnection, _emailsByConnection));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_commitments),const DeepCollectionEquality().hash(_emailsByConnection));

@override
String toString() {
  return 'CommitmentsOverview(commitments: $commitments, emailsByConnection: $emailsByConnection)';
}


}

/// @nodoc
abstract mixin class _$CommitmentsOverviewCopyWith<$Res> implements $CommitmentsOverviewCopyWith<$Res> {
  factory _$CommitmentsOverviewCopyWith(_CommitmentsOverview value, $Res Function(_CommitmentsOverview) _then) = __$CommitmentsOverviewCopyWithImpl;
@override @useResult
$Res call({
 List<Commitment> commitments, Map<String, String> emailsByConnection
});




}
/// @nodoc
class __$CommitmentsOverviewCopyWithImpl<$Res>
    implements _$CommitmentsOverviewCopyWith<$Res> {
  __$CommitmentsOverviewCopyWithImpl(this._self, this._then);

  final _CommitmentsOverview _self;
  final $Res Function(_CommitmentsOverview) _then;

/// Create a copy of CommitmentsOverview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? commitments = null,Object? emailsByConnection = null,}) {
  return _then(_CommitmentsOverview(
commitments: null == commitments ? _self._commitments : commitments // ignore: cast_nullable_to_non_nullable
as List<Commitment>,emailsByConnection: null == emailsByConnection ? _self._emailsByConnection : emailsByConnection // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

/// @nodoc
mixin _$UserPreferences {

 AppThemeMode get themeMode; bool get notificationsEnabled;
/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserPreferencesCopyWith<UserPreferences> get copyWith => _$UserPreferencesCopyWithImpl<UserPreferences>(this as UserPreferences, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserPreferences&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.notificationsEnabled, notificationsEnabled) || other.notificationsEnabled == notificationsEnabled));
}


@override
int get hashCode => Object.hash(runtimeType,themeMode,notificationsEnabled);

@override
String toString() {
  return 'UserPreferences(themeMode: $themeMode, notificationsEnabled: $notificationsEnabled)';
}


}

/// @nodoc
abstract mixin class $UserPreferencesCopyWith<$Res>  {
  factory $UserPreferencesCopyWith(UserPreferences value, $Res Function(UserPreferences) _then) = _$UserPreferencesCopyWithImpl;
@useResult
$Res call({
 AppThemeMode themeMode, bool notificationsEnabled
});




}
/// @nodoc
class _$UserPreferencesCopyWithImpl<$Res>
    implements $UserPreferencesCopyWith<$Res> {
  _$UserPreferencesCopyWithImpl(this._self, this._then);

  final UserPreferences _self;
  final $Res Function(UserPreferences) _then;

/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeMode = null,Object? notificationsEnabled = null,}) {
  return _then(_self.copyWith(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,notificationsEnabled: null == notificationsEnabled ? _self.notificationsEnabled : notificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UserPreferences].
extension UserPreferencesPatterns on UserPreferences {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserPreferences value)  $default,){
final _that = this;
switch (_that) {
case _UserPreferences():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AppThemeMode themeMode,  bool notificationsEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
return $default(_that.themeMode,_that.notificationsEnabled);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AppThemeMode themeMode,  bool notificationsEnabled)  $default,) {final _that = this;
switch (_that) {
case _UserPreferences():
return $default(_that.themeMode,_that.notificationsEnabled);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AppThemeMode themeMode,  bool notificationsEnabled)?  $default,) {final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
return $default(_that.themeMode,_that.notificationsEnabled);case _:
  return null;

}
}

}

/// @nodoc


class _UserPreferences implements UserPreferences {
  const _UserPreferences({required this.themeMode, required this.notificationsEnabled});


@override final  AppThemeMode themeMode;
@override final  bool notificationsEnabled;

/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserPreferencesCopyWith<_UserPreferences> get copyWith => __$UserPreferencesCopyWithImpl<_UserPreferences>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserPreferences&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.notificationsEnabled, notificationsEnabled) || other.notificationsEnabled == notificationsEnabled));
}


@override
int get hashCode => Object.hash(runtimeType,themeMode,notificationsEnabled);

@override
String toString() {
  return 'UserPreferences(themeMode: $themeMode, notificationsEnabled: $notificationsEnabled)';
}


}

/// @nodoc
abstract mixin class _$UserPreferencesCopyWith<$Res> implements $UserPreferencesCopyWith<$Res> {
  factory _$UserPreferencesCopyWith(_UserPreferences value, $Res Function(_UserPreferences) _then) = __$UserPreferencesCopyWithImpl;
@override @useResult
$Res call({
 AppThemeMode themeMode, bool notificationsEnabled
});




}
/// @nodoc
class __$UserPreferencesCopyWithImpl<$Res>
    implements _$UserPreferencesCopyWith<$Res> {
  __$UserPreferencesCopyWithImpl(this._self, this._then);

  final _UserPreferences _self;
  final $Res Function(_UserPreferences) _then;

/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themeMode = null,Object? notificationsEnabled = null,}) {
  return _then(_UserPreferences(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,notificationsEnabled: null == notificationsEnabled ? _self.notificationsEnabled : notificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
