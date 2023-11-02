import 'package:books/data/database.dart';
import 'package:books/domain/model/model.dart';
import 'package:drift/drift.dart';

extension JoinedSelectStatementMapper on List<TypedResult> {
  /// The current elements of this iterable are converted into a list of books
  Set<BookModel> mapToBooks({required Database database}) {
    final Iterable<BookEntityData> bookEntity = map(
      (TypedResult e) => e.readTable(database.bookEntity),
    );

    final Iterable<AuthorEntityData> authorEntity = map(
      (TypedResult e) => e.readTable(database.authorEntity),
    );

    final Iterable<BookAuthorEntityData> bookAuthorEntity = map(
      (TypedResult e) => e.readTable(database.bookAuthorEntity),
    );

    final Iterable<BookModel> books = bookEntity.map((BookEntityData book) {
      final Iterable<int> authorIds = bookAuthorEntity
          .where((BookAuthorEntityData bookAuthor) => bookAuthor.bookId == book.id)
          .map((BookAuthorEntityData bookAuthor) => bookAuthor.authorId);

      final Iterable<AuthorEntityData> authors = authorEntity.where(
        (AuthorEntityData author) => authorIds.contains(author.id),
      );

      return (book: book, authors: authors).model;
    });

    // FIXME: When using join, books with multiple authors are matched with redundant equivalent entries
    return books.toSet();
  }
}
