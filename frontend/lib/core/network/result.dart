/// A discriminated union for API results.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => isSuccess ? (this as Success<T>).data : null;
  ApiFailure? get failureOrNull =>
      isFailure ? (this as Failure<T>).failure : null;

  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(ApiFailure failure) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final data) => onSuccess(data),
      Failure<T>(:final failure) => onFailure(failure),
    };
  }

  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success<T>(:final data) => Success(transform(data)),
      Failure<T>(:final failure) => Failure(failure),
    };
  }
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final ApiFailure failure;
  const Failure(this.failure);
}

// ── Failure types ──────────────────────────────────────────────────────────

sealed class ApiFailure {
  final String message;
  const ApiFailure(this.message);
}

final class NetworkFailure extends ApiFailure {
  const NetworkFailure(super.message);
}

final class UnauthorizedFailure extends ApiFailure {
  const UnauthorizedFailure(
      [super.message = 'Session expired. Please log in again.']);
}

final class NotFoundFailure extends ApiFailure {
  const NotFoundFailure([super.message = 'Resource not found.']);
}

final class ValidationFailure extends ApiFailure {
  final Map<String, dynamic>? errors;
  const ValidationFailure(super.message, {this.errors});
}

final class RiskRejectedFailure extends ApiFailure {
  const RiskRejectedFailure(super.message);
}

final class LiveTradingDisabledFailure extends ApiFailure {
  const LiveTradingDisabledFailure(
      [super.message = 'Live trading is disabled.']);
}

final class ServerFailure extends ApiFailure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

final class UnknownFailure extends ApiFailure {
  const UnknownFailure([super.message = 'An unexpected error occurred.']);
}
