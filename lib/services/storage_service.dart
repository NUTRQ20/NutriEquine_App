import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery and upload to Firebase Storage.
  /// Returns the public download URL or null if cancelled.
  Future<String?> pickAndUploadHorsePhoto(String horseId) async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return null;

    final file = File(picked.path);
    final ref =
        _storage.ref().child('horse_photos/$horseId/profile.jpg');

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// Pick from camera instead of gallery.
  Future<String?> captureAndUploadHorsePhoto(String horseId) async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (picked == null) return null;

    final file = File(picked.path);
    final ref =
        _storage.ref().child('horse_photos/$horseId/profile.jpg');

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}
