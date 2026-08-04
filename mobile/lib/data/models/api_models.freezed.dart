// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UserProfileDto {

 String get id; String get name; String get email; String get accessStatus; String? get avatarUrl;
/// Create a copy of UserProfileDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileDtoCopyWith<UserProfileDto> get copyWith => _$UserProfileDtoCopyWithImpl<UserProfileDto>(this as UserProfileDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfileDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.accessStatus, accessStatus) || other.accessStatus == accessStatus)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,email,accessStatus,avatarUrl);

@override
String toString() {
  return 'UserProfileDto(id: $id, name: $name, email: $email, accessStatus: $accessStatus, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $UserProfileDtoCopyWith<$Res>  {
  factory $UserProfileDtoCopyWith(UserProfileDto value, $Res Function(UserProfileDto) _then) = _$UserProfileDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String email, String accessStatus, String? avatarUrl
});




}
/// @nodoc
class _$UserProfileDtoCopyWithImpl<$Res>
    implements $UserProfileDtoCopyWith<$Res> {
  _$UserProfileDtoCopyWithImpl(this._self, this._then);

  final UserProfileDto _self;
  final $Res Function(UserProfileDto) _then;

/// Create a copy of UserProfileDto
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


/// Adds pattern-matching-related methods to [UserProfileDto].
extension UserProfileDtoPatterns on UserProfileDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfileDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfileDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfileDto value)  $default,){
final _that = this;
switch (_that) {
case _UserProfileDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfileDto value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfileDto() when $default != null:
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
case _UserProfileDto() when $default != null:
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
case _UserProfileDto():
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
case _UserProfileDto() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.accessStatus,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc


class _UserProfileDto implements UserProfileDto {
  const _UserProfileDto({required this.id, required this.name, required this.email, required this.accessStatus, this.avatarUrl});


@override final  String id;
@override final  String name;
@override final  String email;
@override final  String accessStatus;
@override final  String? avatarUrl;

/// Create a copy of UserProfileDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileDtoCopyWith<_UserProfileDto> get copyWith => __$UserProfileDtoCopyWithImpl<_UserProfileDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfileDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.accessStatus, accessStatus) || other.accessStatus == accessStatus)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,email,accessStatus,avatarUrl);

@override
String toString() {
  return 'UserProfileDto(id: $id, name: $name, email: $email, accessStatus: $accessStatus, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$UserProfileDtoCopyWith<$Res> implements $UserProfileDtoCopyWith<$Res> {
  factory _$UserProfileDtoCopyWith(_UserProfileDto value, $Res Function(_UserProfileDto) _then) = __$UserProfileDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String email, String accessStatus, String? avatarUrl
});




}
/// @nodoc
class __$UserProfileDtoCopyWithImpl<$Res>
    implements _$UserProfileDtoCopyWith<$Res> {
  __$UserProfileDtoCopyWithImpl(this._self, this._then);

  final _UserProfileDto _self;
  final $Res Function(_UserProfileDto) _then;

/// Create a copy of UserProfileDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? email = null,Object? accessStatus = null,Object? avatarUrl = freezed,}) {
  return _then(_UserProfileDto(
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
mixin _$AgendaEventDto {

 String get id; String get title; String get description; DateTime get date; bool get allDay; String get googleStatus; String get syncStatus;
/// Create a copy of AgendaEventDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgendaEventDtoCopyWith<AgendaEventDto> get copyWith => _$AgendaEventDtoCopyWithImpl<AgendaEventDto>(this as AgendaEventDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgendaEventDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.date, date) || other.date == date)&&(identical(other.allDay, allDay) || other.allDay == allDay)&&(identical(other.googleStatus, googleStatus) || other.googleStatus == googleStatus)&&(identical(other.syncStatus, syncStatus) || other.syncStatus == syncStatus));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,description,date,allDay,googleStatus,syncStatus);

@override
String toString() {
  return 'AgendaEventDto(id: $id, title: $title, description: $description, date: $date, allDay: $allDay, googleStatus: $googleStatus, syncStatus: $syncStatus)';
}


}

/// @nodoc
abstract mixin class $AgendaEventDtoCopyWith<$Res>  {
  factory $AgendaEventDtoCopyWith(AgendaEventDto value, $Res Function(AgendaEventDto) _then) = _$AgendaEventDtoCopyWithImpl;
@useResult
$Res call({
 String id, String title, String description, DateTime date, bool allDay, String googleStatus, String syncStatus
});




}
/// @nodoc
class _$AgendaEventDtoCopyWithImpl<$Res>
    implements $AgendaEventDtoCopyWith<$Res> {
  _$AgendaEventDtoCopyWithImpl(this._self, this._then);

  final AgendaEventDto _self;
  final $Res Function(AgendaEventDto) _then;

/// Create a copy of AgendaEventDto
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


/// Adds pattern-matching-related methods to [AgendaEventDto].
extension AgendaEventDtoPatterns on AgendaEventDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgendaEventDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgendaEventDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgendaEventDto value)  $default,){
final _that = this;
switch (_that) {
case _AgendaEventDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgendaEventDto value)?  $default,){
final _that = this;
switch (_that) {
case _AgendaEventDto() when $default != null:
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
case _AgendaEventDto() when $default != null:
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
case _AgendaEventDto():
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
case _AgendaEventDto() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.date,_that.allDay,_that.googleStatus,_that.syncStatus);case _:
  return null;

}
}

}

/// @nodoc


class _AgendaEventDto implements AgendaEventDto {
  const _AgendaEventDto({required this.id, required this.title, required this.description, required this.date, required this.allDay, required this.googleStatus, required this.syncStatus});


@override final  String id;
@override final  String title;
@override final  String description;
@override final  DateTime date;
@override final  bool allDay;
@override final  String googleStatus;
@override final  String syncStatus;

/// Create a copy of AgendaEventDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgendaEventDtoCopyWith<_AgendaEventDto> get copyWith => __$AgendaEventDtoCopyWithImpl<_AgendaEventDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgendaEventDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.date, date) || other.date == date)&&(identical(other.allDay, allDay) || other.allDay == allDay)&&(identical(other.googleStatus, googleStatus) || other.googleStatus == googleStatus)&&(identical(other.syncStatus, syncStatus) || other.syncStatus == syncStatus));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,description,date,allDay,googleStatus,syncStatus);

@override
String toString() {
  return 'AgendaEventDto(id: $id, title: $title, description: $description, date: $date, allDay: $allDay, googleStatus: $googleStatus, syncStatus: $syncStatus)';
}


}

/// @nodoc
abstract mixin class _$AgendaEventDtoCopyWith<$Res> implements $AgendaEventDtoCopyWith<$Res> {
  factory _$AgendaEventDtoCopyWith(_AgendaEventDto value, $Res Function(_AgendaEventDto) _then) = __$AgendaEventDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String description, DateTime date, bool allDay, String googleStatus, String syncStatus
});




}
/// @nodoc
class __$AgendaEventDtoCopyWithImpl<$Res>
    implements _$AgendaEventDtoCopyWith<$Res> {
  __$AgendaEventDtoCopyWithImpl(this._self, this._then);

  final _AgendaEventDto _self;
  final $Res Function(_AgendaEventDto) _then;

/// Create a copy of AgendaEventDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? date = null,Object? allDay = null,Object? googleStatus = null,Object? syncStatus = null,}) {
  return _then(_AgendaEventDto(
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
mixin _$CommitmentDto {

 String get id; String get type; String get title; String get description; DateTime get date; double get confidence; String get status; bool get requiresReview; String? get time; String? get emailSubject; String? get connectionId;
/// Create a copy of CommitmentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommitmentDtoCopyWith<CommitmentDto> get copyWith => _$CommitmentDtoCopyWithImpl<CommitmentDto>(this as CommitmentDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommitmentDto&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.date, date) || other.date == date)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.status, status) || other.status == status)&&(identical(other.requiresReview, requiresReview) || other.requiresReview == requiresReview)&&(identical(other.time, time) || other.time == time)&&(identical(other.emailSubject, emailSubject) || other.emailSubject == emailSubject)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,title,description,date,confidence,status,requiresReview,time,emailSubject,connectionId);

@override
String toString() {
  return 'CommitmentDto(id: $id, type: $type, title: $title, description: $description, date: $date, confidence: $confidence, status: $status, requiresReview: $requiresReview, time: $time, emailSubject: $emailSubject, connectionId: $connectionId)';
}


}

/// @nodoc
abstract mixin class $CommitmentDtoCopyWith<$Res>  {
  factory $CommitmentDtoCopyWith(CommitmentDto value, $Res Function(CommitmentDto) _then) = _$CommitmentDtoCopyWithImpl;
@useResult
$Res call({
 String id, String type, String title, String description, DateTime date, double confidence, String status, bool requiresReview, String? time, String? emailSubject, String? connectionId
});




}
/// @nodoc
class _$CommitmentDtoCopyWithImpl<$Res>
    implements $CommitmentDtoCopyWith<$Res> {
  _$CommitmentDtoCopyWithImpl(this._self, this._then);

  final CommitmentDto _self;
  final $Res Function(CommitmentDto) _then;

/// Create a copy of CommitmentDto
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


/// Adds pattern-matching-related methods to [CommitmentDto].
extension CommitmentDtoPatterns on CommitmentDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommitmentDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommitmentDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommitmentDto value)  $default,){
final _that = this;
switch (_that) {
case _CommitmentDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommitmentDto value)?  $default,){
final _that = this;
switch (_that) {
case _CommitmentDto() when $default != null:
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
case _CommitmentDto() when $default != null:
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
case _CommitmentDto():
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
case _CommitmentDto() when $default != null:
return $default(_that.id,_that.type,_that.title,_that.description,_that.date,_that.confidence,_that.status,_that.requiresReview,_that.time,_that.emailSubject,_that.connectionId);case _:
  return null;

}
}

}

/// @nodoc


class _CommitmentDto implements CommitmentDto {
  const _CommitmentDto({required this.id, required this.type, required this.title, required this.description, required this.date, required this.confidence, required this.status, required this.requiresReview, this.time, this.emailSubject, this.connectionId});


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

/// Create a copy of CommitmentDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommitmentDtoCopyWith<_CommitmentDto> get copyWith => __$CommitmentDtoCopyWithImpl<_CommitmentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommitmentDto&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.date, date) || other.date == date)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.status, status) || other.status == status)&&(identical(other.requiresReview, requiresReview) || other.requiresReview == requiresReview)&&(identical(other.time, time) || other.time == time)&&(identical(other.emailSubject, emailSubject) || other.emailSubject == emailSubject)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,title,description,date,confidence,status,requiresReview,time,emailSubject,connectionId);

@override
String toString() {
  return 'CommitmentDto(id: $id, type: $type, title: $title, description: $description, date: $date, confidence: $confidence, status: $status, requiresReview: $requiresReview, time: $time, emailSubject: $emailSubject, connectionId: $connectionId)';
}


}

/// @nodoc
abstract mixin class _$CommitmentDtoCopyWith<$Res> implements $CommitmentDtoCopyWith<$Res> {
  factory _$CommitmentDtoCopyWith(_CommitmentDto value, $Res Function(_CommitmentDto) _then) = __$CommitmentDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String title, String description, DateTime date, double confidence, String status, bool requiresReview, String? time, String? emailSubject, String? connectionId
});




}
/// @nodoc
class __$CommitmentDtoCopyWithImpl<$Res>
    implements _$CommitmentDtoCopyWith<$Res> {
  __$CommitmentDtoCopyWithImpl(this._self, this._then);

  final _CommitmentDto _self;
  final $Res Function(_CommitmentDto) _then;

/// Create a copy of CommitmentDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? title = null,Object? description = null,Object? date = null,Object? confidence = null,Object? status = null,Object? requiresReview = null,Object? time = freezed,Object? emailSubject = freezed,Object? connectionId = freezed,}) {
  return _then(_CommitmentDto(
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
mixin _$DashboardSummaryDto {

 int get daysUsingAgenKin; int get emailsToday; int get totalEmails; int get pendingReviews; int get eventsCreated; String get planName;
/// Create a copy of DashboardSummaryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardSummaryDtoCopyWith<DashboardSummaryDto> get copyWith => _$DashboardSummaryDtoCopyWithImpl<DashboardSummaryDto>(this as DashboardSummaryDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardSummaryDto&&(identical(other.daysUsingAgenKin, daysUsingAgenKin) || other.daysUsingAgenKin == daysUsingAgenKin)&&(identical(other.emailsToday, emailsToday) || other.emailsToday == emailsToday)&&(identical(other.totalEmails, totalEmails) || other.totalEmails == totalEmails)&&(identical(other.pendingReviews, pendingReviews) || other.pendingReviews == pendingReviews)&&(identical(other.eventsCreated, eventsCreated) || other.eventsCreated == eventsCreated)&&(identical(other.planName, planName) || other.planName == planName));
}


@override
int get hashCode => Object.hash(runtimeType,daysUsingAgenKin,emailsToday,totalEmails,pendingReviews,eventsCreated,planName);

@override
String toString() {
  return 'DashboardSummaryDto(daysUsingAgenKin: $daysUsingAgenKin, emailsToday: $emailsToday, totalEmails: $totalEmails, pendingReviews: $pendingReviews, eventsCreated: $eventsCreated, planName: $planName)';
}


}

/// @nodoc
abstract mixin class $DashboardSummaryDtoCopyWith<$Res>  {
  factory $DashboardSummaryDtoCopyWith(DashboardSummaryDto value, $Res Function(DashboardSummaryDto) _then) = _$DashboardSummaryDtoCopyWithImpl;
@useResult
$Res call({
 int daysUsingAgenKin, int emailsToday, int totalEmails, int pendingReviews, int eventsCreated, String planName
});




}
/// @nodoc
class _$DashboardSummaryDtoCopyWithImpl<$Res>
    implements $DashboardSummaryDtoCopyWith<$Res> {
  _$DashboardSummaryDtoCopyWithImpl(this._self, this._then);

  final DashboardSummaryDto _self;
  final $Res Function(DashboardSummaryDto) _then;

/// Create a copy of DashboardSummaryDto
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


/// Adds pattern-matching-related methods to [DashboardSummaryDto].
extension DashboardSummaryDtoPatterns on DashboardSummaryDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DashboardSummaryDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DashboardSummaryDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DashboardSummaryDto value)  $default,){
final _that = this;
switch (_that) {
case _DashboardSummaryDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DashboardSummaryDto value)?  $default,){
final _that = this;
switch (_that) {
case _DashboardSummaryDto() when $default != null:
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
case _DashboardSummaryDto() when $default != null:
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
case _DashboardSummaryDto():
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
case _DashboardSummaryDto() when $default != null:
return $default(_that.daysUsingAgenKin,_that.emailsToday,_that.totalEmails,_that.pendingReviews,_that.eventsCreated,_that.planName);case _:
  return null;

}
}

}

