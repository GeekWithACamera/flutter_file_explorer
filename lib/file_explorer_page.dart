import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p; // For path manipulation (add path package to pubspec.yaml)

class FileExplorerPage extends StatefulWidget {
  const FileExplorerPage({super.key});

  @override
  State<FileExplorerPage> createState() => _FileExplorerPageState();
}

class _FileExplorerPageState extends State<FileExplorerPage> {
  Directory? _selectedDirectory;
  List<FileSystemEntity> _rightPanelItems = [];
  List<Directory> _initialRoots = [];
  bool _isLoadingRoots = true;
  bool _showPreviewPane = false;
  FileSystemEntity? _selectedFile;
  ThemeMode _themeMode = ThemeMode.light; // Light/Dark mode toggle

  @override
  void initState() {
    super.initState();
    _loadInitialRoots();
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
        _selectDirectory(_initialRoots.first);
      }
    });
  }

  Future<void> _selectDirectory(Directory directory) async {
    try {
      if (!await directory.exists()) {
        setState(() {
          _selectedDirectory = directory;
          _rightPanelItems = [];
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
      });
    } catch (e) {
      print("Error listing directory \\${directory.path}: \\$e");
      setState(() {
        _selectedDirectory = directory;
        _rightPanelItems = []; // Show empty or error state
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access: \\${p.basename(directory.path)}. Permission denied?')),
      );
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

  Widget _buildDirectoryTree(Directory dir, {int depth = 0}) {
    String displayName = p.basename(dir.path);
    if (displayName.isEmpty && dir.path.isNotEmpty) { // Handle root paths like 'C:\' or '/'
        displayName = dir.path;
    }

    return ExpansionTile(
      key: PageStorageKey<String>(dir.path), // Preserve expansion state
      leading: Icon(Icons.folder, color: Colors.amber[700]),
      title: GestureDetector(
        onTap: () => _selectDirectory(dir), // Enable single-click to open folder in right pane
        onDoubleTap: () => _selectDirectory(dir), // Enable double-click to open folder
        child: Text(
          displayName,
          style: TextStyle(
            fontWeight: _selectedDirectory?.path == dir.path ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      childrenPadding: EdgeInsets.only(left: 16.0 * (depth == 0 ? 1 : 0) ), // Indent only children of non-root items
      children: <Widget>[
        FutureBuilder<List<Directory>>(
          future: _getSubDirectories(dir),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && depth < 2) {
              // return const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator(minHeight: 2));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink(); // No sub-directories or not loaded yet
            }
            return Column( // Ensure children are laid out vertically
              children: snapshot.data!
                  .map((subDir) => _buildDirectoryTree(subDir, depth: depth + 1))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

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
    String currentDisplayPath = "File Explorer";
    if (_selectedDirectory != null) {
      currentDisplayPath = p.basename(_selectedDirectory!.path);
      if (currentDisplayPath.isEmpty) {
        currentDisplayPath = _selectedDirectory!.path;
      }
    }

    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.folder, color: Colors.amber[700]),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _selectedDirectory?.path ?? "This PC",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          actions: [
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              tooltip: 'New Folder',
              onPressed: () async {
                if (_selectedDirectory != null) {
                  final newFolderName = 'New Folder';
                  final newFolderPath =
                      p.join(_selectedDirectory!.path, newFolderName);
                  final newFolder = Directory(newFolderPath);
                  if (await newFolder.exists()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Folder "$newFolderName" already exists.')),
                    );
                  } else {
                    try {
                      await newFolder.create();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Folder "$newFolderName" created successfully.')),
                      );
                      _selectDirectory(_selectedDirectory!);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to create folder: $e')),
                      );
                    }
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
              onPressed: () {
                setState(() {
                  _rightPanelItems.sort((a, b) {
                    return p.basename(a.path).toLowerCase().compareTo(
                        p.basename(b.path).toLowerCase());
                  });
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.view_list),
              tooltip: 'View',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('View functionality not implemented yet.')),
                );
              },
            ),
          ],
        ),
        body: Row(
          children: [
            // Directory Tree Pane
            Container(
              width: 250,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey[300]!)),
              ),
              child: _isLoadingRoots
                  ? const Center(child: CircularProgressIndicator())
                  : _initialRoots.isEmpty
                      ? const Center(child: Text('No roots found or accessible.'))
                      : ListView(
                          children: _initialRoots.map((root) => _buildDirectoryTree(root)).toList(),
                        ),
            ),
            // File List Pane
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    border: _showPreviewPane
                        ? Border(right: BorderSide(color: Colors.grey[300]!))
                        : null,
                  ),
                  child: _selectedDirectory == null
                      ? const Center(child: Text('Select a folder from the left panel'))
                      : FutureBuilder(
                          future: _selectedDirectory!.exists(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.data == false) {
                              return Center(
                                child: Text(
                                  'Directory not accessible or does not exist:\n${_selectedDirectory!.path}',
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            if (_rightPanelItems.isEmpty) {
                              return Center(
                                child: Text('Folder is empty: ${p.basename(_selectedDirectory!.path)}'),
                              );
                            }
                            return SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Date Modified')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Size')),
                                ],
                                rows: _rightPanelItems.map((entity) {
                                  final isDir = entity is Directory;
                                  return DataRow(cells: [
                                    DataCell(Row(
                                      children: [
                                        Icon(
                                          isDir
                                              ? Icons.folder
                                              : Icons.insert_drive_file,
                                          color: isDir ? Colors.amber[700] : Colors.blueGrey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedFile = entity;
                                            });
                                          },
                                          onDoubleTap: isDir
                                              ? () => _selectDirectory(entity)
                                              : null,
                                          child: Text(p.basename(entity.path)),
                                        ),
                                      ],
                                    )),
                                    DataCell(Text(
                                      entity.statSync().modified.toLocal().toString(),
                                    )),
                                    DataCell(Text(isDir ? 'Folder' : 'File')),
                                    DataCell(Text(
                                      isDir ? '' : '${(entity as File).lengthSync()} bytes',
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            // Preview/Details Pane
            if (_showPreviewPane)
              Container(
                width: 300,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.grey[300]!)),
                ),
                child: _selectedFile == null
                    ? const Center(child: Text('No file selected'))
                    : FutureBuilder<Map<String, dynamic>>(
                        future: _getFileDetails(_selectedFile!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData) {
                            return const Center(child: Text('Error loading file details'));
                          }
                          final details = snapshot.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (details['isImage'] == true)
                                Expanded(
                                  child: Image.file(
                                    File(_selectedFile!.path),
                                    fit: BoxFit.contain,
                                  ),
                                )
                              else if (details['isVideo'] == true)
                                Expanded(
                                  child: Center(
                                    child: Text('Video preview not supported yet.'),
                                  ),
                                )
                              else
                                Expanded(
                                  child: Center(
                                    child: Text('Preview not available for this file type.'),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('Name: ${details['name']}'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('Type: ${details['isImage'] ? 'Image' : details['isVideo'] ? 'Video' : 'File'}'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('Size: ${details['size']} bytes'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('Date Modified: ${details['created']}'),
                              ),
                              if (details.containsKey('error'))
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Error: ${details['error']}', style: TextStyle(color: Colors.red)),
                                ),
                            ],
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
