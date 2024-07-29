// firebase_services.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

class FirebaseServices {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Future<String?> uploadImage(File file) async {
    // Compress image to ensure it is within the size limit
    final compressedFile = await compressImage(file);
    if (compressedFile == null) return null;

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final destination = 'images/$fileName';

    try {
      final ref = FirebaseStorage.instance.ref(destination);
      await ref.putFile(compressedFile);
      String imageUrl = await ref.getDownloadURL();
      return imageUrl;
    } catch (e) {
      print('Error occurred while uploading image: $e');
      return null;
    }
  }

  Future<File?> compressImage(File file) async {
    final bytes = file.readAsBytesSync();
    final img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      print('Unable to decode image.');
      return null;
    }

    // Resize and compress image
    final resizedImage = img.copyResize(image, width: 100); // Adjust width as needed
    final compressedBytes = img.encodeJpg(resizedImage, quality: 85); // Adjust quality as needed

    // Save compressed image to temporary file
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/temp_image.jpg');
    tempFile.writeAsBytesSync(compressedBytes);

    return tempFile;
  }

  Future<void> createData(String imageUrl, String location, String detectionStatus) async {
    DocumentReference documentReference = db.collection("SafetyReport").doc(location);

    Map<String, dynamic> mapData = {
      "Image": imageUrl,
      "Location": location,
      "Safety Report": detectionStatus,
      "Time stamp": Timestamp.now()
    };

    documentReference.set(mapData).whenComplete(() {
      print("$location created");
    });
  }
}
