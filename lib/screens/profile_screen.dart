import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/member_profile_service.dart';

const _interests = [
  'Travel', 'Music', 'Reading', 'Food', 'Fitness', 'Technology',
  'Entrepreneurship', 'Movies', 'Art', 'Nature', 'Sports', 'Volunteering',
  'Fashion', 'Photography', 'Cooking', 'Faith', 'Culture', 'Personal growth',
];
const _values = [
  'Honesty', 'Respect', 'Family', 'Faith', 'Kindness', 'Ambition',
  'Loyalty', 'Communication', 'Independence', 'Financial responsibility',
  'Emotional maturity', 'Trust',
];
const _lifestyles = [
  'Active', 'Relaxed', 'Career-focused', 'Family-oriented', 'Social',
  'Homebody', 'Adventurous', 'Health-conscious', 'Creative', 'Travel-loving',
];
const _genders = ['Woman', 'Man', 'Non-binary', 'Prefer to discuss'];
const _goals = ['Long-term relationship', 'Marriage', 'Dating with intention', 'Friendship first'];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = MemberProfileService(Supabase.instance.client);
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _bio = TextEditingController();
  String _goal = _goals.first;
  String _gender = 'Prefer to discuss';
  final Set<String> _selectedInterests = {};
  final Set<String> _selectedValues = {};
  final Set<String> _selectedLifestyles = {};
  final Set<String> _preferredGenders = {};
  final Set<String> _preferredGoals = {};
  RangeValues _ageRange = const RangeValues(21, 45);
  double _distance = 50;
  bool _saving = false;
  bool _loading = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.loadProfile();
      if (data != null) {
        _name.text = (data['display_name'] ?? '').toString();
        _city.text = (data['city'] ?? '').toString();
        _bio.text = (data['bio'] ?? '').toString();
        _goal = (data['relationship_goal'] ?? _goals.first).toString();
        _gender = (data['gender'] ?? 'Prefer to discuss').toString();
        _selectedInterests.addAll((data['interests'] as List?)?.cast<String>() ?? []);
        _selectedValues.addAll((data['values'] as List?)?.cast<String>() ?? []);
        _selectedLifestyles.addAll((data['lifestyles'] as List?)?.cast<String>() ?? []);
        final p = data['preferences'] as Map<String, dynamic>?;
        if (p != null) {
          _ageRange = RangeValues(
            (p['min_age'] as num?)?.toDouble() ?? 21,
            (p['max_age'] as num?)?.toDouble() ?? 45,
          );
          _preferredGenders.addAll((p['preferred_genders'] as List?)?.cast<String>() ?? []);
          _preferredGoals.addAll((p['preferred_goals'] as List?)?.cast<String>() ?? []);
          _distance = ((p['max_distance_km'] as num?) ?? 50).toDouble();
        }
      }
    } catch (_) {
      _status = 'Complete your profile to start receiving recommendations.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _city.text.trim().isEmpty) {
      setState(() => _status = 'Please enter your display name and city.');
      return;
    }
    if (_selectedInterests.isEmpty || _selectedValues.isEmpty || _selectedLifestyles.isEmpty) {
      setState(() => _status = 'Choose at least one interest, value and lifestyle.');
      return;
    }
    setState(() { _saving = true; _status = null; });
    try {
      await _service.saveProfile(
        displayName: _name.text,
        city: _city.text,
        bio: _bio.text,
        relationshipGoal: _goal,
        gender: _gender,
        interests: _selectedInterests.toList(),
        values: _selectedValues.toList(),
        lifestyles: _selectedLifestyles.toList(),
        minAge: _ageRange.start.round(),
        maxAge: _ageRange.end.round(),
        preferredGenders: _preferredGenders.toList(),
        preferredGoals: _preferredGoals.toList(),
        maxDistanceKm: _distance.round(),
      );
      _status = 'Your profile and matchmaking preferences have been saved.';
    } on PostgrestException catch (e) {
      _status = 'Could not save: ${e.message}. Confirm the Sprint 2 migration and RLS policies are applied.';
    } catch (e) {
      _status = 'Could not save your profile. Please try again.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose(); _city.dispose(); _bio.dispose(); super.dispose();
  }

  Widget _section(String title, String hint, List<String> options, Set<String> selected) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(hint, style: const TextStyle(color: Colors.black54, fontSize: 13)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 2, children: options.map((option) {
        final active = selected.contains(option);
        return FilterChip(
          label: Text(option),
          selected: active,
          onSelected: (value) => setState(() {
            if (value) { selected.add(option); } else { selected.remove(option); }
          }),
          selectedColor: const Color(0xFFF1D7E2),
          checkmarkColor: const Color(0xFF7B2348),
        );
      }).toList()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 32), children: [
      const Text('Build your AMORA profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Share what matters to you. Your answers help AMORA suggest more compatible connections.'),
      const SizedBox(height: 22),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _city, decoration: const InputDecoration(labelText: 'City / area', hintText: 'e.g. Accra', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _bio, maxLines: 4, maxLength: 300, decoration: const InputDecoration(labelText: 'About you', hintText: 'A little about your personality and what you enjoy…', border: OutlineInputBorder())),
      const SizedBox(height: 16),
      const Text('Gender', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _genders.contains(_gender) ? _gender : 'Prefer to discuss',
        items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        onChanged: (v) => setState(() => _gender = v ?? 'Prefer to discuss'),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      const SizedBox(height: 16),
      const Text('Relationship goal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _goals.contains(_goal) ? _goal : _goals.first,
        items: _goals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        onChanged: (v) => setState(() => _goal = v ?? _goals.first),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      const SizedBox(height: 22),
      _section('Your interests', 'Select the things you enjoy.', _interests, _selectedInterests),
      const SizedBox(height: 20),
      _section('Your values', 'Choose the qualities that matter most to you.', _values, _selectedValues),
      const SizedBox(height: 20),
      _section('Your lifestyle', 'Select the descriptions that fit your everyday life.', _lifestyles, _selectedLifestyles),
      const SizedBox(height: 22),
      const Text('Who would you like to meet?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('These preferences guide discovery. Leave blank if you are open to everyone.', style: TextStyle(color: Colors.black54, fontSize: 13)),
      const SizedBox(height: 8),
      _section('Preferred genders', 'Select one or more, if you wish.', _genders, _preferredGenders),
      const SizedBox(height: 16),
      _section('Preferred relationship goals', 'Select the goals you are open to.', _goals, _preferredGoals),
      const SizedBox(height: 18),
      Text('Preferred age range: ${_ageRange.start.round()}–${_ageRange.end.round()}', style: const TextStyle(fontWeight: FontWeight.bold)),
      RangeSlider(
        values: _ageRange,
        min: 18, max: 80, divisions: 62,
        labels: RangeLabels('${_ageRange.start.round()}', '${_ageRange.end.round()}'),
        onChanged: (v) => setState(() => _ageRange = v),
      ),
      Text('Preferred distance: ${_distance.round()} km', style: const TextStyle(fontWeight: FontWeight.bold)),
      const Text('Saved as a preference. Distance-based filtering will be enabled when location-sharing and distance calculations are implemented.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      Slider(value: _distance, min: 5, max: 500, divisions: 99, onChanged: (v) => setState(() => _distance = v)),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Saving profile…' : 'Save profile and preferences'),
      ),
      if (_status != null) Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(_status!, style: TextStyle(color: _status!.startsWith('Your profile') ? Colors.green.shade700 : Colors.red.shade700)),
      ),
      const SizedBox(height: 12),
      const Text('Your compatibility answers are used to generate recommendations. They are not a guarantee that two people are compatible.', style: TextStyle(fontSize: 12, color: Colors.black54)),
    ]);
  }
}
