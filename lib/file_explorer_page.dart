import 'dart:io';
import 'dart:ui'; // Required for ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p; // For path manipulation (add path package to pubspec.yaml)

// Centralized Theme Configuration
class AppTheme {
  static final BorderRadius _borderRadius = BorderRadius.circular(8.0); // Consistent rounded corners

  static ThemeData _baseTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue, // Windows 11 accent blue
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Segoe UI', // Ensure this font is available or use a system fallback in MaterialApp
      scaffoldBackgroundColor: isLight ? Colors.grey[100] : Colors.grey[900]?.withOpacity(0.95), // Subtle background
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface.withOpacity(0.7), // Acrylic effect base
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent, // Important for M3 transparency
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          fontFamily: 'Segoe UI',
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0, // Flat design, shadows can be added subtly if needed
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
        color: colorScheme.surfaceVariant.withOpacity(isLight ? 0.6 : 0.4), // Acrylic-like card
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // Default card margin
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
        backgroundColor: colorScheme.surface.withOpacity(0.85), // More opaque for readability
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
        selectedTileColor: colorScheme.primaryContainer.withOpacity(0.4),
        iconColor: colorScheme.onSurfaceVariant,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: _borderRadius),
          padding: const EdgeInsets.all(10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: _borderRadius),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Increased vertical padding
        ),
      ),
      dataTableTheme: DataTableThemeData(
        dataRowColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primaryContainer.withOpacity(0.3);
          }
          return null; // Default for transparent rows, allowing Card background to show
        }),
        headingRowColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          return colorScheme.surfaceVariant.withOpacity(isLight ? 0.3 : 0.2);
        }),
        dividerThickness: 1,
        dataTextStyle: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, fontFamily: 'Segoe UI'),
        headingTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface, fontFamily: 'Segoe UI'),
        horizontalMargin: 12,
        columnSpacing: 20,
        headingRowHeight: 40,
        dataRowMinHeight: 38,
        dataRowMaxHeight: 42,
        decoration: BoxDecoration(borderRadius: _borderRadius), // Rounded corners for DataTable area
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(fontFamily: 'Segoe UI', fontSize: 13.5, color: colorScheme.onSurface),
        labelLarge: TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.w500, color: colorScheme.onSurface),
        titleSmall: TextStyle(fontFamily: 'Segoe UI', fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      dividerColor: colorScheme.outline.withOpacity(0.5),
      tooltipTheme: TooltipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withOpacity(0.85),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
      ),
    );
  }

  static ThemeData get lightTheme => _baseTheme(Brightness.light);
  static ThemeData get darkTheme => _baseTheme(Brightness.dark);
}


class FileExplorerPage extends StatefulWidget {
  const FileExplorerPage({super.key});

  @override
  State<FileExplorerPage> createState() => _FileExplorerPageState();
}

class _FileExplorerPageState extends State<FileExplorerPage> {
  Directory? _selectedDirectory;
  List<FileSystemEntity> _rightPanelItems = []; // All items in the current directory
  List<FileSystemEntity> _displayedItems = []; // Items to display (filtered or all)
  List<Directory> _initialRoots = [];
  bool _isLoadingRoots = true;
  bool _showPreviewPane = false;
  FileSystemEntity? _selectedFile;
  ThemeMode _themeMode = ThemeMode.light;

