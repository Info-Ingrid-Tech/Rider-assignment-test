import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// import 'package:just_audio/just_audio.dart'; // Optional: Add sound here if you want

class AssignmentOffer extends StatefulWidget {
  final String assignmentId;
  final String orderId;
  final VoidCallback onDismiss;

  const AssignmentOffer({
    super.key,
    required this.assignmentId,
    required this.orderId,
    required this.onDismiss,
  });

  @override
  State<AssignmentOffer> createState() => _AssignmentOfferState();
}

class _AssignmentOfferState extends State<AssignmentOffer> {
  int _secondsRemaining = 120; // Matches your server timeout
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // _playSound(); // Optional sound play
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        widget.onDismiss(); // Auto dismiss on timeout
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _respondToOffer(String status) async {
    setState(() => _isLoading = true);
    try {
      // Update the assignment status.
      // The Cloud Function "handleRiderAcceptance" (Step 6) will listen to this.
      await FirebaseFirestore.instance
          .collection('rider_assignments')
          .doc(widget.assignmentId) // Use assignmentId (which is usually the orderId)
          .update({'status': status});

      widget.onDismiss(); // Close the dialog
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.6),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)
            ],
          ),
          child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('Orders').doc(widget.orderId).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator())
                  );
                }

                final orderData = snapshot.data!.data() as Map<String, dynamic>;
                final double totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
                final String address = orderData['deliveryAddress']?['street'] ?? 'Unknown Address';
                final String distance = "3.5 km"; // You can calculate this if you have lat/lng

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with Countdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "New Order Request",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _secondsRemaining < 30 ? Colors.red.shade100 : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "00:${_secondsRemaining.toString().padLeft(2, '0')}",
                            style: TextStyle(
                              color: _secondsRemaining < 30 ? Colors.red : Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    // Price & Distance
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.green, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              "QAR ${totalAmount.toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text("Earnings", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        Container(height: 40, width: 1, color: Colors.grey.shade300),
                        Column(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              distance,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text("Distance", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Address
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.home_work_outlined, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              address,
                              style: const TextStyle(fontSize: 14, height: 1.4),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _respondToOffer('rejected'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Reject", style: TextStyle(color: Colors.red, fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _respondToOffer('accepted'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text("Accept", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              }
          ),
        ),
      ),
    );
  }
}