/// @nodoc


class _DashboardSummaryDto implements DashboardSummaryDto {
  const _DashboardSummaryDto({required this.daysUsingAgenKin, required this.emailsToday, required this.totalEmails, required this.pendingReviews, required this.eventsCreated, required this.planName});


@override final  int daysUsingAgenKin;
@override final  int emailsToday;
@override final  int totalEmails;
@override final  int pendingReviews;
@override final  int eventsCreated;
@override final  String planName;

/// Create a copy of DashboardSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DashboardSummaryDtoCopyWith<_DashboardSummaryDto> get copyWith => __$DashboardSummaryDtoCopyWithImpl<_DashboardSummaryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DashboardSummaryDto&&(identical(other.daysUsingAgenKin, daysUsingAgenKin) || other.daysUsingAgenKin == daysUsingAgenKin)&&(identical(other.emailsToday, emailsToday) || other.emailsToday == emailsToday)&&(identical(other.totalEmails, totalEmails) || other.totalEmails == totalEmails)&&(identical(other.pendingReviews, pendingReviews) || other.pendingReviews == pendingReviews)&&(identical(other.eventsCreated, eventsCreated) || other.eventsCreated == eventsCreated)&&(identical(other.planName, planName) || other.planName == planName));
}


@override
int get hashCode => Object.hash(runtimeType,daysUsingAgenKin,emailsToday,totalEmails,pendingReviews,eventsCreated,planName);

