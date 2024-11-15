import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import "database.dart";
import 'gallery_state.dart';
import 'widgets/main_misc.dart';
import 'misc/file_logger.dart';
import 'widgets/search_bar.dart';
import 'widgets/gallery_widget.dart';
import 'widgets/more_widgets.dart';
import 'utility/hive_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ImageMetadataAdapter());
  await openHiveBox();

  await FileLogger.initialize();

  final appDir = await getApplicationDocumentsDirectory();
  await FileLogger.log("AppDir is $appDir");

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  runApp(
    ChangeNotifierProvider(
      create: (context) => GalleryState(scaffoldMessengerKey),
      child: MyApp(scaffoldMessengerKey: scaffoldMessengerKey),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  const MyApp({super.key, required this.scaffoldMessengerKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Gallery App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: MyGalleryApp(scaffoldMessengerKey: scaffoldMessengerKey),
    );
  }
}

class MyGalleryApp extends StatelessWidget {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  const MyGalleryApp({super.key, required this.scaffoldMessengerKey});

  @override
  Widget build(BuildContext context) {
    Color primary = Theme.of(context).colorScheme.primary;
    Color onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Consumer<GalleryState>(builder: (context, state, child) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Gallery App",
              style: TextStyle(
                color: onPrimary,
              )),
          backgroundColor: primary,
          actions: [
            getModelsMenu(state, onPrimary),
            getColumnsMenu(onPrimary, state),
            getWipeButton(
              onPrimary,
              context,
              state,
              scaffoldMessengerKey,
            ),
          ],
        ),
        body: Stack(
          children: [
            const Column(
              children: [
                GallerySearchBar(),
                GalleryWidget(onThumbnailTapped: onThumbnailTapped),
              ],
            ),
            if (state.isLoading) const LoadingScreen()
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => showAddImageOptions(context, scaffoldMessengerKey),
          backgroundColor: primary,
          child: Icon(Icons.add, color: onPrimary),
        ),
      );
    });
  }
}
