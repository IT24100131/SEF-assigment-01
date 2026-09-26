import 'package:flutter/material.dart';
import '../models/catch.dart';
import '../services/api_service.dart';

class CatchFormScreen extends StatefulWidget {
  final Catch? existingCatch;
  
  const CatchFormScreen({Key? key, this.existingCatch}) : super(key: key);

  @override
  State<CatchFormScreen> createState() => _CatchFormScreenState();
}

class _CatchFormScreenState extends State<CatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fishTypeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'Available';
  String _selectedQuality = 'High';
  bool _isLoading = false;

  final List<String> _fishTypes = [
    'Tuna', 'Salmon', 'Mackerel', 'Sardine', 'Skipjack', 'Yellowfin',
    'Prawns', 'Crab', 'Lobster', 'Squid', 'Other'
  ];

  final List<String> _statuses = ['Available', 'Reserved', 'Sold'];
  final List<String> _qualities = ['High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    if (widget.existingCatch != null) {
      _populateForm(widget.existingCatch!);
    }
  }

  void _populateForm(Catch catch) {
    _fishTypeController.text = catch.fishType;
    _quantityController.text = catch.quantity.toString();
    _priceController.text = catch.pricePerKg.toString();
    _locationController.text = catch.location;
    _descriptionController.text = catch.description ?? '';
    _selectedDate = catch.catchDate;
    _selectedStatus = catch.status;
    _selectedQuality = catch.quality ?? 'High';
  }

  @override
  void dispose() {
    _fishTypeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveCatch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final catchData = Catch(
        id: widget.existingCatch?.id,
        fishType: _fishTypeController.text.trim(),
        quantity: double.parse(_quantityController.text),
        pricePerKg: double.parse(_priceController.text),
        location: _locationController.text.trim(),
        catchDate: _selectedDate,
        status: _selectedStatus,
        quality: _selectedQuality,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
      );

      if (widget.existingCatch == null) {
        await ApiService.createCatch(catchData);
      } else {
        await ApiService.updateCatch(widget.existingCatch!.id!, catchData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingCatch == null 
                ? 'Catch added successfully!' 
                : 'Catch updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingCatch == null ? 'Add Catch' : 'Edit Catch'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (widget.existingCatch != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteCatch,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fish Type
              DropdownButtonFormField<String>(
                value: _fishTypes.contains(_fishTypeController.text) 
                    ? _fishTypeController.text 
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Fish Type',
                  prefixIcon: Icon(Icons.waves),
                  border: OutlineInputBorder(),
                ),
                items: _fishTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  _fishTypeController.text = value ?? '';
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select fish type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Custom fish type if "Other" is selected
              if (_fishTypeController.text == 'Other')
                Column(
                  children: [
                    TextFormField(
                      controller: _fishTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Custom Fish Type',
                        prefixIcon: Icon(Icons.edit),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter fish type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Quantity
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity (kg)',
                  prefixIcon: Icon(Icons.scale),
                  border: OutlineInputBorder(),
                  suffixText: 'kg',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  final quantity = double.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Price per kg
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price per kg',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Catch Location',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Catch Date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Catch Date',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.info),
                  border: OutlineInputBorder(),
                ),
                items: _statuses.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Quality
              DropdownButtonFormField<String>(
                value: _selectedQuality,
                decoration: const InputDecoration(
                  labelText: 'Quality',
                  prefixIcon: Icon(Icons.star),
                  border: OutlineInputBorder(),
                ),
                items: _qualities.map((quality) {
                  return DropdownMenuItem(
                    value: quality,
                    child: Text(quality),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedQuality = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Total value display
              if (_quantityController.text.isNotEmpty && _priceController.text.isNotEmpty)
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Value:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${((double.tryParse(_quantityController.text) ?? 0) * (double.tryParse(_priceController.text) ?? 0)).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Save button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCatch,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.existingCatch == null ? 'Add Catch' : 'Update Catch',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCatch() async {
    if (widget.existingCatch?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Catch'),
        content: const Text('Are you sure you want to delete this catch?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await ApiService.deleteCatch(widget.existingCatch!.id!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catch deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting catch: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}