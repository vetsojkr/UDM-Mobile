import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'candidate_home.dart';
import '../../services/candidature_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/user_service.dart';
import '../../models/role.dart';

class CandidatureScreen extends StatefulWidget {
  const CandidatureScreen({super.key});

  @override
  State<CandidatureScreen> createState() => _CandidatureScreenState();
}

class _CandidatureScreenState extends State<CandidatureScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _dateNaissanceController = TextEditingController();
  DateTime? _selectedDate;

  String? _selectedFaculty;
  String? _selectedProgramme;
  bool _showProgrammeList = false;

  final Map<String, Map<String, dynamic>> _faculties = {
    'Faculté de commerce et de gestion': {
      'imageAsset': 'assets/images/faculty_commerce.jpg',
      'programmes': [
        'Licence (avec mention) en comptabilité et finance',
        'Licence (avec mention) en gestion des ressources humaines',
        'Licence (avec mention) en marketing',
        'Licence (avec mention) en banque et finance – Double diplôme national',
        'Diplôme en comptabilité et finance',
        'Diplôme en services bancaires et financiers',
        'Diplôme en gestion des ressources humaines',
        'Master 2 : Ingénierie numérique dans l’enseignement supérieur',
        'Master en gestion d’entreprise durable',
      ],
    },
    'Faculté du développement durable et de l’ingénierie': {
      'imageAsset': 'assets/images/faculty_engineering.jpg',
      'programmes': [
        'BEng (Hons) en génie civil',
        'BEng (Hons) en génie électrique et électronique',
        'BEng (Hons) en génie électromécanique',
        'Licence (avec mention) en génie civil',
        'Licence (avec mention) en génie électrique et automatisation',
        'Licence (avec mention) en génie électromécanique',
        'Licence (avec mention) en systèmes énergétiques et développement durable',
        'Licence (avec mention) en systèmes intelligents',
        'Diplôme en génie civil',
        'Diplôme en génie électrique et automatisation',
        'Diplôme en génie électromécanique',
        'Master en génie civil (structures et travaux publics)',
        'Master en efficacité énergétique et développement durable',
        'Master en technologies vertes et villes durables',
        'Master en Internet industriel des objets',
      ],
    },
    'Faculté des technologies de l’information et de la communication': {
      'imageAsset': 'assets/images/faculty_ict.jpg',
      'programmes': [
        'Licence (avec mention) en sciences humaines numériques',
        'BA (avec mention) en humanités numériques',
        'Licence (avec mention) en informatique appliquée',
        'Licence (avec mention) en génie logiciel',
        'Diplôme en génie logiciel',
        'Master en humanités numériques',
        'Master en intelligence artificielle et robotique',
        'Master en E-Santé publique',
      ],
    },
  };

  final Map<String, Map<String, bool>> _documentsStatus = {};
  bool _isLoading = false;
  String? _candidatureId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final CloudinaryService _cloudinary = CloudinaryService();
  final CandidatureService _candidatureService = CandidatureService();
  final UserService _userService = UserService();

  bool get _isMasterProgramme =>
      _selectedProgramme != null &&
      (_selectedProgramme!.toLowerCase().contains('master') ||
          _selectedProgramme!.toLowerCase().contains('mastère'));

  void _resetDocumentsForProgramme() {
    _documentsStatus.clear();
    if (_isMasterProgramme) {
      _documentsStatus['CV détaillé'] = {'uploaded': false, 'required': true};
      _documentsStatus['Lettre de motivation'] = {'uploaded': false, 'required': true};
      _documentsStatus['Diplôme de Licence'] = {'uploaded': false, 'required': true};
      _documentsStatus['Relevés de notes de Licence'] = {'uploaded': false, 'required': true};
      _documentsStatus['Projet de recherche (éventuel)'] = {'uploaded': false, 'required': false};
      _documentsStatus['Recommandations (2 minimum)'] = {'uploaded': false, 'required': true};
      _documentsStatus['Attestation de niveau en anglais (IELTS/TOEFL)'] = {'uploaded': false, 'required': true};
    } else {
      _documentsStatus['CV récent'] = {'uploaded': false, 'required': true};
      _documentsStatus['Lettre de motivation'] = {'uploaded': false, 'required': true};
      _documentsStatus['Diplôme du Baccalauréat'] = {'uploaded': false, 'required': true};
      _documentsStatus['Relevés de notes (dernières années)'] = {'uploaded': false, 'required': true};
      _documentsStatus['Certificat de naissance'] = {'uploaded': false, 'required': true};
      _documentsStatus['Passeport (valide)'] = {'uploaded': false, 'required': true};
      _documentsStatus['Photo d\'identité récente'] = {'uploaded': false, 'required': true};
      _documentsStatus['Certificat de travail (si expérience)'] = {'uploaded': false, 'required': false};
      _documentsStatus['Recommandations (optionnel)'] = {'uploaded': false, 'required': false};
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadExistingDraft();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _dateNaissanceController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await _userService.getCurrentUserData();
    if (userData != null && mounted) {
      setState(() {
        _firstNameController.text = userData['prenom'] ?? '';
        _lastNameController.text = userData['nom'] ?? '';
        _emailController.text = userData['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
        _telephoneController.text = userData['telephone'] ?? '';
        if (userData['dateNaissance'] != null) {
          final ts = userData['dateNaissance'] as Timestamp;
          _selectedDate = ts.toDate();
          _dateNaissanceController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
        }
      });
    }
  }

  Future<void> _loadExistingDraft() async {
    final draft = await _candidatureService.getCurrentDraft();
    if (draft != null && draft.exists && mounted) {
      final data = draft.data() as Map<String, dynamic>;
      final programme = data['programme'] as String?;
      if (programme != null && programme.isNotEmpty) {
        setState(() {
          _candidatureId = draft.id;
          _selectedProgramme = programme;
          for (var faculty in _faculties.keys) {
            if (_faculties[faculty]!['programmes'].contains(programme)) {
              _selectedFaculty = faculty;
              _showProgrammeList = true;
              break;
            }
          }
          _resetDocumentsForProgramme();
        });
        final docsSnapshot = await _candidatureService.getDocumentsStream(_candidatureId!).first;
        for (var doc in docsSnapshot.docs) {
          final type = doc['type'] as String;
          if (_documentsStatus.containsKey(type)) {
            setState(() {
              _documentsStatus[type]!['uploaded'] = true;
            });
          }
        }
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 18 * 365)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateNaissanceController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      if (_candidatureId != null) {
        await _candidatureService.updateDraft(_candidatureId!, {
          'dateNaissance': Timestamp.fromDate(picked),
        });
      }
    }
  }

  Future<void> _saveDraftAfterProgramme() async {
    if (_candidatureId == null) {
      final id = await _candidatureService.createDraft(
        nom: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        email: _emailController.text.trim(),
        telephone: _telephoneController.text.trim(),
        programme: _selectedProgramme!,
      );
      setState(() {
        _candidatureId = id;
      });
    } else {
      await _candidatureService.updateDraft(_candidatureId!, {
        'programme': _selectedProgramme,
      });
    }
  }

  Future<void> _deleteDraft() async {
    if (_candidatureId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le brouillon'),
        content: const Text('Voulez-vous vraiment supprimer cette candidature ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await _candidatureService.deleteCandidature(_candidatureId!);
      setState(() {
        _candidatureId = null;
        _selectedFaculty = null;
        _selectedProgramme = null;
        _showProgrammeList = false;
        _documentsStatus.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brouillon supprimé')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadDocument(String type) async {
    if (_candidatureId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez d’abord choisir un programme'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;

      setState(() => _isLoading = true);
      final file = result.files.single;
      final String fileName = file.name;
      String? url;

      if (kIsWeb) {
        Uint8List? bytes = file.bytes;
        if (bytes != null) {
          url = await _cloudinary.uploadBytes(bytes, fileName);
        } else {
          throw Exception("Impossible de lire les données du fichier");
        }
      } else {
        String? path = file.path;
        if (path != null) {
          url = await _cloudinary.uploadFile(File(path));
        } else if (file.bytes != null) {
          url = await _cloudinary.uploadBytes(file.bytes!, fileName);
        }
      }

      if (url != null && _candidatureId != null) {
        await _candidatureService.addDocument(
          candidatureId: _candidatureId!,
          nomFichier: fileName,
          type: type,
          url: url,
        );
        if (mounted) {
          setState(() {
            _documentsStatus[type]!['uploaded'] = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$type téléversé avec succès'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception("L'URL n'a pas pu être générée");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizeSubmission() async {
    if (_candidatureId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune candidature en cours'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProgramme == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir un programme'), backgroundColor: Colors.orange),
      );
      return;
    }

    final missingRequired = _documentsStatus.entries
        .where((entry) => entry.value['required'] == true && entry.value['uploaded'] == false)
        .map((e) => e.key)
        .toList();

    if (missingRequired.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Documents obligatoires manquants : ${missingRequired.join(', ')}'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _candidatureService.updateDraft(_candidatureId!, {
        'nom': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'email': _emailController.text.trim(),
        'telephone': _telephoneController.text.trim(),
        'programme': _selectedProgramme,
        'dateNaissance': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
      });
      await _candidatureService.submitCandidature(_candidatureId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Candidature soumise avec succès !'), backgroundColor: Colors.green),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => CandidateHomeScreen(role: UserRole.candidat)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Postuler"),
        centerTitle: true,
        actions: [
          if (_candidatureId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteDraft,
              tooltip: 'Supprimer le brouillon',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildForm(),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Informations personnelles", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: "Prénom",
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.isEmpty ? "Champ obligatoire" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: "Nom",
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.isEmpty ? "Champ obligatoire" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: "Email",
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) => value == null || value.isEmpty ? "Email requis" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telephoneController,
            decoration: const InputDecoration(
              labelText: "Téléphone",
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) => value == null || value.isEmpty ? "Téléphone requis" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dateNaissanceController,
            decoration: const InputDecoration(
              labelText: "Date de naissance",
              prefixIcon: Icon(Icons.cake_outlined),
              border: OutlineInputBorder(),
              hintText: "JJ/MM/AAAA",
            ),
            readOnly: true,
            onTap: _selectDate,
            validator: (value) => _selectedDate == null ? "Date de naissance requise" : null,
          ),
          const SizedBox(height: 20),

          // ===== CHOIX DE LA FACULTÉ ET DU PROGRAMME =====
          if (_selectedProgramme == null) ...[
            const Text("Choisissez votre faculté", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _faculties.keys.length,
                itemBuilder: (context, index) {
                  final facultyName = _faculties.keys.elementAt(index);
                  final faculty = _faculties[facultyName]!;
                  final isSelected = _selectedFaculty == facultyName;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFaculty = facultyName;
                        _showProgrammeList = true;
                      });
                    },
                    child: Container(
                      width: 220,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                            child: Image.asset(
                              faculty['imageAsset'],
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 120,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image, size: 50),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              facultyName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_showProgrammeList && _selectedFaculty != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Choisissez votre programme", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _faculties[_selectedFaculty]!['programmes'].length,
                      itemBuilder: (context, index) {
                        final programme = _faculties[_selectedFaculty]!['programmes'][index];
                        final isSelected = _selectedProgramme == programme;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              setState(() {
                                _selectedProgramme = programme;
                                _resetDocumentsForProgramme();
                              });
                              await _saveDraftAfterProgramme();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      programme,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: isSelected ? Theme.of(context).primaryColor : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
          ] else ...[
            // ===== SECTION CORRIGÉE POUR L'OVERFLOW =====
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Programme choisi", 
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text(
                          _selectedProgramme!, 
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      setState(() {
                        _selectedFaculty = null;
                        _selectedProgramme = null;
                        _showProgrammeList = false;
                        _documentsStatus.clear();
                      });
                      if (_candidatureId != null) {
                        await _candidatureService.deleteCandidature(_candidatureId!);
                        setState(() => _candidatureId = null);
                      }
                    },
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                    tooltip: "Changer",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ===== DOCUMENTS REQUIS =====
          if (_selectedProgramme != null) ...[
            const Text("Documents requis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._documentsStatus.entries.map((entry) {
              final type = entry.key;
              final isUploaded = entry.value['uploaded']!;
              final isRequired = entry.value['required']!;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        isUploaded ? Icons.check_circle : Icons.attach_file,
                        key: ValueKey(isUploaded),
                        color: isUploaded ? Colors.green : (isRequired ? Colors.red : Colors.grey),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(type,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          overflow: TextOverflow.ellipsis, maxLines: 1)),
                        if (!isRequired) ...[ 
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Optionnel', style: TextStyle(fontSize: 9)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        isUploaded ? "Document déposé ✓"
                            : (isRequired ? "Obligatoire — manquant" : "Document optionnel"),
                        style: TextStyle(
                          fontSize: 11,
                          color: isUploaded ? Colors.green : (isRequired ? Colors.red.shade400 : Colors.grey),
                        ),
                      ),
                    ])),
                    IconButton(
                      icon: Icon(isUploaded ? Icons.refresh_rounded : Icons.upload_rounded,
                        color: isUploaded ? Colors.blue : Colors.grey.shade600, size: 20),
                      onPressed: () => _pickAndUploadDocument(type),
                      tooltip: isUploaded ? "Remplacer" : "Téléverser",
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ]),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isLoading ? null : _finalizeSubmission,
                child: const Text(
                  "Soumettre ma candidature",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}