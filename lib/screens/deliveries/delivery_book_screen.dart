import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/delivery_service.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';

class DeliveryBookScreen extends StatefulWidget {
  final User user;
  final VoidCallback onBooked;

  const DeliveryBookScreen({
    super.key,
    required this.user,
    required this.onBooked,
  });

  @override
  State<DeliveryBookScreen> createState() => _DeliveryBookScreenState();
}

class _DeliveryBookScreenState extends State<DeliveryBookScreen> {
  final _pickupNameController = TextEditingController();
  final _pickupPhoneController = TextEditingController();
  final _pickupSearchController = TextEditingController();

  final _dropoffNameController = TextEditingController();
  final _dropoffPhoneController = TextEditingController();
  final _dropoffSearchController = TextEditingController();

  final _notesController = TextEditingController();

  List<String> _states = [];
  String? _selectedState;
  bool _isLoadingProviders = true;

  bool _isSearchingPickup = false;
  List<Map<String, dynamic>> _pickupResults = [];
  Map<String, dynamic>? _pickupSelected;

  bool _isSearchingDropoff = false;
  List<Map<String, dynamic>> _dropoffResults = [];
  Map<String, dynamic>? _dropoffSelected;

  bool _isEstimating = false;
  bool _isBooking = false;
  Map<String, dynamic>? _estimate;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _pickupNameController.dispose();
    _pickupPhoneController.dispose();
    _pickupSearchController.dispose();
    _dropoffNameController.dispose();
    _dropoffPhoneController.dispose();
    _dropoffSearchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    try {
      final result = await DeliveryService.getProviders();
      if (result['success'] == true) {
        setState(() {
          _states = (result['states'] as List<dynamic>?)
                  ?.map((s) => s.toString())
                  .toList() ??
              ['Lagos'];
          _selectedState = _states.isNotEmpty ? _states[0] : 'Lagos';
          _isLoadingProviders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load providers: $e')),
        );
      }
      setState(() {
        _states = ['Lagos'];
        _selectedState = 'Lagos';
        _isLoadingProviders = false;
      });
    }
  }

  String get _providerName {
    if (_selectedState?.toLowerCase() == 'lagos') {
      return 'Gokada';
    }
    return 'SaleCentra Rider';
  }

  bool get _isGokada => _providerName == 'Gokada';

