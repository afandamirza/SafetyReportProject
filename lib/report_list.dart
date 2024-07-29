import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportList extends StatelessWidget {
  const ReportList({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder(
      stream: db.collection("SafetyReport").snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No reports found.');
        } else {
          return SizedBox(
            height: MediaQuery.of(context).size.height,
            child: ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                DocumentSnapshot documentSnapshot = snapshot.data!.docs[index];
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

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Card(
                    elevation: 4,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        data['Image'] != null
                            ? Image.network(
                                data['Image'],
                                height: 80,
                                width: 80,
                                fit: BoxFit.cover,
                              )
                            : const SizedBox(
                                height: 80,
                                width: 80,
                                child: Icon(Icons.image_not_supported, size: 80),
                              ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['Location'] ?? 'No Location',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text('Date: $formattedDate'),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            'Status: ${data['Safety Report'] ?? 'No Status'}',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}