@override
String toString() {
  return 'DashboardSummaryDto(daysUsingAgenKin: $daysUsingAgenKin, emailsToday: $emailsToday, totalEmails: $totalEmails, pendingReviews: $pendingReviews, eventsCreated: $eventsCreated, planName: $planName)';
}


}

/// @nodoc
abstract mixin class _$DashboardSummaryDtoCopyWith<$Res> implements $DashboardSummaryDtoCopyWith<$Res> {
  factory _$DashboardSummaryDtoCopyWith(_DashboardSummaryDto value, $Res Function(_DashboardSummaryDto) _then) = __$DashboardSummaryDtoCopyWithImpl;
@override @useResult
$Res call({
 int daysUsingAgenKin, int emailsToday, int totalEmails, int pendingReviews, int eventsCreated, String planName
});




}
/// @nodoc
class __$DashboardSummaryDtoCopyWithImpl<$Res>
    implements _$DashboardSummaryDtoCopyWith<$Res> {
  __$DashboardSummaryDtoCopyWithImpl(this._self, this._then);

  final _DashboardSummaryDto _self;
  final $Res Function(_DashboardSummaryDto) _then;

/// Create a copy of DashboardSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? daysUsingAgenKin = null,Object? emailsToday = null,Object? totalEmails = null,Object? pendingReviews = null,Object? eventsCreated = null,Object? planName = null,}) {
  return _then(_DashboardSummaryDto(
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
mixin _$GmailConnectionDto {

 String get id; String get email; bool get connected; String get status; bool get calendarActive; int get pendingTasks; int get errorTasks; DateTime? get lastReadAt; String? get lastError;
/// Create a copy of GmailConnectionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GmailConnectionDtoCopyWith<GmailConnectionDto> get copyWith => _$GmailConnectionDtoCopyWithImpl<GmailConnectionDto>(this as GmailConnectionDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GmailConnectionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.status, status) || other.status == status)&&(identical(other.calendarActive, calendarActive) || other.calendarActive == calendarActive)&&(identical(other.pendingTasks, pendingTasks) || other.pendingTasks == pendingTasks)&&(identical(other.errorTasks, errorTasks) || other.errorTasks == errorTasks)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.lastError, lastError) || other.lastError == lastError));
}


@override
int get hashCode => Object.hash(runtimeType,id,email,connected,status,calendarActive,pendingTasks,errorTasks,lastReadAt,lastError);

@override
String toString() {
  return 'GmailConnectionDto(id: $id, email: $email, connected: $connected, status: $status, calendarActive: $calendarActive, pendingTasks: $pendingTasks, errorTasks: $errorTasks, lastReadAt: $lastReadAt, lastError: $lastError)';
}


}

/// @nodoc
abstract mixin class $GmailConnectionDtoCopyWith<$Res>  {
  factory $GmailConnectionDtoCopyWith(GmailConnectionDto value, $Res Function(GmailConnectionDto) _then) = _$GmailConnectionDtoCopyWithImpl;
@useResult
$Res call({
 String id, String email, bool connected, String status, bool calendarActive, int pendingTasks, int errorTasks, DateTime? lastReadAt, String? lastError
});




}
/// @nodoc
class _$GmailConnectionDtoCopyWithImpl<$Res>
    implements $GmailConnectionDtoCopyWith<$Res> {
  _$GmailConnectionDtoCopyWithImpl(this._self, this._then);

  final GmailConnectionDto _self;
  final $Res Function(GmailConnectionDto) _then;

/// Create a copy of GmailConnectionDto
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


/// Adds pattern-matching-related methods to [GmailConnectionDto].
extension GmailConnectionDtoPatterns on GmailConnectionDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GmailConnectionDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GmailConnectionDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GmailConnectionDto value)  $default,){
final _that = this;
switch (_that) {
case _GmailConnectionDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GmailConnectionDto value)?  $default,){
final _that = this;
switch (_that) {
case _GmailConnectionDto() when $default != null:
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
case _GmailConnectionDto() when $default != null:
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
case _GmailConnectionDto():
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
case _GmailConnectionDto() when $default != null:
return $default(_that.id,_that.email,_that.connected,_that.status,_that.calendarActive,_that.pendingTasks,_that.errorTasks,_that.lastReadAt,_that.lastError);case _:
  return null;

}
}

}

