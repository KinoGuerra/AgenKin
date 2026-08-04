import 'package:agenkin/core/errors/app_exception.dart';
import 'package:agenkin/domain/models/app_models.dart';

T requireSuccess<T>(AppResult<T> result) {
  return switch (result) {
    AppSuccess<T>(value: final value) => value,
    AppFailure<T>(message: final message) => throw AppException(message),
  };
}
