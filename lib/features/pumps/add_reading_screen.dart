import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pump_model.dart';
import '../../models/pump_reading_model.dart';
import '../../services/firestore/pump_reading_provider.dart';

class AddReadingScreen extends ConsumerStatefulWidget {
  final PumpModel pump;

  const AddReadingScreen({super.key, required this.pump});

  @override
  ConsumerState<AddReadingScreen> createState() => _AddReadingScreenState();
}

class _AddReadingScreenState extends ConsumerState<AddReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _openingController = TextEditingController();
  final _closingController = TextEditingController();
  final _priceController = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingOpening = true;
  String? _errorMessage;

  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadOpeningReading();
  }

  Future<void> _loadOpeningReading() async {
    final service = ref.read(pumpReadingFirestoreServiceProvider);
    PumpReadingModel? lastReading;
    try {
      lastReading = await service.getLatestReadingBefore(pumpId: widget.pump.id, beforeDate: _today);
    } catch (_) {
      // Prefill is a convenience — fall through to an empty opening field.
    }
    if (mounted) {
      setState(() {
        if (lastReading != null) {
          _openingController.text = lastReading.closingReading.toString();
        }
        _isLoadingOpening = false;
      });
    }
  }

  @override
  void dispose() {
    _openingController.dispose();
    _closingController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String? _validateNumber(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return '$label cannot be negative';
    return null;
  }

  String? _validateClosing(String? value) {
    final basicError = _validateNumber(value, 'Closing reading');
    if (basicError != null) return basicError;

    final opening = double.tryParse(_openingController.text.trim()) ?? 0;
    final closing = double.tryParse(value!.trim()) ?? 0;
    if (closing < opening) return 'Closing reading cannot be less than opening';
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(pumpReadingFirestoreServiceProvider);
      await service.saveReading(
        pumpId: widget.pump.id,
        pumpName: widget.pump.name,
        date: _today,
        openingReading: double.parse(_openingController.text.trim()),
        closingReading: double.parse(_closingController.text.trim()),
        pricePerLitre: double.parse(_priceController.text.trim()),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reading saved successfully')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save. Please check your connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  double? get _litresSold {
    final opening = double.tryParse(_openingController.text.trim());
    final closing = double.tryParse(_closingController.text.trim());
    if (opening == null || closing == null || closing < opening) return null;
    return closing - opening;
  }

  double? get _revenue {
    final litres = _litresSold;
    final price = double.tryParse(_priceController.text.trim());
    if (litres == null || price == null) return null;
    return litres * price;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.pump.name} · $_today')),
      body: _isLoadingOpening
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _openingController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Opening Reading (litres)',
                          prefixIcon: Icon(Icons.play_circle_outline_rounded),
                        ),
                        validator: (v) => _validateNumber(v, 'Opening reading'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _closingController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Closing Reading (litres)',
                          prefixIcon: Icon(Icons.stop_circle_outlined),
                        ),
                        validator: _validateClosing,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Price per Litre',
                          prefixIcon: Icon(Icons.currency_rupee_rounded),
                        ),
                        validator: (v) => _validateNumber(v, 'Price per litre'),
                        onChanged: (_) => setState(() {}),
                        onFieldSubmitted: (_) => _handleSave(),
                      ),
                      const SizedBox(height: 20),
                      if (_litresSold != null || _revenue != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Litres Sold', style: theme.textTheme.bodyMedium),
                                  Text(
                                    _litresSold != null ? '${_litresSold!.toStringAsFixed(2)} L' : '—',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Revenue', style: theme.textTheme.bodyMedium),
                                  Text(
                                    _revenue != null ? '₹${_revenue!.toStringAsFixed(2)}' : '—',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Reading'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
