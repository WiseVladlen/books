import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:books/domain/domain.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'home_event.dart';
part 'home_state.dart';

const String tag = 'HomeBloc';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required this.bookRepository}) : super(const HomeState()) {
    on<LoadBooksEvent>(_loadBooks, transformer: droppable());
    on<SearchQueryChangedEvent>(_searchQueryChanged, transformer: restartable());
    on<RefreshBooksEvent>(_refreshBooks);
  }

  final IBookRepository bookRepository;

  Future<void> _loadBooks(LoadBooksEvent event, Emitter<HomeState> emit) async {
    if (state.booksHavePeaked) return;

    if (state.query.isNotEmpty) {
      final List<BookModel> books = await _runSafely(
        () => bookRepository.getBooks(
          queryParameters: QueryParameters(
            query: state.query,
            startIndex: state.lastBookIndex,
          ),
        ),
        emit: emit,
      );

      bookRepository.upsertBooks(books);

      emit(
        state.copyWith(
          books: <BookModel>[...state.books, ...books],
          bookDownloadStatus: DownloadStatus.success,
          lastBookIndex: state.lastBookIndex + books.length,
          booksHavePeaked: books.length < QueryParameters.pageSize,
          requestParameterChanged: false,
        ),
      );
    }
  }

  Future<void> _searchQueryChanged(SearchQueryChangedEvent event, Emitter<HomeState> emit) async {
    final String query = event.query.trim();

    if (query == state.query) return;

    if (query.isEmpty) {
      return emit(
        state.copyWith(
          query: query,
          books: <BookModel>[],
          bookDownloadStatus: DownloadStatus.initial,
          lastBookIndex: 0,
          booksHavePeaked: false,
          requestParameterChanged: true,
        ),
      );
    }

    emit(
      state.copyWith(
        query: query,
        bookDownloadStatus: DownloadStatus.inProgress,
        requestParameterChanged: true,
      ),
    );

    final List<BookModel> books = await _runSafely(
      () => bookRepository.getBooks(
        queryParameters: QueryParameters(query: query),
      ),
      emit: emit,
    );

    bookRepository.upsertBooks(books);

    emit(
      state.copyWith(
        books: books,
        bookDownloadStatus: DownloadStatus.success,
        lastBookIndex: books.length,
        booksHavePeaked: books.length < QueryParameters.pageSize,
      ),
    );
  }

  Future<void> _refreshBooks(RefreshBooksEvent event, Emitter<HomeState> emit) async {
    if (state.bookDownloadStatus.isInProgress) return;

    if (state.query.isNotEmpty) {
      final List<BookModel> books = await _runSafely(
        () => bookRepository.getBooks(
          queryParameters: QueryParameters(query: state.query),
        ),
        emit: emit,
        onComplete: () => event.onComplete(),
      );

      bookRepository.upsertBooks(books);

      emit(
        state.copyWith(
          books: books,
          lastBookIndex: books.length,
          booksHavePeaked: books.length < QueryParameters.pageSize,
          requestParameterChanged: true,
        ),
      );
    }
  }

  Future<T> _runSafely<T>(
    Future<T> Function() query, {
    required Emitter<HomeState> emit,
    VoidCallback? onComplete,
  }) async {
    try {
      return await query();
    } on DioException catch (error, stack) {
      _handleException(emit: emit, message: tag, error: error, stackTrace: stack);
      rethrow;
    } finally {
      onComplete?.call();
    }
  }

  void _handleException({
    required Emitter<HomeState> emit,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(message, error: error ?? 'Unknown error', stackTrace: stackTrace);
    emit(state.copyWith(bookDownloadStatus: DownloadStatus.failure));
  }
}
