import 'package:books/domain/model/enum/enum.dart';
import 'package:books/presentation/search_bloc/search_bloc.dart';
import 'package:books/utils/build_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef _SettingsSectionItems<T> = Iterable<({String title, T value})>;

class _SettingsSection<T> extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.groupValue,
    required this.onChanged,
    required this.sectionItems,
  });

  final String title;

  final T groupValue;

  final ValueChanged<T?> onChanged;

  final _SettingsSectionItems<T> sectionItems;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: SizedBox(
            width: double.maxFinite,
            child: Center(
              child: Text(
                title,
                style: context.textStyles.dialogTitle,
              ),
            ),
          ),
        ),
        for (final ({String title, T value}) sectionItem in sectionItems)
          RadioListTile<T>(
            value: sectionItem.value,
            groupValue: groupValue,
            onChanged: onChanged,
            title: Text(sectionItem.title),
          ),
      ],
    );
  }
}

Future<void> showSettingsModalBottomSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(
        left: Radius.circular(12),
        right: Radius.circular(12),
      ),
    ),
    builder: (BuildContext sheetContext) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _SettingsSection<DataSourceType>(
              title: context.l10n.dataSourceTypeHeader,
              groupValue: context.read<SearchBloc>().state.dataSourceType,
              onChanged: (DataSourceType? value) {
                context.read<SearchBloc>().add(DataSourceChangedEvent(value));
                Navigator.pop(context);
              },
              sectionItems: DataSourceType.values.map(
                (DataSourceType dataSourceType) => switch (dataSourceType) {
                  DataSourceType.local => (
                      title: context.l10n.localDataSourceHeader,
                      value: dataSourceType
                    ),
                  DataSourceType.remote => (
                      title: context.l10n.remoteDataSourceHeader,
                      value: dataSourceType
                    ),
                },
              ),
            ),
            const Divider(),
            _SettingsSection<LanguageCode>(
              title: context.l10n.languageHeader,
              groupValue: context.read<SearchBloc>().state.languageCode,
              onChanged: (LanguageCode? value) {
                context.read<SearchBloc>().add(LanguageChangedEvent(value));
                Navigator.pop(context);
              },
              sectionItems: LanguageCode.values.map(
                (LanguageCode languageCode) => (
                  title: languageCode.name.toUpperCase(),
                  value: languageCode,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