/// @nodoc


class _GmailConnectionDto implements GmailConnectionDto {
  const _GmailConnectionDto({required this.id, required this.email, required this.connected, required this.status, required this.calendarActive, required this.pendingTasks, required this.errorTasks, this.lastReadAt, this.lastError});


@override final  String id;
@override final  String email;
@override final  bool connected;
@override final  String status;
@override final  bool calendarActive;
@override final  int pendingTasks;
@override final  int errorTasks;
@override final  DateTime? lastReadAt;
@override final  String? lastError;

/// Create a copy of GmailConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GmailConnectionDtoCopyWith<_GmailConnectionDto> get copyWith => __$GmailConnectionDtoCopyWithImpl<_GmailConnectionDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GmailConnectionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.status, status) || other.status == status)&&(identical(other.calendarActive, calendarActive) || other.calendarActive == calendarActive)&&(identical(other.pendingTasks, pendingTasks) || other.pendingTasks == pendingTasks)&&(identical(other.errorTasks, errorTasks) || other.errorTasks == errorTasks)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.lastError, lastError) || other.lastError == lastError));
}


@override
int get hashCode => Object.hash(runtimeType,id,email,connected,status,calendarActive,pendingTasks,errorTasks,lastReadAt,lastError);

@override
String toString() {
  return 'GmailConnectionDto(id: $id, email: $email, connected: $connected, status: $status, calendarActive: $calendarActive, pendingTasks: $pendingTasks, errorTasks: $errorTasks, lastReadAt: $lastReadAt, lastError: $lastError)';
}


}