  Future<void> _searchPickup() async {
    final query = _pickupSearchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type a pickup address to search')),
      );
      return;
    }
    setState(() => _isSearchingPickup = true);
    try {
      final result = await DeliveryService.searchAddress(query);
      if (result['success'] == true) {
        final places = (result['places'] as List<dynamic>?)
                ?.map((p) => p as Map<String, dynamic>)
                .toList() ??
            [];
        setState(() {
          _pickupResults = places;
          _pickupSelected = null;
        });
      } else {
        throw Exception(result['error'] ?? 'Search failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingPickup = false);
    }
  }

  Future<void> _searchDropoff() async {
    final query = _dropoffSearchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type a delivery address to search')),
      );
      return;
    }
    setState(() => _isSearchingDropoff = true);
    try {
      final result = await DeliveryService.searchAddress(query);
      if (result['success'] == true) {
        final places = (result['places'] as List<dynamic>?)
                ?.map((p) => p as Map<String, dynamic>)
                .toList() ??
            [];
        setState(() {
          _dropoffResults = places;
          _dropoffSelected = null;
        });
      } else {
        throw Exception(result['error'] ?? 'Search failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingDropoff = false);
    }
  }

  bool _validateFields() {
    if (_pickupSelected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and confirm a pickup address')),
      );
      return false;
    }
    if (_dropoffSelected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please search and confirm a delivery address')),
      );
      return false;
    }
    return true;
  }

  Map<String, dynamic> _buildPickup() {
    return {
      'address': _pickupSelected!['address'],
      'latitude': _pickupSelected!['latitude'],
      'longitude': _pickupSelected!['longitude'],
      'name': _pickupNameController.text.trim(),
      'phone': _pickupPhoneController.text.trim(),
    };
  }

  Map<String, dynamic> _buildDropoff() {
    return {
      'address': _dropoffSelected!['address'],
      'latitude': _dropoffSelected!['latitude'],
      'longitude': _dropoffSelected!['longitude'],
      'name': _dropoffNameController.text.trim(),
      'phone': _dropoffPhoneController.text.trim(),
    };
  }

  Future<void> _getEstimate() async {
    if (!_validateFields()) return;

    setState(() => _isEstimating = true);
    try {
      final result = await DeliveryService.estimateDelivery(
        userId: widget.user.id,
        pickup: _buildPickup(),
        dropoff: _buildDropoff(),
        provider: _providerName,
        state: _selectedState ?? '',
      );

      if (result['success'] == true) {
        setState(() => _estimate = result);
      } else {
        throw Exception(result['error'] ?? 'Estimate failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estimate failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isEstimating = false);
    }
  }

  Future<void> _bookDelivery() async {
    if (!_validateFields()) return;
    if (_estimate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please get an estimate first')),
      );
      return;
    }

    setState(() => _isBooking = true);
    try {
      final riderCost = (_estimate!['rider_cost'] ?? 0).toDouble();

      final result = await DeliveryService.bookDelivery(
        userId: widget.user.id,
        pickup: _buildPickup(),
        dropoff: _buildDropoff(),
        provider: _providerName,
        riderCost: riderCost,
        notes: _notesController.text.trim(),
        state: _selectedState ?? '',
      );

      if (result['success'] == true) {
        final deliveryId = result['delivery_id'] as String?;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery booked! Opening payment...'),
              backgroundColor: Colors.green,
            ),
          );
          if (deliveryId != null) {
            await _initiatePaymentForDelivery(deliveryId);
          }
          widget.onBooked();
        }
      } else {
        throw Exception(result['error'] ?? 'Booking failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _initiatePaymentForDelivery(String deliveryId) async {
    try {
      final result = await DeliveryService.initiatePayment(
        deliveryId: deliveryId,
        email: widget.user.email,
        customerName: widget.user.businessName,
        customerPhone: widget.user.phoneNumber,
      );
      if (result['success'] == true) {
        final paymentLink = result['payment_link'] as String?;
        if (paymentLink != null) {
          await launchUrl(Uri.parse(paymentLink),
              mode: LaunchMode.externalApplication);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Payment opened in browser. Check your Active deliveries to verify payment after completing.'),
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Delivery created but payment initiation failed. Pay from Active deliveries. Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProviders) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State selector
          _buildSectionHeader('Your State'),
          DropdownButtonFormField<String>(
            value: _selectedState,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            items: _states
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedState = value;
                _estimate = null;
              });
            },
          ),
          const SizedBox(height: 12),

          // Provider info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_isGokada ? Icons.motorcycle : Icons.delivery_dining,
                    color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isGokada
                        ? 'Gokada — Automated dispatch via Gokada API (Lagos only)'
                        : 'SaleCentra Rider — A dispatch rider in $_selectedState will be assigned automatically.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader('Pickup Details'),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                    _pickupNameController, 'Pickup Name',
                    initialValue: widget.user.businessName),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                    _pickupPhoneController, 'Pickup Phone',
                    initialValue: widget.user.phoneNumber,
                    keyboardType: TextInputType.phone),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAddressSearch(
            controller: _pickupSearchController,
            onSearch: _searchPickup,
            isSearching: _isSearchingPickup,
            results: _pickupResults,
            selected: _pickupSelected,
            onSelect: (place) {
              setState(() {
                _pickupSelected = place;
                _pickupResults = [];
                _estimate = null;
              });
            },
            label: 'Search Pickup Address',
          ),

          const SizedBox(height: 20),
          _buildSectionHeader('Dropoff Details'),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                    _dropoffNameController, 'Customer Name'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                    _dropoffPhoneController, 'Customer Phone',
                    keyboardType: TextInputType.phone),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAddressSearch(
            controller: _dropoffSearchController,
            onSearch: _searchDropoff,
            isSearching: _isSearchingDropoff,
            results: _dropoffResults,
            selected: _dropoffSelected,
            onSelect: (place) {
              setState(() {
                _dropoffSelected = place;
                _dropoffResults = [];
                _estimate = null;
              });
            },
            label: 'Search Delivery Address',
          ),

          const SizedBox(height: 16),
          _buildTextField(_notesController, 'Notes (optional)', maxLines: 2),

          const SizedBox(height: 20),
          if (_estimate != null) ...[
            _buildEstimateCard(),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isEstimating ? null : _getEstimate,
                  child: _isEstimating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Get Estimate'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isBooking ? null : _bookDelivery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isBooking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Book Delivery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAddressSearch({
    required TextEditingController controller,
    required VoidCallback onSearch,
    required bool isSearching,
    required List<Map<String, dynamic>> results,
    required Map<String, dynamic>? selected,
    required ValueChanged<Map<String, dynamic>> onSelect,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: isSearching ? null : onSearch,
              icon: isSearching
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
            ),
          ],
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (context, index) {
                final place = results[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on, size: 18),
                  title: Text(
                    place['address'] ?? '',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelect(place),
                );
              },
            ),
          ),
        ],
        if (selected != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected['address'] ?? '',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    if (initialValue != null && controller.text.isEmpty) {
      controller.text = initialValue;
    }
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildEstimateCard() {
    final customerFee = (_estimate!['customer_fee'] ?? 0).toDouble();
    final riderCost = (_estimate!['rider_cost'] ?? 0).toDouble();
    final distance = _estimate!['distance_km'] ?? 0;

    return Card(
      color: AppTheme.primaryColor.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Distance',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                Text('${distance.toStringAsFixed(1)} km',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Delivery Fee',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                Text('\u20a6${riderCost.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Service Fee',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                Text('\u20a6${(customerFee - riderCost).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '\u20a6${customerFee.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
