import 'package:books/domain/model/model.dart';

abstract interface class IBookLocalDataSource {
  Future<void> upsertBooks(List<BookModel> books);

  Future<List<BookModel>> getBooks({required QueryParameters queryParameters});

  Future<void> addBookToFavourites({required int userId, required String bookId});
  Future<void> deleteBookFromFavourites({required int userId, required String bookId});

  Stream<List<BookModel>> getUserBookStream({required int userId});
}