  // Navigation history
  final List<Directory> _history = [];
  int _historyIndex = -1;
  bool _isNavigatingHistory = false; // Flag to prevent history modification during back/forward

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    _loadInitialRoots();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Check if the current text is different from the state's _searchText
    // to prevent potential loops if setState itself triggers the listener indirectly.
    if (_searchText != _searchController.text) {
      setState(() {
        _searchText = _searchController.text;
        _filterDisplayedItems();
      });
    }
  }

  void _filterDisplayedItems() {
    if (_searchText.isEmpty) {
      _displayedItems = List.from(_rightPanelItems);
    } else {
      _displayedItems = _rightPanelItems
          .where((item) =>
              p.basename(item.path).toLowerCase().contains(_searchText.toLowerCase()))
          .toList();
    }
  }

  Future<void> _loadInitialRoots() async {
    setState(() {
      _isLoadingRoots = true;
    });
    List<Directory> roots = [];
    try {
      if (Platform.isWindows) {
        // Iterate through common drive letters for Windows
        for (var i = 'A'.codeUnitAt(0); i <= 'Z'.codeUnitAt(0); i++) {
          final letter = String.fromCharCode(i);
          final drivePath = '$letter:\\';
          final driveDir = Directory(drivePath);
          try {
            if (await driveDir.exists()) {
              roots.add(driveDir);
            }
          } catch (e) {
            // Log error for specific drive but continue
            print("Error checking drive ${drivePath}: $e");
          }
        }
        // Fallback for Windows if no drives found by letter iteration
        if (roots.isEmpty) {
          String? userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null && userProfile.isNotEmpty) {
            final userDir = Directory(userProfile);
            if (await userDir.exists()) roots.add(userDir);
          }
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        String? homePath = Platform.environment['HOME'];
        if (homePath != null && homePath.isNotEmpty) {
          final homeDir = Directory(homePath);
          if (await homeDir.exists()) {
            roots.add(homeDir);
          }
        }
        // Optionally, add other common roots like '/' if desired, but be cautious with permissions and performance.
        // final rootDir = Directory('/');
        // if (await rootDir.exists()) roots.add(rootDir);
      }

      if (roots.isEmpty) {
        final currentDir = Directory.current;
        if (await currentDir.exists()) {
          roots.add(currentDir);
        }
      }
    } catch (e) {
      print("Error loading initial roots: $e");
      // Fallback to current directory if other methods fail
      if (roots.isEmpty) {
        final currentDir = Directory.current;
         if (await currentDir.exists()) {
          roots.add(currentDir);
        }
      }
    }

    setState(() {
      _initialRoots = roots;
      _isLoadingRoots = false;
      if (_initialRoots.isNotEmpty) {
        _selectDirectory(_initialRoots.first, fromHistory: false);
      }
    });
  }

  Future<void> _selectDirectory(Directory directory, {bool fromHistory = false}) async {
    if (_isNavigatingHistory && !fromHistory) {
      _isNavigatingHistory = false;
    }

    if (!fromHistory && !_isNavigatingHistory) {
      if (_historyIndex < _history.length - 1) {
        _history.removeRange(_historyIndex + 1, _history.length);
      }
      if (_history.isEmpty || _history.last.path != directory.path) {
        _history.add(directory);
        _historyIndex = _history.length - 1;
      } else if (_history.isNotEmpty && _history.last.path == directory.path) {
        _historyIndex = _history.length - 1; // Ensure index is correct if re-selecting current
      }
       // When a new directory is selected NOT from history, clear the search field.
      _searchController.clear(); // This will trigger _onSearchChanged -> _filterDisplayedItems
    }
    
    _selectedFile = null; // Clear file selection in preview pane on any directory change

    try {
      if (!await directory.exists()) {
        setState(() {
          _selectedDirectory = directory;
          _rightPanelItems = [];
          _filterDisplayedItems();
          // _updateButtonStates(); // Implicitly handled by setState
        });
        print("Directory does not exist: \\${directory.path}");
        return;
      }

      final Stream<FileSystemEntity> itemsStream = directory.list();
      final List<FileSystemEntity> items = [];
      await for (final item in itemsStream) {
        items.add(item);
      }
      items.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
      });

      setState(() {
        _selectedDirectory = directory;
        _rightPanelItems = items;
        _filterDisplayedItems(); // Apply current search text or show all
        // _updateButtonStates(); // Implicitly handled by setState
      });
    } catch (e) {
      print("Error listing directory \\${directory.path}: \\$e");
      setState(() {
        _selectedDirectory = directory;
        _rightPanelItems = [];
        _filterDisplayedItems();
        // _updateButtonStates(); // Implicitly handled by setState
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access: \\${p.basename(directory.path)}. Permission denied?')),
      );
    }
  }

  // Navigation methods
  bool _canNavigateBack() => _historyIndex > 0;
  bool _canNavigateForward() => _historyIndex < _history.length - 1;
  bool _canNavigateUp() {
    if (_selectedDirectory == null) return false;
    try {
      Directory parent = _selectedDirectory!.parent;
      return parent.path != _selectedDirectory!.path && parent.existsSync();
    } catch (e) {
      return false;
    }
  }

  void _navigateBack() {
    if (_canNavigateBack()) {
      _isNavigatingHistory = true;
      _historyIndex--;
      _selectDirectory(_history[_historyIndex], fromHistory: true);
      // _isNavigatingHistory will be reset if user makes a new selection,
      // or should be reset after operation if we are sure no new selection can interrupt.
      // For safety, _selectDirectory handles resetting it on non-history navigation.
      // After history navigation, it's fine for it to remain true until next non-history action.
      setState(() {}); // To update button states
    }
  }

  void _navigateForward() {
    if (_canNavigateForward()) {
      _isNavigatingHistory = true;
      _historyIndex++;
      _selectDirectory(_history[_historyIndex], fromHistory: true);
      setState(() {}); // To update button states
    }
  }

  void _navigateUp() {
    if (_selectedDirectory != null && _canNavigateUp()) {
      try {
        Directory parentDir = _selectedDirectory!.parent;
        _selectDirectory(parentDir, fromHistory: false); // Navigating up starts a new history branch
      } catch (e) {
        print("Error navigating up: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot navigate up from this location.')),
        );
      }
    }
  }

  Future<List<Directory>> _getSubDirectories(Directory dir) async {
    List<Directory> subDirs = [];
    try {
      if (!await dir.exists()) return [];
      await for (var entity in dir.list(followLinks: false)) { // followLinks: false to avoid issues
        if (entity is Directory) {
          subDirs.add(entity);
        }
      }
      subDirs.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
    } catch (e) {
      print("Error getting subdirectories for ${dir.path}: $e");
    }
    return subDirs;
  }

  // _buildDirectoryTree is removed as it's replaced by _buildNavigationPane

  Future<Map<String, dynamic>> _getFileDetails(FileSystemEntity file) async {
    try {
      final isImage = file is File && ['.jpg', '.jpeg', '.png', '.gif'].contains(p.extension(file.path).toLowerCase());
      final isVideo = file is File && ['.mp4', '.avi', '.mov'].contains(p.extension(file.path).toLowerCase());
      final size = file is File ? await file.length() : 0;
      final created = file is File ? await file.stat().then((stat) => stat.changed) : null;
      return {
        'name': p.basename(file.path),
        'size': size,
        'created': created?.toLocal().toString() ?? 'Unknown',
        'isImage': isImage,
        'isVideo': isVideo,
      };
    } catch (e) {
      print("Error fetching file details for \\${file.path}: \\$e");
      return {
        'name': p.basename(file.path),
        'size': 'Access Denied',
        'created': 'Access Denied',
        'isImage': false,
        'isVideo': false,
        'error': e.toString(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter File Explorer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size(double.infinity, 88), // Standard height for command bar + path
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: <Widget>[
                          _buildCommandBarButton(Icons.arrow_back_rounded, 'Back', _canNavigateBack() ? _navigateBack : null, isNavButton: true),
                          _buildCommandBarButton(Icons.arrow_forward_rounded, 'Forward', _canNavigateForward() ? _navigateForward : null, isNavButton: true),
                          _buildCommandBarButton(Icons.arrow_upward_rounded, 'Up', _canNavigateUp() ? _navigateUp : null, isNavButton: true),
                          const SizedBox(width: 8),

                          _buildCommandBarButton(Icons.create_new_folder_rounded, 'New', () { /* TODO */ }),
                          _buildCommandBarButton(Icons.content_cut_rounded, 'Cut', () { /* TODO */ }),
                          _buildCommandBarButton(Icons.content_copy_rounded, 'Copy', () { /* TODO */ }),
                          _buildCommandBarButton(Icons.content_paste_rounded, 'Paste', () { /* TODO */ }),
                          _buildCommandBarButton(Icons.share_rounded, 'Share', () { /* TODO */ }),
                          _buildCommandBarButton(Icons.delete_rounded, 'Delete', () { /* TODO */ }),
                          const VerticalDivider(indent: 8, endIndent: 8),
                          _buildCommandBarButton(Icons.swap_vert_rounded, 'Sort', () {
                            setState(() {
                              _rightPanelItems.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
                              _filterDisplayedItems(); // Re-apply filter after sort
                            });
                          }),
                          _buildCommandBarButton(Icons.grid_view_rounded, 'View', () { /* TODO */ }),
                          
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: SizedBox(
                                height: 36, // Standard height for text fields in command bars
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                                  decoration: InputDecoration(
                                    hintText: 'Search',
                                    hintStyle: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)),
                                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    suffixIcon: _searchText.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(Icons.clear_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            onPressed: () => _searchController.clear(), // Listener will handle the rest
                                            splashRadius: 18,
                                          )
                                        : null,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                                    border: OutlineInputBorder(borderRadius: AppTheme._borderRadius, borderSide: BorderSide.none),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: AppTheme._borderRadius,
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // const Spacer(), // Removed to allow search bar to expand more
                          _buildCommandBarButton(
                            _showPreviewPane ? Icons.preview_rounded : Icons.preview_rounded,
                            _showPreviewPane ? 'Hide preview' : 'Show preview',
                            () => setState(() => _showPreviewPane = !_showPreviewPane),
                          ),
                          _buildCommandBarButton(
                            _themeMode == ThemeMode.light ? Icons.brightness_4_rounded : Icons.brightness_7_rounded,
                            'Toggle Theme',
                            () => setState(() => _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 6.0),
                      child: Row(
                        children: [
                          Icon(Icons.folder_open_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                _selectedDirectory?.path ?? "This PC",
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 88 + 8, left: 6, right: 6, bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 240,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: _buildNavigationPane(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: _selectedDirectory == null
                        ? Center(child: Text('Select a folder', style: Theme.of(context).textTheme.bodyMedium))
                        : FutureBuilder(
                            future: _selectedDirectory!.exists(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.data == false) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, size: 52),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Cannot access "${p.basename(_selectedDirectory!.path)}".',
                                          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16.5),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'The folder may have been moved, renamed, or you may not have sufficient permissions.',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Path: ${_selectedDirectory!.path}',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 11.5),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              if (_rightPanelItems.isEmpty) {
                                return Center(
                                  child: Text(
                                    'This folder is empty.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                );
                              }
                              return SingleChildScrollView(
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  columns: const [
                                    DataColumn(label: Text('Name')),
                                    DataColumn(label: Text('Date modified')),
                                    DataColumn(label: Text('Type')),
                                    DataColumn(label: Text('Size')),
                                  ],
                                  rows: _displayedItems.map((entity) { // Use _displayedItems
                                    final isDir = entity is Directory;
                                    FileStat? stat;
                                    try { stat = entity.statSync(); } catch (e) { /* Ignored */ }
                                    return DataRow(
                                      selected: _selectedFile?.path == entity.path,
                                      onSelectChanged: (selected) => setState(() => _selectedFile = (selected ?? false) ? entity : null),
                                      cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              Icon(
                                                isDir ? Icons.folder_rounded : _getIconForFileType(p.extension(entity.path)),
                                                color: isDir ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(child: Text(p.basename(entity.path), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                          onTap: () {
                                            setState(() => _selectedFile = entity);
                                            if (isDir) { /* _selectDirectory(entity); // Consider double tap for navigation */ }
                                          },
                                        ),
                                        DataCell(Text(stat != null ? stat.modified.toLocal().toString().substring(0, 16) : 'N/A')),
                                        DataCell(Text(isDir ? 'File folder' : _getFileTypeDescription(p.extension(entity.path)))),
                                        DataCell(Text(isDir ? '' : (stat != null && entity is File ? '${(entity.lengthSync() / 1024).toStringAsFixed(1)} KB' : 'N/A'))),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
              if (_showPreviewPane) const SizedBox(width: 6),
              if (_showPreviewPane)
                SizedBox(
                  width: 280,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _selectedFile == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_rounded, size: 52, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  Text('Select an item to see details', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            )
                          : FutureBuilder<Map<String, dynamic>>(
                              future: _getFileDetails(_selectedFile!),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                final hasError = snapshot.data?['error'] != null && snapshot.data!['error'] != 'Access Denied';
                                if (!snapshot.hasData || hasError) {
                                  return Center(child: Text('Error: ${snapshot.data?['error'] ?? 'Could not load details'}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)));
                                }
                                final details = snapshot.data!;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (details['isImage'] == true && _selectedFile is File)
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: AppTheme._borderRadius,
                                          child: Image.file(File(_selectedFile!.path), fit: BoxFit.contain,
                                            errorBuilder: (c, e, st) => Center(child: Text('Could not load preview', style: Theme.of(context).textTheme.bodyMedium)),
                                          ),
                                        ),
                                      )
                                    else if (details['isVideo'] == true && _selectedFile is File)
                                      Expanded(
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [Icon(Icons.movie_filter_rounded, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(height: 8), Text('Video Preview', style: Theme.of(context).textTheme.bodyMedium)],
                                          ),
                                        ),
                                      )
                                    else
                                      Expanded(
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _selectedFile is Directory ? Icons.folder_rounded : _getIconForFileType(p.extension(_selectedFile!.path)),
                                                size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(height: 10),
                                              Text(_selectedFile is Directory ? 'Folder' : 'No preview available', style: Theme.of(context).textTheme.bodyMedium),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const Divider(height: 24),
                                    Text(details['name'] ?? 'Unknown', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15.5)),
                                    const SizedBox(height: 12),
                                    Text('Type: ${_getFileTypeDescription(p.extension(_selectedFile!.path))}', style: Theme.of(context).textTheme.bodyMedium),
                                    const SizedBox(height: 6),
                                    Text('Date modified: ${details['created'] ?? 'Unknown'}', style: Theme.of(context).textTheme.bodyMedium),
                                    const SizedBox(height: 6),
                                    if (_selectedFile is File)
                                      Text('Size: ${details['size'] == 'Access Denied' ? 'N/A' : ((details['size'] ?? 0) / 1024).toStringAsFixed(1) + ' KB'}', style: Theme.of(context).textTheme.bodyMedium),
                                    if (details['error'] == 'Access Denied')
                                       Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text('Details: Access Denied', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
                                      ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommandBarButton(IconData icon, String tooltip, VoidCallback? onPressed, {bool isNavButton = false}) {
    // For nav buttons, reduce horizontal padding slightly if needed, or use a specific style
    final double hPadding = isNavButton ? 0.5 : 1.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPadding),
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        splashRadius: 20,
        padding: const EdgeInsets.all(8),
        disabledColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
      ),
    );
  }

  Widget _buildNavigationPane() {
    final commonFolders = [
      {'name': 'Desktop', 'icon': Icons.desktop_windows_rounded},
      {'name': 'Documents', 'icon': Icons.folder_shared_rounded},
      {'name': 'Downloads', 'icon': Icons.file_download_rounded},
      {'name': 'Pictures', 'icon': Icons.photo_library_rounded},
      {'name': 'Music', 'icon': Icons.music_note_rounded},
      {'name': 'Videos', 'icon': Icons.video_library_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 6.0),
          child: Text("Quick access", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              ...commonFolders.map((folder) => ListTile(
                leading: Icon(folder['icon'] as IconData, size: 20),
                title: Text(folder['name'] as String, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Navigate to ${folder['name']}'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: AppTheme._borderRadius),
                      backgroundColor: Theme.of(context).colorScheme.inverseSurface,
                      //contentTextStyle: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface),
                    ),
                  );
                },
              )),
              const Divider(height: 16, indent: 8, endIndent: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 6.0),
                child: Text("This PC", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              if (_isLoadingRoots)
                const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 3)))
              else if (_initialRoots.isEmpty)
                ListTile(title: Text('No drives found.', style: Theme.of(context).textTheme.bodyMedium))
              else
                ..._initialRoots.map((root) => _buildDriveTile(root)).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriveTile(Directory dir) {
    String displayName = p.basename(dir.path);
    if (displayName.isEmpty && dir.path.isNotEmpty) {
        displayName = dir.path;
    }
    if (Platform.isWindows && displayName.length == 2 && displayName.endsWith(':')) {
        displayName = 'Local Disk (${displayName[0]}:)';
    }
    return ListTile(
      leading: const Icon(Icons.storage_rounded, size: 20),
      title: Text(displayName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
      onTap: () => _selectDirectory(dir, fromHistory: false), // Navigating from pane is a new action
      selected: _selectedDirectory?.path == dir.path,
    );
  }

  IconData _getIconForFileType(String extension) {
    switch (extension.toLowerCase()) {
      case '.txt': return Icons.article_rounded;
      case '.pdf': return Icons.picture_as_pdf_rounded;
      case '.doc': case '.docx': return Icons.description_rounded;
      case '.xls': case '.xlsx': return Icons.table_chart_rounded;
      case '.ppt': case '.pptx': return Icons.slideshow_rounded;
      case '.zip': case '.rar': return Icons.archive_rounded;
      case '.jpg': case '.jpeg': case '.png': case '.gif': return Icons.image_rounded;
      case '.mp3': case '.wav': return Icons.audiotrack_rounded;
      case '.mp4': case '.avi': case '.mov': return Icons.movie_creation_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  String _getFileTypeDescription(String extension) {
    switch (extension.toLowerCase()) {
      case '.txt': return 'Text Document';
      case '.pdf': return 'PDF Document';
      case '.doc': case '.docx': return 'Microsoft Word Document';
      case '.xls': case '.xlsx': return 'Microsoft Excel Spreadsheet';
      case '.ppt': case '.pptx': return 'Microsoft PowerPoint Presentation';
      case '.zip': return 'Compressed ZIP Archive';
      case '.rar': return 'Compressed RAR Archive';
      case '.jpg': case '.jpeg': return 'JPEG Image';
      case '.png': return 'PNG Image';
      case '.gif': return 'GIF Image';
      case '.mp3': return 'MP3 Audio File';
      case '.wav': return 'WAV Audio File';
      case '.mp4': return 'MP4 Video File';
      case '.avi': return 'AVI Video File';
      case '.mov': return 'QuickTime Movie File';
      case '.exe': return 'Application';
      case '.dll': return 'System File';
      case '': return 'File folder';
      default:
        if (extension.isNotEmpty) return '${extension.substring(1).toUpperCase()} File';
        return 'File';
    }
  }
}