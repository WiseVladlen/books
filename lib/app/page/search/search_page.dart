import 'dart:async';

import 'package:books/app/app.dart';
import 'package:books/domain/domain.dart';
import 'package:books/presentation/presentation.dart';
import 'package:books/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SearchBloc>(
      create: (BuildContext context) => SearchBloc(
        bookRepository: context.read<IBookRepository>(),
        connectivityService: context.read<IConnectivityService>(),
      ),
      child: const _SearchPageView(),
    );
  }
}

class _SearchPageView extends StatelessWidget {
  const _SearchPageView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _SearchInput(),
        actions: <Widget>[
          IconButton(
            onPressed: () => showSearchFiltersSettingModalBottomSheet(context),
            icon: const Icon(Icons.filter_list),
          ),
        ],
        titleSpacing: 12,
      ),
      body: const _BookList(),
    );
  }
}

class _SearchInput extends StatelessWidget {
  final String _delayedActionKey = (_SearchInput).toString();

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('searchPage_textFieldInput'),
      onChanged: (String value) => DelayedAction(_delayedActionKey).run(() {
        context.read<SearchBloc>().add(SearchQueryChangedEvent(value));
      }),
      style: context.textStyles.appBarTextField,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: context.l10n.searchHint,
        hintStyle: context.textStyles.inputDecorationHint,
        border: InputBorder.none,
      ),
      cursorColor: context.colors.appBarTextFieldPrimary,
    );
  }
}

class _BookList extends StatefulWidget {
  const _BookList();

  @override
  State<_BookList> createState() => _BookListState();
}

class _BookListState extends State<_BookList> {
  static const int _scrollPadding = 100;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (context.read<SearchBloc>().state.requestParameterChanged) _scrollController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();

    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) context.read<SearchBloc>().add(const LoadBooksEvent());
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;

    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double currentScroll = _scrollController.offset;

    return currentScroll >= (maxScroll - _scrollPadding);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final Completer<void> completer = Completer<void>();
        context.read<SearchBloc>().add(RefreshBooksEvent(onComplete: () => completer.complete()));
        await completer.future;
      },
      child: BlocBuilder<SearchBloc, SearchState>(
        buildWhen: (SearchState oldState, SearchState newState) {
          return (oldState.books != newState.books) ||
              (oldState.bookDownloadStatus != newState.bookDownloadStatus) ||
              (oldState.booksHavePeaked != newState.booksHavePeaked);
        },
        builder: (BuildContext context, SearchState state) {
          if (state.bookDownloadStatus.isInProgress) return const LoadingBackground();

          final List<BookModel> books = state.books;

          if (state.isBooksLoadedSuccessfully) {
            return ListView.separated(
              itemBuilder: (BuildContext context, int index) {
                if (index == books.length) return const _BottomLoader();

                final BookModel book = books[index];

                return BookTile.fromModel(
                  key: ValueKey<String>(book.id),
                  model: book,
                );
              },
              separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
              itemCount: state.booksHavePeaked ? books.length : books.length + 1,
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
            );
          }

          return NoResultsBackground(
            icon: state.bookDownloadStatus.isInitial
                ? const Icon(Icons.search, size: 28)
                : const Icon(Icons.question_mark, size: 28),
            text: Text(
              state.bookDownloadStatus.isInitial
                  ? context.l10n.searchBooksMessage
                  : context.l10n.noResultsMessage,
              style: context.textStyles.backgroundLogoMedium,
            ),
          );
        },
      ),
    );
  }
}

class _BottomLoader extends StatelessWidget {
  const _BottomLoader();

  @override
  Widget build(BuildContext context) {
    return UnconstrainedBox(
      child: Transform.scale(
        scale: 0.5,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}
