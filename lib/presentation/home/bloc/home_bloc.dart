import 'dart:developer';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:books/domain/model/book_model.dart';
import 'package:books/domain/model/enum/download_status.dart';
import 'package:books/domain/model/query_parameters.dart';
import 'package:books/domain/repository/book_repository.dart';
import 'package:books/presentation/home/bloc/home_event.dart';
import 'package:books/presentation/home/bloc/home_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const String tag = 'HomeBloc';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required this.bookRepository}) : super(const HomeState()) {
    on<LoadBooksEvent>(_loadBooks, transformer: droppable());
    on<SearchQueryChangedEvent>(_searchQueryChanged, transformer: restartable());
    on<RefreshBooksEvent>(_refreshBooks);
  }

  final List<BookModel> errorTemplate = const <BookModel>[];

  final IBookRepository bookRepository;

  Future<void> _loadBooks(LoadBooksEvent event, Emitter<HomeState> emit) async {
    if (state.booksPeaked) return;

    if (state.query.isNotEmpty) {
      final List<BookModel> books = await _runSafely(
        emit,
        () => bookRepository.getBooks(
          queryParameters: QueryParameters(
            query: state.query,
            startIndex: state.lastBookIndex,
          ),
        ),
        onError: () => errorTemplate,
      );

      if (books == errorTemplate) return;

      emit(
        state.copyWith(
          books: <BookModel>[...state.books, ...books],
          bookDownloadStatus: DownloadStatus.success,
          lastBookIndex: state.lastBookIndex + books.length,
          booksPeaked: books.length < QueryParameters.pageSize,
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
          booksPeaked: false,
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
      emit,
      () => bookRepository.getBooks(
        queryParameters: QueryParameters(query: query),
      ),
      onError: () => errorTemplate,
    );

    if (books == errorTemplate) return;

    emit(
      state.copyWith(
        books: books,
        bookDownloadStatus: DownloadStatus.success,
        lastBookIndex: books.length,
        booksPeaked: books.length < QueryParameters.pageSize,
      ),
    );
  }

  Future<void> _refreshBooks(RefreshBooksEvent event, Emitter<HomeState> emit) async {
    if (state.bookDownloadStatus.isInProgress) return;

    if (state.query.isNotEmpty) {
      final List<BookModel> books = await _runSafely(
        emit,
        () => bookRepository.getBooks(
          queryParameters: QueryParameters(query: state.query),
        ),
        onError: () => errorTemplate,
      );

      if (books == errorTemplate) return;

      emit(
        state.copyWith(
          books: books,
          lastBookIndex: books.length,
          booksPeaked: books.length < QueryParameters.pageSize,
          refreshed: true,
          requestParameterChanged: true,
        ),
      );
    }
  }

  T _runSafely<T>(
    Emitter<HomeState> emit,
    T Function() query, {
    required T Function() onError,
  }) {
    try {
      return query();
    } on IOException catch (error, stack) {
      _handleException(emit: emit, message: tag, error: error, stackTrace: stack);
    } on Exception catch (error, stack) {
      _handleException(emit: emit, message: tag, error: error, stackTrace: stack);
    } catch (error, stack) {
      _handleException(
        emit: emit,
        message: '$tag - Unspecified type exception',
        error: error,
        stackTrace: stack,
      );
    }
    return onError();
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