/// @nodoc
abstract mixin class _$GmailConnectionDtoCopyWith<$Res> implements $GmailConnectionDtoCopyWith<$Res> {
  factory _$GmailConnectionDtoCopyWith(_GmailConnectionDto value, $Res Function(_GmailConnectionDto) _then) = __$GmailConnectionDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String email, bool connected, String status, bool calendarActive, int pendingTasks, int errorTasks, DateTime? lastReadAt, String? lastError
});




}
/// @nodoc
class __$GmailConnectionDtoCopyWithImpl<$Res>
    implements _$GmailConnectionDtoCopyWith<$Res> {
  __$GmailConnectionDtoCopyWithImpl(this._self, this._then);

  final _GmailConnectionDto _self;
  final $Res Function(_GmailConnectionDto) _then;

/// Create a copy of GmailConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? connected = null,Object? status = null,Object? calendarActive = null,Object? pendingTasks = null,Object? errorTasks = null,Object? lastReadAt = freezed,Object? lastError = freezed,}) {
  return _then(_GmailConnectionDto(
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
mixin _$CalendarConnectionDto {

 bool get connected; int get pendingEvents; int get errorEvents; String? get connectionId; String? get email; DateTime? get lastSyncAt;
/// Create a copy of CalendarConnectionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalendarConnectionDtoCopyWith<CalendarConnectionDto> get copyWith => _$CalendarConnectionDtoCopyWithImpl<CalendarConnectionDto>(this as CalendarConnectionDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalendarConnectionDto&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.pendingEvents, pendingEvents) || other.pendingEvents == pendingEvents)&&(identical(other.errorEvents, errorEvents) || other.errorEvents == errorEvents)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.email, email) || other.email == email)&&(identical(other.lastSyncAt, lastSyncAt) || other.lastSyncAt == lastSyncAt));
}


@override
int get hashCode => Object.hash(runtimeType,connected,pendingEvents,errorEvents,connectionId,email,lastSyncAt);

@override
String toString() {
  return 'CalendarConnectionDto(connected: $connected, pendingEvents: $pendingEvents, errorEvents: $errorEvents, connectionId: $connectionId, email: $email, lastSyncAt: $lastSyncAt)';
}


}

/// @nodoc
abstract mixin class $CalendarConnectionDtoCopyWith<$Res>  {
  factory $CalendarConnectionDtoCopyWith(CalendarConnectionDto value, $Res Function(CalendarConnectionDto) _then) = _$CalendarConnectionDtoCopyWithImpl;
@useResult
$Res call({
 bool connected, int pendingEvents, int errorEvents, String? connectionId, String? email, DateTime? lastSyncAt
});




}
/// @nodoc
class _$CalendarConnectionDtoCopyWithImpl<$Res>
    implements $CalendarConnectionDtoCopyWith<$Res> {
  _$CalendarConnectionDtoCopyWithImpl(this._self, this._then);

  final CalendarConnectionDto _self;
  final $Res Function(CalendarConnectionDto) _then;

/// Create a copy of CalendarConnectionDto
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


/// Adds pattern-matching-related methods to [CalendarConnectionDto].
extension CalendarConnectionDtoPatterns on CalendarConnectionDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CalendarConnectionDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CalendarConnectionDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CalendarConnectionDto value)  $default,){
final _that = this;
switch (_that) {
case _CalendarConnectionDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CalendarConnectionDto value)?  $default,){
final _that = this;
switch (_that) {
case _CalendarConnectionDto() when $default != null:
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
case _CalendarConnectionDto() when $default != null:
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
case _CalendarConnectionDto():
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
case _CalendarConnectionDto() when $default != null:
return $default(_that.connected,_that.pendingEvents,_that.errorEvents,_that.connectionId,_that.email,_that.lastSyncAt);case _:
  return null;

}
}

}

