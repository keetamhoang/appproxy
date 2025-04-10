import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/proxy_item.dart';
import '../../core/api/api_client.dart';

class ProxyDetailPage extends StatefulWidget {
  final ProxyItem proxyItem;
  const ProxyDetailPage({super.key, required this.proxyItem});

  @override
  State<ProxyDetailPage> createState() => _ProxyDetailPageState();
}

class _ProxyDetailPageState extends State<ProxyDetailPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _rotateTimerController;
  final _rotateTimerFocus = FocusNode();
  String? _selectedCountry;
  bool _isRotateEnabled = false;
  bool _isSettingsLoading = true;
  Future<Map<String, String>>? _countriesFuture;
  Map<String, String> _countriesMap = {};

  String get _storageKey => 'proxy_settings_${widget.proxyItem.token}';

  @override
  void initState() {
    super.initState();
    _rotateTimerController = TextEditingController();
    _initializePage();
  }

  @override
  void dispose() {
    _rotateTimerController.dispose();
    _rotateTimerFocus.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    await _loadSettings();
    if (mounted) {
      setState(() {
        _countriesFuture = _fetchCountries();
        _isSettingsLoading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? settingsJson = prefs.getString(_storageKey);

      String loadedCountry = 'all';
      bool loadedRotateEnabled = false;
      String loadedRotateTimer = '';

      if (settingsJson != null) {
        final Map<String, dynamic> savedSettings = jsonDecode(settingsJson);
        loadedCountry = savedSettings['country'] ?? 'all';
        loadedRotateEnabled = savedSettings['rotateEnabled'] ?? false;
        loadedRotateTimer = (savedSettings['rotateTimer'] ?? '').toString();
        print('Loaded settings for ${_storageKey}: $savedSettings');
      } else {
        print('No saved settings found for ${_storageKey}, using defaults.');
      }

      _selectedCountry = loadedCountry;
      _isRotateEnabled = loadedRotateEnabled;
      _rotateTimerController.text = loadedRotateTimer;

    } catch (e) {
      print("Error loading settings for ${_storageKey}: $e");
      _selectedCountry = 'all';
      _isRotateEnabled = false;
      _rotateTimerController.text = '';
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading saved settings: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<Map<String, String>> _fetchCountries() async {
    final apiClient = ApiClient.instance;
    try {
      final response = await apiClient.get('/api/public/proxy/country');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final Map<String, dynamic> rawData = response.data['data'];
        final Map<String, String> countries = rawData.map((key, value) => MapEntry(key, value.toString()));
        _countriesMap = countries;
        return countries;
      } else {
        throw Exception(response.data['message'] ?? 'Failed to load countries');
      }
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  String _getDioErrorMessage(DioException e) {
    String defaultMessage = 'Network or server error occurred.';
    if (e.response != null && e.response?.data is Map) {
      return e.response?.data['message'] ?? defaultMessage;
    } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your network.';
    }
    return e.message ?? defaultMessage;
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final country = _selectedCountry;
      final rotateEnabled = _isRotateEnabled;
      final rotateTimer = (rotateEnabled && _rotateTimerController.text.isNotEmpty)
          ? int.tryParse(_rotateTimerController.text)
          : null;

      final Map<String, dynamic> currentSettings = {
        'country': country,
        'rotateEnabled': rotateEnabled,
        'rotateTimer': rotateTimer,
      };

      final String settingsJson = jsonEncode(currentSettings);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, settingsJson);

        print('Saved settings for ${_storageKey}: $settingsJson');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }

      } catch (e) {
        print("Error saving settings for ${_storageKey}: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix errors in the form'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    const Color primaryOrange = Color(0xFFEA580C);

    InputDecoration inputDecoration(String label, {bool enabled = true}) {
      return InputDecoration(
        labelText: label,
        labelStyle: textTheme.labelLarge?.copyWith(color: enabled ? Colors.grey[400] : Colors.grey[600]),
        hintStyle: textTheme.labelMedium?.copyWith(color: Colors.grey[600]),
        errorStyle: textTheme.bodySmall?.copyWith(color: Colors.redAccent),
        filled: true,
        fillColor: enabled ? Colors.white.withOpacity(0.05) : Colors.grey[850]?.withOpacity(0.5),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[700]!, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryOrange, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[800]!, width: 1.0),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
    }

    if (_isSettingsLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Settings...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          elevation: theme.appBarTheme.elevation,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Key: ${widget.proxyItem.token}',
                style: theme.appBarTheme.titleTextStyle?.copyWith(fontSize: 20, color: Colors.black),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                'Edit proxy settings',
                style: textTheme.labelMedium?.copyWith(color: Colors.grey[400]),
              ),
            ],
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          top: true,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text('Country', style: textTheme.titleSmall?.copyWith(color: Colors.grey[400])),
                        const SizedBox(height: 8),
                        FutureBuilder<Map<String, String>>(
                          future: _countriesFuture,
                          builder: (context, snapshot) {
                            Widget dropdownContent;
                            if (snapshot.connectionState == ConnectionState.waiting && _countriesMap.isEmpty) {
                              dropdownContent = DropdownButtonFormField<String>(
                                items: const [],
                                onChanged: null,
                                decoration: inputDecoration('Loading countries...', enabled: false).copyWith(labelText: null),
                                style: textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                                dropdownColor: Colors.grey[850],
                                icon: const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)),
                              );
                            }
                            else if (snapshot.hasError && _countriesMap.isEmpty) {
                              dropdownContent = TextFormField(
                                initialValue: 'Error: ${snapshot.error}',
                                readOnly: true,
                                style: textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
                                decoration: inputDecoration('Could not load countries', enabled: false).copyWith(
                                    labelText: null,
                                    suffixIcon: IconButton(
                                      icon: Icon(Icons.refresh, color: Colors.orangeAccent),
                                      tooltip: 'Retry',
                                      onPressed: () {
                                        setState(() { _countriesFuture = _fetchCountries(); });
                                      },
                                    )
                                ),
                              );
                            }
                            else {
                              final countries = snapshot.hasData ? snapshot.data! : _countriesMap;
                              String? currentSelected = _selectedCountry;
                              if (!countries.containsKey(currentSelected)) {
                                currentSelected = countries.containsKey('all') ? 'all' : (countries.isNotEmpty ? countries.keys.first : null);
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && _selectedCountry != currentSelected) {
                                    setState(() { _selectedCountry = currentSelected; });
                                  }
                                });
                              }
                              dropdownContent = DropdownButtonFormField<String>(
                                value: currentSelected,
                                items: countries.entries.map((entry) {
                                  String displayText;
                                  switch(entry.key) {
                                    case 'all': displayText = entry.value; break;
                                    default: displayText = entry.value;
                                  }
                                  return DropdownMenuItem<String>(
                                    value: entry.key,
                                    child: Text(displayText),
                                  );
                                }).toList(),
                                onChanged: countries.isEmpty ? null : (String? newValue) {
                                  setState(() { _selectedCountry = newValue; });
                                },
                                decoration: inputDecoration('Select country', enabled: countries.isNotEmpty).copyWith(labelText: null),
                                style: textTheme.bodyLarge,
                                dropdownColor: Colors.white,
                                icon: countries.isEmpty ? Icon(Icons.error_outline, color: Colors.grey[600]) : Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400]),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a country';
                                  }
                                  return null;
                                },
                              );
                            }

                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: dropdownContent,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          value: _isRotateEnabled,
                          onChanged: (newValue) {
                            setState(() { _isRotateEnabled = newValue; });
                          },
                          title: Text('Rotate Proxy', style: textTheme.titleMedium),
                          subtitle: Text(
                            'Auto-rotate IP address',
                            style: textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                          ),
                          tileColor: Colors.white.withOpacity(0.05),
                          activeColor: primaryOrange,
                          activeTrackColor: primaryOrange.withOpacity(0.5),
                          inactiveThumbColor: Colors.grey[400],
                          inactiveTrackColor: Colors.grey[700],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        const SizedBox(height: 16),
                        AnimatedOpacity(
                          opacity: _isRotateEnabled ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Visibility(
                            visible: _isRotateEnabled,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _rotateTimerController,
                                  focusNode: _rotateTimerFocus,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: inputDecoration('Rotate Timer (seconds)'),
                                  style: textTheme.bodyLarge,
                                  validator: (value) {
                                    if (_isRotateEnabled && (value == null || value.isEmpty)) {
                                      return 'Timer is required for rotation';
                                    }
                                    final timerNum = int.tryParse(value ?? '');
                                    if (_isRotateEnabled && (timerNum == null || timerNum <= 0)) {
                                      return 'Timer must be a positive number';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: primaryOrange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}