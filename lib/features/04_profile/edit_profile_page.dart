import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../repositories/profile_repository.dart';
import 'user_profile_page.dart';

class EditProfilePage extends StatefulWidget {
  final UserModel user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _profileRepository = ProfileRepository();

  late final TextEditingController _prenomController;
  late final TextEditingController _nomController;
  late final TextEditingController _villeController;
  late final TextEditingController _bioController;
  late final TextEditingController _photoUrlController;

  late String _genre;
  late List<String> _selectedCategories;
  DateTime? _dateNaissance;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _prenomController = TextEditingController(text: u.prenom);
    _nomController = TextEditingController(text: u.nom);
    _villeController = TextEditingController(text: u.lieu ?? '');
    _bioController = TextEditingController(text: u.bio ?? '');
    _photoUrlController = TextEditingController(text: u.photoUrl ?? '');
    _genre = _validGenre(u.genre);
    _selectedCategories = List<String>.from(u.favoriteCategories);
    _dateNaissance = _parseDateString(u.dateNaissance);
  }

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _villeController.dispose();
    _bioController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  String _validGenre(String? value) {
    const options = ['Homme', 'Femme', 'Autre', 'Non précisé'];
    if (value != null && options.contains(value)) return value;
    return 'Non précisé';
  }

  DateTime? _parseDateString(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _save() async {
    final prenom = _prenomController.text.trim();

    if (prenom.isEmpty) {
      setState(() => _errorMessage = 'Le prénom est obligatoire.');
      return;
    }

    final bio = _bioController.text.trim();
    if (bio.length > 300) {
      setState(() => _errorMessage = 'La bio ne peut pas dépasser 300 caractères.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _profileRepository.updateProfile(
        userId: widget.user.id,
        prenom: prenom,
        nom: _nomController.text,
        lieu: _villeController.text,
        genre: _genre,
        dateNaissance: _dateNaissance != null ? _formatDate(_dateNaissance!) : '',
        bio: bio,
        favoriteCategories: _selectedCategories,
        photoUrl: _photoUrlController.text,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erreur lors de la sauvegarde : $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _prenomController,
              decoration: const InputDecoration(
                label: Text.rich(
                  TextSpan(
                    text: 'Prénom',
                    children: [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nomController,
              decoration: const InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _villeController,
              decoration: const InputDecoration(
                labelText: 'Ville',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Genre',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _genre,
                  isDense: true,
                  items: ['Homme', 'Femme', 'Autre', 'Non précisé']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _genre = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date de naissance (optionnel)',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
                hintText: _dateNaissance != null
                    ? _formatDate(_dateNaissance!)
                    : null,
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateNaissance ?? DateTime(1990),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dateNaissance = picked);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Bio (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _photoUrlController,
              decoration: const InputDecoration(
                labelText: 'URL de photo (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Catégories favorites',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: UserProfilePage.availableCategories.map((cat) {
                final selected = _selectedCategories.contains(cat);
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedCategories.add(cat);
                      } else {
                        _selectedCategories.remove(cat);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '* Champ obligatoire',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