/// @nodoc


class _CalendarConnectionDto implements CalendarConnectionDto {
  const _CalendarConnectionDto({required this.connected, required this.pendingEvents, required this.errorEvents, this.connectionId, this.email, this.lastSyncAt});


@override final  bool connected;
@override final  int pendingEvents;
@override final  int errorEvents;
@override final  String? connectionId;
@override final  String? email;
@override final  DateTime? lastSyncAt;

/// Create a copy of CalendarConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CalendarConnectionDtoCopyWith<_CalendarConnectionDto> get copyWith => __$CalendarConnectionDtoCopyWithImpl<_CalendarConnectionDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CalendarConnectionDto&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.pendingEvents, pendingEvents) || other.pendingEvents == pendingEvents)&&(identical(other.errorEvents, errorEvents) || other.errorEvents == errorEvents)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.email, email) || other.email == email)&&(identical(other.lastSyncAt, lastSyncAt) || other.lastSyncAt == lastSyncAt));
}


@override
int get hashCode => Object.hash(runtimeType,connected,pendingEvents,errorEvents,connectionId,email,lastSyncAt);

@override
String toString() {
  return 'CalendarConnectionDto(connected: $connected, pendingEvents: $pendingEvents, errorEvents: $errorEvents, connectionId: $connectionId, email: $email, lastSyncAt: $lastSyncAt)';
}


}

