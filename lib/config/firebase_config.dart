import 'package:firebase_core/firebase_core.dart';

const String _firebaseDatabaseUrl = String.fromEnvironment(
  'FIREBASE_DATABASE_URL',
  defaultValue: '',
);

String get firebaseDatabaseUrl {
  if (_firebaseDatabaseUrl.isEmpty) {
    final projectId = Firebase.app().options.projectId;
    if (projectId.isNotEmpty) {
      return 'https://agrishield-71213-default-rtdb.firebaseio.com/';
    }

    throw StateError(
      'Missing FIREBASE_DATABASE_URL and Firebase projectId could not be resolved.'
    );
  }
  return _firebaseDatabaseUrl;
}