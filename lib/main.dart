import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/rendering.dart';
import 'package:logging/logging.dart';
import 'dart:io';
import 'firebase_options.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:safetyreport/detail_page.dart';

void main() async {
  //Inisialisasi agar flutter bisa tersambung ke firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  //
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safety Report',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}



class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  String? image, location, detectionStatus;
  File? _imageFile;
  DateTimeRange? _selectedDateRange;
  bool _isDescending = false;
  bool _isGridView = false;
  String searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  // Objek variabel Instance untuk memanggil Firebase
  final FirebaseFirestore db = FirebaseFirestore.instance;
  //

  final ImagePicker picker = ImagePicker();

  final Logger log = Logger('_MyHomePageState');

  void getLocation(String location) {
    this.location = location;
  }

  void getDetectionStatus(String status) {
    detectionStatus = status;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

 @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(
      start: DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day),
      end: DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59),
    );

    _setupLogging();
  }

  void _setupLogging() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  // Pick image from gallery
  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      } else {
        log.info('No item selected.');
      }
    });
  }

  // Compress image
  Future<File?> compressImage(File file) async {
    final bytes = file.readAsBytesSync();
    final img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      log.warning('Unable to decode image.');
      return null;
    }

    int width;
    int height;

    if (image.width > image.height) {
      width = 1000;
      height = (image.height / image.width * 1000).round();
    } else {
      height = 1000;
      width = (image.width / image.height * 1000).round();
    }

    img.Image resizedImage =
        img.copyResize(image, width: width, height: height);

    final compressedBytes =
        img.encodeJpg(resizedImage, quality: 100);

    // Save compressed image to temporary file
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/temp_image.jpg');
    tempFile.writeAsBytesSync(compressedBytes);

    return tempFile;
  }

  // Upload image to Firebase Storage and get URL
  Future<void> uploadImage() async {
    if (_imageFile == null) return;

    final compressedFile = await compressImage(_imageFile!);
    if (compressedFile == null) return;

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final destination = 'images/$fileName';

    try {
      final ref = FirebaseStorage.instance.ref(destination);
      await ref.putFile(compressedFile);
      String imageUrl = await ref.getDownloadURL();

      setState(() {
        image = imageUrl;
      });

      log.info('Image uploaded: $imageUrl');
    } catch (e) {
      log.severe('Error occurred while uploading image: $e');
    }
  }


  //Create dan submit data
  Future<void> createData() async {
    await uploadImage();

    DocumentReference documentReference = db.collection("SafetyReport").doc();

    Map<String, dynamic> mapData = {
      "Image": image,
      "Location": location,
      "Safety Report": detectionStatus,
      "Time stamp": Timestamp.now()
    };

    documentReference.set(mapData).whenComplete(() {
      log.finer("Document created with ID: ${documentReference.id}");
    });
  }

  // Show date range picker and set state for date range
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _handleMenuSelection(String value) {
    if (value == 'today') {
      setState(() {
        _selectedDateRange = DateTimeRange(
          start: DateTime(
              DateTime.now().year, DateTime.now().month, DateTime.now().day),
          end: DateTime(DateTime.now().year, DateTime.now().month,
              DateTime.now().day, 23, 59, 59),
        );
      });
    } else if (value == 'all') {
      setState(() {
        _selectedDateRange = null;
      });
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _isDescending = !_isDescending;
    });
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  void navigateToDetailPage(DocumentSnapshot documentSnapshot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailPage(documentSnapshot: documentSnapshot),
      ),
    );
  }

