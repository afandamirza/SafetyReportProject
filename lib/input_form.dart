// input_form.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'firebase_services.dart';

class InputForm extends StatefulWidget {
  const InputForm({super.key});

  @override
  State<InputForm> createState() => _InputFormState();
}

class _InputFormState extends State<InputForm> {
  String? image, location, detectionStatus;
  File? _imageFile;
  final picker = ImagePicker();
  final FirebaseServices firebaseServices = FirebaseServices();

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });
  }

  Future<void> createData() async {
    if (_imageFile != null) {
      String? imageUrl = await firebaseServices.uploadImage(_imageFile!);
      if (imageUrl != null) {
        await firebaseServices.createData(imageUrl, location!, detectionStatus!);
      }
    }
  }

  void getLocation(String location) {
    this.location = location;
  }

  void getDetectionStatus(String status) {
    this.detectionStatus = status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Add New Data'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _imageFile == null
                    ? Text('No image selected.')
                    : Image.file(_imageFile!),
                ElevatedButton(
                  onPressed: pickImage,
                  child: Text('Pick Image'),
                ),
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
                  child: TextFormField(
                    decoration: const InputDecoration(
                        labelText: "Detection Status",
                        fillColor: Colors.white,
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.blue, width: 2.0),
                        )),
                    onChanged: (status) {
                      getDetectionStatus(status);
                    },
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
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
        ),
      ),
    );
  }
}
