import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ProfilePhotoService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndUploadPhoto(String userId) async {
    try {
      // 1. PICK
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      print('PICK result: ${picked?.path}');
      if (picked == null) return null;

      // 2. CROP (carré centré manuel)
      final bytes = await File(picked.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final size = decoded.width < decoded.height ? decoded.width : decoded.height;
      final x = (decoded.width - size) ~/ 2;
      final y = (decoded.height - size) ~/ 2;
      var cropped = img.copyCrop(decoded, x: x, y: y, width: size, height: size);
      print('CROP result: ${cropped.width}x${cropped.height}');

      // 3. RESIZE (max 512px)
      if (size > 512) {
        cropped = img.copyResize(cropped, width: 512, height: 512);
      }

      // 4. ENCODE
      final compressed = Uint8List.fromList(img.encodeJpg(cropped, quality: 78));
      print('COMPRESS result: ${compressed.length} bytes');

      // 5. UPLOAD
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/$userId/profile/avatar.jpg');

      await ref.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final String downloadUrl = await ref.getDownloadURL();
      print('UPLOAD done: $downloadUrl');

      // 6. FIRESTORE
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
