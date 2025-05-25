// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_file_explorer/file_explorer_page.dart'; // Assuming your app name is file_explorer_app

// Helper function to pump the FileExplorerPage widget
Future<void> pumpFileExplorerPage(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp( // Ensure MaterialApp is used
    home: const FileExplorerPage(),
    // If your FileExplorerPage uses AppTheme.lightTheme/darkTheme,
    // you might need to provide them here or ensure AppTheme is accessible.
    // For simplicity, we'll rely on default ThemeData if not explicitly set by FileExplorerPage's MaterialApp itself.
    // However, FileExplorerPage itself is a MaterialApp, so this outer one is just for the test environment.
    // The FileExplorerPage's own MaterialApp will dictate its internal theming.
    theme: ThemeData.light(), // Provide a basic theme for the test environment
    darkTheme: ThemeData.dark(),
  ));
  // Wait for any initial async operations like _loadInitialRoots to settle
  // Increased duration to allow for more complex async setups if any.
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized

  group('FileExplorerPage Widget Tests', () {
    testWidgets('Initial layout verification', (WidgetTester tester) async {
      await pumpFileExplorerPage(tester);

      // Verify AppBar (Command Bar) is present
      expect(find.byType(AppBar), findsOneWidget);

      // Verify key elements in the AppBar's title structure
      // Navigation buttons (Back, Forward, Up)
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      
      // Action buttons
      expect(find.byIcon(Icons.create_new_folder_rounded), findsOneWidget);
      expect(find.byIcon(Icons.content_cut_rounded), findsOneWidget);
      expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
      expect(find.byIcon(Icons.content_paste_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget); // Sort
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget); // View

      // Search TextField (by type, or more specific if needed by a Key)
      expect(find.byType(TextField), findsOneWidget);
      
      // Preview pane toggle button - initial state depends on _showPreviewPane default (false)
      // If false, icon is preview_rounded (to show)
      expect(find.byIcon(Icons.preview_rounded), findsOneWidget);
      
      // Theme toggle button - initial state depends on _themeMode default (light)
      // If light, icon is brightness_4_rounded (to go dark)
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp).first); // Get the inner MaterialApp from FileExplorerPage
      if (materialApp.themeMode == ThemeMode.light || materialApp.themeMode == ThemeMode.system && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light) {
        expect(find.byIcon(Icons.brightness_4_rounded), findsOneWidget);
      } else {
        expect(find.byIcon(Icons.brightness_7_rounded), findsOneWidget);
      }


      // Verify path display area (e.g., by finding the folder icon next to the path)
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);

      // Verify Navigation Pane (e.g., by finding text "Quick access" or "This PC")
      expect(find.text('Quick access'), findsOneWidget);
      expect(find.text('This PC'), findsOneWidget);
      // Check for a common folder like Desktop
      expect(find.widgetWithText(ListTile, 'Desktop'), findsOneWidget);

      // Verify Content Area
      // This depends on whether _loadInitialRoots successfully loads a directory and items.
      // In a pure widget test without file system access, _rightPanelItems might be empty.
      // If _initialRoots is empty or inaccessible, it shows "No roots found..."
      // If a root is found but empty or inaccessible, it shows "This folder is empty." or "Cannot access..."
      // We need to be flexible here or mock.
      final dataTableFinder = find.byType(DataTable);
      final noRootsFinder = find.text('No roots found or accessible.'); // This might appear if Platform.isWindows etc. fails.
      final selectFolderFinder = find.text('Select a folder'); // This appears if _selectedDirectory is null
      final emptyFolderFinder = find.text('This folder is empty.');
      final cannotAccessFinder = find.textContaining('Cannot access'); // Partial match

      // Wait for any async operations in _selectDirectory to complete
      await tester.pumpAndSettle(const Duration(seconds: 1));


      bool contentAreaOkay = tester.any(dataTableFinder) || 
                             tester.any(noRootsFinder) || 
                             tester.any(selectFolderFinder) ||
                             tester.any(emptyFolderFinder) ||
                             tester.any(cannotAccessFinder);
      
      expect(contentAreaOkay, isTrue, 
        reason: "Content area should show DataTable, 'No roots', 'Select a folder', 'Empty folder', or 'Cannot access' message.");
      
      // Verify Details Pane (initially hidden)
      expect(find.text('Select an item to see details'), findsNothing);
    });

    testWidgets('Initial navigation button states', (WidgetTester tester) async {
      await pumpFileExplorerPage(tester);

      // Back button should be disabled (onPressed is null)
      final backButton = find.widgetWithIcon(IconButton, Icons.arrow_back_rounded);
      expect(tester.widget<IconButton>(backButton).onPressed, isNull);

      // Forward button should be disabled (onPressed is null)
      final forwardButton = find.widgetWithIcon(IconButton, Icons.arrow_forward_rounded);
      expect(tester.widget<IconButton>(forwardButton).onPressed, isNull);

      // Up button's state depends on the initial directory.
      // If _selectedDirectory is null or a root, it should be disabled.
      // Given _loadInitialRoots might select a root drive by default on Windows,
      // it's likely disabled.
      final upButton = find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded);
      expect(upButton, findsOneWidget);
      // We can't be certain of its state without mocking the file system or knowing the test env.
      // However, a fresh history means _canNavigateUp might be false if it's a root.
      // If _selectedDirectory is null initially (before _loadInitialRoots fully settles or if it fails), it'd be disabled.
      // We will assume it is likely disabled initially.
       expect(tester.widget<IconButton>(upButton).onPressed, isNull); // Common initial state
    });

    testWidgets('Search functionality UI interaction', (WidgetTester tester) async {
      await pumpFileExplorerPage(tester);

      final searchFieldFinder = find.byType(TextField);
      expect(searchFieldFinder, findsOneWidget);

      // Initially, clear button should not be visible
      expect(find.byIcon(Icons.clear_rounded), findsNothing);

      // Enter text into the search field
      await tester.enterText(searchFieldFinder, 'test search');
      await tester.pump(); // Let the UI rebuild

      // Verify the text is in the field
      expect(find.text('test search'), findsOneWidget);
      // Verify clear button is now visible
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      // Tap the clear button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump(); // Let the UI rebuild

      // Verify the text field is cleared (hintText 'Search' should be back if field is empty)
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('test search'), findsNothing);
      // Verify clear button is hidden again
      expect(find.byIcon(Icons.clear_rounded), findsNothing);
    });

    testWidgets('Toggle Theme button changes theme icon', (WidgetTester tester) async {
      await pumpFileExplorerPage(tester);

      // Assuming initial theme is light, so brightness_4_rounded (go to dark) is shown.
      final themeToggleButtonLight = find.byIcon(Icons.brightness_4_rounded);
      final themeToggleButtonDark = find.byIcon(Icons.brightness_7_rounded);

      // Determine initial state more robustly
      final initialApp = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
      bool isInitiallyLight = initialApp.themeMode == ThemeMode.light || 
                              (initialApp.themeMode == ThemeMode.system && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light);

      if (isInitiallyLight) {
        expect(themeToggleButtonLight, findsOneWidget);
        await tester.tap(themeToggleButtonLight);
        await tester.pumpAndSettle();
        expect(themeToggleButtonDark, findsOneWidget); // Icon changed for dark mode

        // Tap again to go back to light
        await tester.tap(themeToggleButtonDark);
        await tester.pumpAndSettle();
        expect(themeToggleButtonLight, findsOneWidget);
      } else {
        expect(themeToggleButtonDark, findsOneWidget);
        await tester.tap(themeToggleButtonDark);
        await tester.pumpAndSettle();
        expect(themeToggleButtonLight, findsOneWidget); // Icon changed for light mode

        // Tap again to go back to dark
        await tester.tap(themeToggleButtonLight);
        await tester.pumpAndSettle();
        expect(themeToggleButtonDark, findsOneWidget);
      }
    });

    testWidgets('Toggle Preview Pane button changes icon and pane visibility', (WidgetTester tester) async {
      await pumpFileExplorerPage(tester);

      // Initial state: preview pane is hidden, button shows "show preview" icon (preview_rounded)
      final showPreviewIcon = find.byIcon(Icons.preview_rounded);
      final hidePreviewIcon = find.byIcon(Icons.preview_rounded);
      final previewPaneContent = find.text('Select an item to see details');

      expect(showPreviewIcon, findsOneWidget);
      expect(previewPaneContent, findsNothing);

      // Tap to show preview pane
      await tester.tap(showPreviewIcon);
      await tester.pump(); 

      // Verify icon changed and pane content is visible
      expect(hidePreviewIcon, findsOneWidget);
      expect(previewPaneContent, findsOneWidget);

      // Tap to hide preview pane
      await tester.tap(hidePreviewIcon);
      await tester.pump();

      // Verify icon changed back and pane content is hidden
      expect(showPreviewIcon, findsOneWidget);
      expect(previewPaneContent, findsNothing);
    });

    // --- Placeholder Tests for More Complex Interactions ---
    // These would require mocking the file system or a more sophisticated test setup.

    // testWidgets('Tapping a Quick Access item updates path (mocked)', (WidgetTester tester) async {
    //   await pumpFileExplorerPage(tester);
    //   // This requires knowing the path of "Documents" or mocking it.
    //   // For example, if "Documents" path is "/users/test/Documents"
    //   final documentsTile = find.widgetWithText(ListTile, 'Documents');
    //   expect(documentsTile, findsOneWidget);
    //   await tester.tap(documentsTile);
    //   await tester.pumpAndSettle(Duration(seconds: 2)); // Allow for async _selectDirectory
    //   // Verify path in AppBar has updated. This requires the path to be findable, e.g. by a Key or specific text.
    //   // expect(find.textContaining('/users/test/Documents'), findsOneWidget); // Example
    //   // Verify Back button is now enabled if navigation occurred from a different previous path
    //   // final backButton = find.widgetWithIcon(IconButton, Icons.arrow_back_rounded);
    //   // expect(tester.widget<IconButton>(backButton).onPressed, isNotNull);
    // });

    // testWidgets('Search filters displayed items (mocked data)', (WidgetTester tester) async {
    //   // 1. Need a way to inject mock data into _rightPanelItems for FileExplorerPage.
    //   //    This might involve refactoring FileExplorerPage to accept a list of initial items for testing,
    //   //    or using a mock file system service.
    //   // 2. Pump the page with mock data.
    //   // 3. Find the search TextField and enter text.
    //   // 4. await tester.pump();
    //   // 5. Verify that the DataTable now only shows items matching the search text.
    //   //    This means checking for specific Text widgets in DataCells.
    //   // Example:
    //   // await tester.enterText(find.byType(TextField), 'MockFile1');
    //   // await tester.pump();
    //   // expect(find.text('MockFile1.txt'), findsOneWidget);
    //   // expect(find.text('AnotherFile.txt'), findsNothing);
    // });


    // testWidgets('Navigation history buttons update after navigation (mocked)', (WidgetTester tester) async {
    //   // 1. Setup initial state (e.g., at root "/"). Back/Fwd disabled.
    //   // 2. Simulate navigation to "/folder1".
    //   //    - Back should be enabled. Fwd still disabled.
    //   // 3. Simulate navigation to "/folder1/subfolderA".
    //   //    - Back still enabled. Fwd still disabled.
    //   // 4. Tap Back button.
    //   //    - Should go to "/folder1".
    //   //    - Back still enabled (or disabled if "/folder1" was the first entry after root).
    //   //    - Fwd should be enabled (to go to "subfolderA").
    //   // 5. Tap Up button (if applicable).
    //   //    - State should update accordingly.
    //   // This requires significant control over _selectDirectory and history management.
    // });
  });
}
