import 'package:flutter/material.dart';
import 'package:agenda_app/models/group_model.dart';
import 'package:agenda_app/repositories/groups_repository.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final GroupsRepository _repository = GroupsRepository();

  String _visibility = GroupModel.visibilityPrivate;
  bool _isSaving = false;

  String _visibilityHelperText() {
    switch (_visibility) {
      case GroupModel.visibilityFriends:
        return 'Le groupe est destiné à votre cercle d’amis.';
      case GroupModel.visibilityPrivate:
      default:
        return 'Le groupe reste privé et géré par ses membres.';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    final trimmedName = _nameController.text.trim();
    final trimmedDescription = _descriptionController.text.trim();

    setState(() {
      _isSaving = true;
    });

    final success = await _repository.createGroup(
      name: trimmedName,
      description: trimmedDescription,
      visibility: _visibility,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Groupe créé avec succès'
              : 'Impossible de créer le groupe',
        ),
      ),
    );

    if (success) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un groupe'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Nom du groupe',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Entrez un nom';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                enabled: !_isSaving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(
                  labelText: 'Visibilité',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: GroupModel.visibilityPrivate,
                    child: Text('Privé'),
                  ),
                  DropdownMenuItem(
                    value: GroupModel.visibilityFriends,
                    child: Text('Entre amis'),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _visibility = value;
                        });
                      },
              ),
              const SizedBox(height: 8),
              Text(
                _visibilityHelperText(),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Créer le groupe'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}