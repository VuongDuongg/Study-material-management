/// Lớp đóng gói kết quả thực thi (Result Pattern)
/// Giúp UI phân biệt rõ ràng giữa thành công (Success) và lỗi (Failure) mà không cần lạm dụng try-catch ở UI
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
        Success<T>(data: final data) => data,
        Failure<T>() => null,
      };

  String? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(message: final message) => message,
      };

  R when<R>({
    required R Function(T data) onSuccess,
    required R Function(String message, Object? exception) onFailure,
  }) {
    return switch (this) {
      Success<T>(data: final data) => onSuccess(data),
      Failure<T>(message: final msg, exception: final err) =>
        onFailure(msg, err),
    };
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  final Object? exception;
  const Failure(this.message, [this.exception]);
}
