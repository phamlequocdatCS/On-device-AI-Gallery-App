import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../gallery_state.dart';
import '../transformers_dart/tokenizer.dart';
import 'main_misc.dart';
import 'more_widgets.dart';

class GallerySearchBar extends StatefulWidget {
  const GallerySearchBar({super.key});

  @override
  State<GallerySearchBar> createState() => _GallerySearchBarState();
}

class _GallerySearchBarState extends State<GallerySearchBar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryState>(
      builder: (context, state, _) {
        Color onSurface = Theme.of(context).colorScheme.onSurface;
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  getSearchField(state, onSurface),
                  getSearchMenu(state, onSurface)
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Expanded getSearchField(GalleryState state, Color onSurface) {
    return Expanded(
      child: TextField(
        controller: _searchController,
        decoration: getSearchFieldDecoration(state, onSurface),
        onChanged: (value) => {
          state.filterImages(value),
        },
        onSubmitted: (value) {
          if (state.currentSearch == SearchTypes.semantic) {
            state.searchSemantic(value);
          }
        },
      ),
    );
  }

  InputDecoration getSearchFieldDecoration(
    GalleryState state,
    Color onSurface,
  ) {
    return InputDecoration(
      labelText: 'Search',
      hintText: getHintText(state),
      prefixIcon: Icon(Icons.search, color: onSurface),
      suffixIcon: getSearchBarSuffix(state, onSurface),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  IntrinsicWidth getSearchBarSuffix(GalleryState state, Color onSurface) {
    return IntrinsicWidth(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          getStyledCounterText(
            _searchController.text,
            state.currentSearch,
            state.tokenizer,
            onSurface,
          ),
          IconButton(
            icon: Icon(Icons.clear, color: onSurface),
            onPressed: () {
              _searchController.clear();
              state.filterImages('');
              setState(() {});
            },
          ),
          if (state.currentSearch == SearchTypes.semantic)
            getSemanticSearchButton(onSurface, state, _searchController.text),
        ],
      ),
    );
  }
}

PopupMenuButton<SearchTypes> getSearchMenu(
  GalleryState state,
  Color onSurface,
) {
  return PopupMenuButton<SearchTypes>(
    icon: Icon(
      getSearchTypeIcon(state.currentSearch),
      color: onSurface,
    ),
    onSelected: state.setSearchType,
    itemBuilder: (_) => getSearchTypeOptions(state.currentSearch),
  );
}

IconButton getSemanticSearchButton(
  Color onSurface,
  GalleryState state,
  String text,
) {
  return IconButton(
    icon: Icon(Icons.search, color: onSurface),
    onPressed: () {
      state.searchSemantic(text);
    },
  );
}

String getHintText(GalleryState state) =>
    'Enter ${SearchTypeManager.getSearchTypeName(state.currentSearch)}';

Widget getStyledCounterText(
  String text,
  SearchTypes currentSearch,
  PreTrainedTokenizer tokenizer,
  Color onSurface,
) {
  double fontSize = 15;
  if (currentSearch == SearchTypes.semantic) {
    int tokenizedLength = getTokenizedLength(text, tokenizer);
    final isExceeded = tokenizedLength > 75;
    return RichTextCounterLimit(
      tokenizedLength: tokenizedLength,
      isExceeded: isExceeded,
      fontSize: fontSize,
      color: onSurface,
    );
  } else {
    return Text(
      "${text.length}",
      style: TextStyle(fontSize: fontSize),
    );
  }
}
