import 'package:fl_query_hooks/fl_query_hooks.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:platform_ui/platform_ui.dart';
import 'package:spotify/spotify.dart';
import 'package:spotube/components/shared/shimmers/shimmer_playbutton_card.dart';
import 'package:spotube/components/shared/waypoint.dart';
import 'package:spotube/components/playlist/playlist_card.dart';
import 'package:spotube/models/logger.dart';
import 'package:spotube/provider/spotify_provider.dart';
import 'package:spotube/services/queries/queries.dart';

class CategoryCard extends HookConsumerWidget {
  final Category category;
  final Iterable<PlaylistSimple>? playlists;
  CategoryCard(
    this.category, {
    Key? key,
    this.playlists,
  }) : super(key: key);

  final logger = getLogger(CategoryCard);

  @override
  Widget build(BuildContext context, ref) {
    final scrollController = useScrollController();
    final spotify = ref.watch(spotifyProvider);
    final playlistQuery = useInfiniteQuery(
      job: Queries.category.playlistsOf(category.id!),
      externalData: spotify,
    );
    final hasNextPage = playlistQuery.hasNextPage;

    final playlists = playlistQuery.pages
        .expand(
          (page) => page?.items ?? const Iterable.empty(),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              PlatformText.headline(category.name ?? "Unknown"),
            ],
          ),
        ),
        if (playlists.isEmpty &&
            !playlistQuery.hasData &&
            !playlistQuery.hasError)
          const ShimmerPlaybuttonCard(count: 5)
        else if (playlists.isNotEmpty)
          SizedBox(
            height: 245,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
              ),
              child: Scrollbar(
                controller: scrollController,
                interactive: false,
                child: Waypoint(
                  controller: scrollController,
                  onTouchEdge: () async {
                    await playlistQuery.fetchNextPage();
                  },
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    controller: scrollController,
                    children: [
                      ...playlists.map((playlist) => PlaylistCard(playlist)),
                      if (hasNextPage) const ShimmerPlaybuttonCard(count: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (playlistQuery.hasError && playlists.isEmpty)
          PlatformText(
            "Something Went Wrong\n${playlistQuery.errors.first}",
          ),
      ],
    );
  }
}