/// @nodoc
abstract mixin class _$CalendarConnectionDtoCopyWith<$Res> implements $CalendarConnectionDtoCopyWith<$Res> {
  factory _$CalendarConnectionDtoCopyWith(_CalendarConnectionDto value, $Res Function(_CalendarConnectionDto) _then) = __$CalendarConnectionDtoCopyWithImpl;
@override @useResult
$Res call({
 bool connected, int pendingEvents, int errorEvents, String? connectionId, String? email, DateTime? lastSyncAt
});




}
/// @nodoc
class __$CalendarConnectionDtoCopyWithImpl<$Res>
    implements _$CalendarConnectionDtoCopyWith<$Res> {
  __$CalendarConnectionDtoCopyWithImpl(this._self, this._then);

  final _CalendarConnectionDto _self;
  final $Res Function(_CalendarConnectionDto) _then;

/// Create a copy of CalendarConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? connected = null,Object? pendingEvents = null,Object? errorEvents = null,Object? connectionId = freezed,Object? email = freezed,Object? lastSyncAt = freezed,}) {
  return _then(_CalendarConnectionDto(
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
mixin _$ConnectionsStateDto {

 List<GmailConnectionDto> get gmailAccounts; int get gmailUsed; int get gmailLimit; CalendarConnectionDto get calendar; bool get autoSync; bool get autoCreateEvents; double get confidenceThreshold;
/// Create a copy of ConnectionsStateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionsStateDtoCopyWith<ConnectionsStateDto> get copyWith => _$ConnectionsStateDtoCopyWithImpl<ConnectionsStateDto>(this as ConnectionsStateDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionsStateDto&&const DeepCollectionEquality().equals(other.gmailAccounts, gmailAccounts)&&(identical(other.gmailUsed, gmailUsed) || other.gmailUsed == gmailUsed)&&(identical(other.gmailLimit, gmailLimit) || other.gmailLimit == gmailLimit)&&(identical(other.calendar, calendar) || other.calendar == calendar)&&(identical(other.autoSync, autoSync) || other.autoSync == autoSync)&&(identical(other.autoCreateEvents, autoCreateEvents) || other.autoCreateEvents == autoCreateEvents)&&(identical(other.confidenceThreshold, confidenceThreshold) || other.confidenceThreshold == confidenceThreshold));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(gmailAccounts),gmailUsed,gmailLimit,calendar,autoSync,autoCreateEvents,confidenceThreshold);

@override
String toString() {
  return 'ConnectionsStateDto(gmailAccounts: $gmailAccounts, gmailUsed: $gmailUsed, gmailLimit: $gmailLimit, calendar: $calendar, autoSync: $autoSync, autoCreateEvents: $autoCreateEvents, confidenceThreshold: $confidenceThreshold)';
}


}

/// @nodoc
abstract mixin class $ConnectionsStateDtoCopyWith<$Res>  {
  factory $ConnectionsStateDtoCopyWith(ConnectionsStateDto value, $Res Function(ConnectionsStateDto) _then) = _$ConnectionsStateDtoCopyWithImpl;
@useResult
$Res call({
 List<GmailConnectionDto> gmailAccounts, int gmailUsed, int gmailLimit, CalendarConnectionDto calendar, bool autoSync, bool autoCreateEvents, double confidenceThreshold
});


$CalendarConnectionDtoCopyWith<$Res> get calendar;

}
/// @nodoc
class _$ConnectionsStateDtoCopyWithImpl<$Res>
    implements $ConnectionsStateDtoCopyWith<$Res> {
  _$ConnectionsStateDtoCopyWithImpl(this._self, this._then);

  final ConnectionsStateDto _self;
  final $Res Function(ConnectionsStateDto) _then;

/// Create a copy of ConnectionsStateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gmailAccounts = null,Object? gmailUsed = null,Object? gmailLimit = null,Object? calendar = null,Object? autoSync = null,Object? autoCreateEvents = null,Object? confidenceThreshold = null,}) {
  return _then(_self.copyWith(
gmailAccounts: null == gmailAccounts ? _self.gmailAccounts : gmailAccounts // ignore: cast_nullable_to_non_nullable
as List<GmailConnectionDto>,gmailUsed: null == gmailUsed ? _self.gmailUsed : gmailUsed // ignore: cast_nullable_to_non_nullable
as int,gmailLimit: null == gmailLimit ? _self.gmailLimit : gmailLimit // ignore: cast_nullable_to_non_nullable
as int,calendar: null == calendar ? _self.calendar : calendar // ignore: cast_nullable_to_non_nullable
as CalendarConnectionDto,autoSync: null == autoSync ? _self.autoSync : autoSync // ignore: cast_nullable_to_non_nullable
as bool,autoCreateEvents: null == autoCreateEvents ? _self.autoCreateEvents : autoCreateEvents // ignore: cast_nullable_to_non_nullable
as bool,confidenceThreshold: null == confidenceThreshold ? _self.confidenceThreshold : confidenceThreshold // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of ConnectionsStateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CalendarConnectionDtoCopyWith<$Res> get calendar {

  return $CalendarConnectionDtoCopyWith<$Res>(_self.calendar, (value) {
    return _then(_self.copyWith(calendar: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConnectionsStateDto].
extension ConnectionsStateDtoPatterns on ConnectionsStateDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConnectionsStateDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConnectionsStateDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConnectionsStateDto value)  $default,){
final _that = this;
switch (_that) {
case _ConnectionsStateDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConnectionsStateDto value)?  $default,){
final _that = this;
switch (_that) {
case _ConnectionsStateDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<GmailConnectionDto> gmailAccounts,  int gmailUsed,  int gmailLimit,  CalendarConnectionDto calendar,  bool autoSync,  bool autoCreateEvents,  double confidenceThreshold)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConnectionsStateDto() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<GmailConnectionDto> gmailAccounts,  int gmailUsed,  int gmailLimit,  CalendarConnectionDto calendar,  bool autoSync,  bool autoCreateEvents,  double confidenceThreshold)  $default,) {final _that = this;
switch (_that) {
case _ConnectionsStateDto():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<GmailConnectionDto> gmailAccounts,  int gmailUsed,  int gmailLimit,  CalendarConnectionDto calendar,  bool autoSync,  bool autoCreateEvents,  double confidenceThreshold)?  $default,) {final _that = this;
switch (_that) {
case _ConnectionsStateDto() when $default != null:
return $default(_that.gmailAccounts,_that.gmailUsed,_that.gmailLimit,_that.calendar,_that.autoSync,_that.autoCreateEvents,_that.confidenceThreshold);case _:
  return null;

}
}

}

/// @nodoc


class _ConnectionsStateDto implements ConnectionsStateDto {
  const _ConnectionsStateDto({required final  List<GmailConnectionDto> gmailAccounts, required this.gmailUsed, required this.gmailLimit, required this.calendar, required this.autoSync, required this.autoCreateEvents, required this.confidenceThreshold}): _gmailAccounts = gmailAccounts;


 final  List<GmailConnectionDto> _gmailAccounts;
@override List<GmailConnectionDto> get gmailAccounts {
  if (_gmailAccounts is EqualUnmodifiableListView) return _gmailAccounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_gmailAccounts);
}

@override final  int gmailUsed;
@override final  int gmailLimit;
@override final  CalendarConnectionDto calendar;
@override final  bool autoSync;
@override final  bool autoCreateEvents;
@override final  double confidenceThreshold;

/// Create a copy of ConnectionsStateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConnectionsStateDtoCopyWith<_ConnectionsStateDto> get copyWith => __$ConnectionsStateDtoCopyWithImpl<_ConnectionsStateDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConnectionsStateDto&&const DeepCollectionEquality().equals(other._gmailAccounts, _gmailAccounts)&&(identical(other.gmailUsed, gmailUsed) || other.gmailUsed == gmailUsed)&&(identical(other.gmailLimit, gmailLimit) || other.gmailLimit == gmailLimit)&&(identical(other.calendar, calendar) || other.calendar == calendar)&&(identical(other.autoSync, autoSync) || other.autoSync == autoSync)&&(identical(other.autoCreateEvents, autoCreateEvents) || other.autoCreateEvents == autoCreateEvents)&&(identical(other.confidenceThreshold, confidenceThreshold) || other.confidenceThreshold == confidenceThreshold));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_gmailAccounts),gmailUsed,gmailLimit,calendar,autoSync,autoCreateEvents,confidenceThreshold);

@override
String toString() {
  return 'ConnectionsStateDto(gmailAccounts: $gmailAccounts, gmailUsed: $gmailUsed, gmailLimit: $gmailLimit, calendar: $calendar, autoSync: $autoSync, autoCreateEvents: $autoCreateEvents, confidenceThreshold: $confidenceThreshold)';
}


}

/// @nodoc
abstract mixin class _$ConnectionsStateDtoCopyWith<$Res> implements $ConnectionsStateDtoCopyWith<$Res> {
  factory _$ConnectionsStateDtoCopyWith(_ConnectionsStateDto value, $Res Function(_ConnectionsStateDto) _then) = __$ConnectionsStateDtoCopyWithImpl;
@override @useResult
$Res call({
 List<GmailConnectionDto> gmailAccounts, int gmailUsed, int gmailLimit, CalendarConnectionDto calendar, bool autoSync, bool autoCreateEvents, double confidenceThreshold
});


@override $CalendarConnectionDtoCopyWith<$Res> get calendar;

}
/// @nodoc
class __$ConnectionsStateDtoCopyWithImpl<$Res>
    implements _$ConnectionsStateDtoCopyWith<$Res> {
  __$ConnectionsStateDtoCopyWithImpl(this._self, this._then);

  final _ConnectionsStateDto _self;
  final $Res Function(_ConnectionsStateDto) _then;

/// Create a copy of ConnectionsStateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gmailAccounts = null,Object? gmailUsed = null,Object? gmailLimit = null,Object? calendar = null,Object? autoSync = null,Object? autoCreateEvents = null,Object? confidenceThreshold = null,}) {
  return _then(_ConnectionsStateDto(
gmailAccounts: null == gmailAccounts ? _self._gmailAccounts : gmailAccounts // ignore: cast_nullable_to_non_nullable
as List<GmailConnectionDto>,gmailUsed: null == gmailUsed ? _self.gmailUsed : gmailUsed // ignore: cast_nullable_to_non_nullable
as int,gmailLimit: null == gmailLimit ? _self.gmailLimit : gmailLimit // ignore: cast_nullable_to_non_nullable
as int,calendar: null == calendar ? _self.calendar : calendar // ignore: cast_nullable_to_non_nullable
as CalendarConnectionDto,autoSync: null == autoSync ? _self.autoSync : autoSync // ignore: cast_nullable_to_non_nullable
as bool,autoCreateEvents: null == autoCreateEvents ? _self.autoCreateEvents : autoCreateEvents // ignore: cast_nullable_to_non_nullable
as bool,confidenceThreshold: null == confidenceThreshold ? _self.confidenceThreshold : confidenceThreshold // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of ConnectionsStateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CalendarConnectionDtoCopyWith<$Res> get calendar {

  return $CalendarConnectionDtoCopyWith<$Res>(_self.calendar, (value) {
    return _then(_self.copyWith(calendar: value));
  });
}
}

// dart format on