Widget _buildInkWellListItem(DocumentSnapshot documentSnapshot) {
  Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;

  dynamic timestamp = data['Time stamp'];
  String formattedDate;

  if (timestamp is Timestamp) {
    DateTime dateTime = timestamp.toDate();
    formattedDate = DateFormat('MMMM d, yyyy \'at\' h:mm:ss a').format(dateTime);
  } else if (timestamp is int) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    formattedDate = DateFormat('MMMM d, yyyy \'at\' h:mm:ss a').format(dateTime);
  } else {
    formattedDate = 'No Timestamp';
  }

  return InkWell(
    onTap: () => navigateToDetailPage(documentSnapshot),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
      child: Card(
        elevation: 0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 16, top: 16, bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: data['Image'] != null
                  ? Image.network(data['Image'], height: 72, width: 72, fit: BoxFit.cover)
                  : const SizedBox(height: 72, width: 72, child: Icon(Icons.image_not_supported, size: 72)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(data['Location'] ?? 'No Location',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  AutoSizeText(formattedDate,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2),
                  AutoSizeText('ID: ${documentSnapshot.id}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(8),
              child: AutoSizeText('${data['Safety Report'] ?? 'No Status'}',
                  maxLines: 2,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: getStatusColor(data['Safety Report'] ?? ''),
                  )),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildInkWellGridItem(DocumentSnapshot documentSnapshot) {
  Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;

  dynamic timestamp = data['Time stamp'];
  String formattedDate;

  if (timestamp is Timestamp) {
    DateTime dateTime = timestamp.toDate();
    formattedDate = DateFormat('MMMM d, yyyy \'at\' h:mm:ss a').format(dateTime);
  } else if (timestamp is int) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    formattedDate = DateFormat('MMMM d, yyyy \'at\' h:mm:ss a').format(dateTime);
  } else {
    formattedDate = 'No Timestamp';
  }

  return InkWell(
    onTap: () => navigateToDetailPage(documentSnapshot),
    child: Card(
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: data['Image'] != null
                ? Image.network(data['Image'], fit: BoxFit.cover)
                : const Center(child: Icon(Icons.image_not_supported)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  data['Location'] ?? 'No Location',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                AutoSizeText(
                  formattedDate,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AutoSizeText(
                  'ID: ${documentSnapshot.id}', // Display document ID
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8),
            child: AutoSizeText(
              '${data['Safety Report'] ?? 'No Status'}',
              maxLines: 2,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: getStatusColor(data['Safety Report'] ?? ''),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  // Get status color based on detection status
  Color getStatusColor(String status) {
    switch (status) {
      case "No Googles":
        return Colors.blue;
      case "No Coat":
        return Colors.orange;
      case "No Helmet":
        return Colors.red;
      case "No Boots":
        return Colors.brown;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top Bar Menu Aplikasi Untuk Show All Data dan Grid/List View
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title:
            const Text('Safety Report', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            color: Colors.white,
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: _toggleViewMode,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'today',
                  child: Text('Show Today\'s Data'),
                ),
                const PopupMenuItem<String>(
                  value: 'all',
                  child: Text('Show All Data'),
                ),
              ];
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[

                  // Create Data Insert Image

                  _imageFile == null
                      ? const Text('No image selected.')
                      : Image.file(_imageFile!,
                          height: 300, width: 300, fit: BoxFit.cover),
                  const SizedBox(
                    height: 24,
                  ),
                  ElevatedButton(
                    onPressed: pickImage,
                    child: const Text('Pick Image'),
                  ),

                  //Input Form

                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextFormField(
                      decoration: const InputDecoration(
                          labelText: "Location",
                          fillColor: Colors.white,
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.blue, width: 2.0),
                          )),
                      onChanged: (String location) {
                        getLocation(location);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Detection Status",
                        fillColor: Colors.white,
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.blue, width: 2.0),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: "No Googles", child: Text("No Googles")),
                        DropdownMenuItem(
                            value: "No Coat", child: Text("No Coat")),
                        DropdownMenuItem(
                            value: "No Helmet", child: Text("No Helmet")),
                        DropdownMenuItem(
                            value: "No Boots", child: Text("No Boots")),
                      ],
                      onChanged: (String? status) {
                        setState(() {
                          getDetectionStatus(status!);
                        });
                      },
                    ),
                  ),

                  // Create Data Insert Image

                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 10,
                      children: <Widget>[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 2),
                            foregroundColor: Colors.green,
                          ),
                          child: const Text(
                            'Create',
                            textAlign: TextAlign.center,
                          ),
                          onPressed: () {
                            createData();
                          },
                        ),
                      ],
                    ),
                  ),

                  //

                  const SizedBox(
                    height: 24,
                  ),

                  // Memilih Date Range

                  TextButton.icon(
                    onPressed: () => _selectDateRange(context),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black.withOpacity(0.8),
                      side: const BorderSide(
                          color: Colors.grey, width: 1), 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    label: const Text('Select Date Range'),
                    icon: const Icon(
                      Icons.edit_calendar_rounded,
                      color: Color(0xFF1976D2),
                    ),
                  ),

                  //

                  const SizedBox(
                    height: 16,
                  ),

                  // Text Date Range yang telah di pick

                  if (_selectedDateRange != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 10, right: 10, bottom: 10),
                      child: Align(
                        alignment: Alignment.center,
                        child: AutoSizeText(
                          'Selected date range: ${DateFormat('dd-MM-yyyy').format(_selectedDateRange!.start)} to ${DateFormat('dd-MM-yyyy').format(_selectedDateRange!.end)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],

                  //
                  
                  //Report Title

                  Padding(
                    padding:
                        const EdgeInsets.only(left: 10, right: 10, bottom: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: AutoSizeText(
                            'Report',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 20),
                          ),
                        ),


                        //Ascending/Descending Button

                        IconButton(
                          icon: _isDescending
                              ? Transform.flip(
                                  flipY: true,
                                  child: const Icon(Icons.sort),
                                )
                              : const Icon(Icons.sort),
                          onPressed: _toggleSortOrder,
                        ),
                      ],
                    ),
                  ),

                  //

                  // Search TextBox

                  SizedBox(
                    width: MediaQuery.of(context).orientation ==
                            Orientation.landscape
                        ? MediaQuery.of(context).size.width / 2
                        : MediaQuery.of(context).size.width,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: TextFormField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                  ),

                  //
                  

                  // Streambuilder untuk menampilkan data dari Firebase

                  StreamBuilder(
                    stream: _selectedDateRange == null

                        //Memanggil Collection yang ada di Firebase

                        ? db.collection("SafetyReport").orderBy("Time stamp",descending:!_isDescending).snapshots()
                        : db
                            .collection("SafetyReport")
                            .where("Time stamp",
                                isGreaterThanOrEqualTo:
                                    _selectedDateRange!.start)
                            .where("Time stamp",
                                isLessThanOrEqualTo: _selectedDateRange!.end)
                            .orderBy("Time stamp",
                                descending:
                                    !_isDescending)
                            .snapshots(),

                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty) {
                        return const Text('No reports found.');
                      } else {
                        final docs = snapshot.data!.docs.where((doc) {
                          Map<String, dynamic> data =
                              doc.data() as Map<String, dynamic>;
                          String location =
                              data['Location']?.toString().toLowerCase() ?? '';
                          String safetyReport =
                              data['Safety Report']?.toString().toLowerCase() ??
                                  '';
                          String timestamp = (data['Time stamp'] is Timestamp)
                              ? DateFormat('MMMM d, yyyy \'at\' h:mm:ss a')
                                  .format(data['Time stamp'].toDate())
                                  .toLowerCase()
                              : '';
                          String docId = doc.id.toLowerCase();

                          return location.contains(searchQuery) ||
                              safetyReport.contains(searchQuery) ||
                              timestamp.contains(searchQuery) ||
                              docId.contains(searchQuery);
                        }).toList();

                        if (docs.isEmpty) {
                          return const Text(
                              'No reports found or the value may be a null.');
                        }


                        //Me-return data Firebase dalam bentuk Grid/List
                        return Column(
                          children: [
                            Text('Total Reports: ${docs.length}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(
                              height: 12,
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height,
                              width: MediaQuery.of(context).size.width,
                              child: _isGridView
                                  ? LayoutBuilder(
                                      builder: (context, constraints) {
                                      return GridView.builder(
                                        shrinkWrap: true,
                                        gridDelegate:
                                            SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: kIsWeb
                                              ? MediaQuery.of(context).size.width /6
                                              : (defaultTargetPlatform ==
                                                          TargetPlatform.windows || defaultTargetPlatform == TargetPlatform .macOS || defaultTargetPlatform == TargetPlatform.linux)
                                                  ? MediaQuery.of(context).size.width /6
                                                  : MediaQuery.of(context)
                                                              .orientation ==
                                                          Orientation.portrait
                                                      ? MediaQuery.of(context).size.width / 2
                                                      : MediaQuery.of(context).size.width / 4,
                                          crossAxisSpacing: 4.0,
                                          mainAxisSpacing: 4.0,
                                        ),
                                        itemCount: docs.length,
                                        itemBuilder: (context, index) {
                                          DocumentSnapshot documentSnapshot = docs[index];
                                          return _buildInkWellGridItem(documentSnapshot);
                                        },
                                      );
                                    })
                                  : ListView(
                                      children:
                                          List.generate(docs.length, (index) {
                                        DocumentSnapshot documentSnapshot =
                                            docs[index];
                                        return _buildInkWellListItem(documentSnapshot);
                                      }),
                                    ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}