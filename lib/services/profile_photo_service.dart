import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePhotoService {
  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper();

  Future<String?> pickAndUploadPhoto(String userId) async {
    try {
      // 1. PICK
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null) return null;

      // 2. CROP
      final CroppedFile? cropped = await _cropper.cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(lockAspectRatio: true),
          IOSUiSettings(lockAspectRatio: true),
        ],
      );
      if (cropped == null) return null;

      // 3. COMPRESS
      final Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        cropped.path,
        minWidth: 512,
        minHeight: 512,
        quality: 78,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) return null;

      // 4. UPLOAD
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/$userId/profile/avatar.jpg');

      await ref.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final String downloadUrl = await ref.getDownloadURL();

      // 5. FIRESTORE
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'photoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      print('ProfilePhotoService.pickAndUploadPhoto error: $e');
      return null;
    }
  }
}
