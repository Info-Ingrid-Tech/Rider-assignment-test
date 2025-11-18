import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/AssignmentOffer.dart';
import '../widgets/delivery_card.dart';
import 'delivery_history_screen.dart';
import 'earnings_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isOnline = false;
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  // Check if a dialog is already showing to prevent stacking
  bool _isDialogShowing = false;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    try {
      // Use set with merge: true to create the doc if it doesn't exist
      await FirebaseFirestore.instance.collection('Drivers').doc(uid).set({
        'status': value ? 'online' : 'offline',
        'isAvailable': value,
        'lastActive': FieldValue.serverTimestamp(), // Good for tracking
        'name': FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown Driver', // Ensure basic fields exist
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
      }, SetOptions(merge: true));

      setState(() {
        _isOnline = value;
      });
    } catch (e) {
      print("Error updating status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  // This function shows the AssignmentOffer widget in a dialog
  void _showAssignmentDialog(String assignmentId, String orderId) {
    if (_isDialogShowing) return;

    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.zero, // Full screen or close to it
          backgroundColor: Colors.transparent,
          child: AssignmentOffer(
            assignmentId: assignmentId,
            orderId: orderId,
            onDismiss: () {
              _isDialogShowing = false;
              Navigator.of(context).pop();
            },
          ),
        );
      },
    ).then((_) => _isDialogShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeTab(), // The main dashboard
      const DeliveryHistoryScreen(),
      const EarningsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Drivers').doc(uid).snapshots(),
      builder: (context, driverSnapshot) {
        if (!driverSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle case where document doesn't exist yet
        if (!driverSnapshot.data!.exists) {
          // Create it immediately if missing? Or show "Go Online" which will create it.
          // For now, let's treat it as offline.
        }

        var driverData = driverSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        bool isOnline = driverData['status'] == 'online';
        String? assignedOrderId = driverData['assignedOrderId'];

        // Sync local state
        if (_isOnline != isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isOnline = isOnline);
          });
        }

        return Stack(
          children: [
            // 1. LISTENER FOR NEW ASSIGNMENTS (The "Offer" Listener)
            if (isOnline && (assignedOrderId == null || assignedOrderId.isEmpty))
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rider_assignments')
                    .where('riderId', isEqualTo: uid)
                    .where('status', isEqualTo: 'pending')
                    .limit(1)
                    .snapshots(),
                builder: (context, assignmentSnapshot) {
                  if (assignmentSnapshot.hasData && assignmentSnapshot.data!.docs.isNotEmpty) {
                    var assignmentDoc = assignmentSnapshot.data!.docs.first;
                    var assignmentData = assignmentDoc.data() as Map<String, dynamic>;

                    // Trigger the dialog immediately
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showAssignmentDialog(assignmentDoc.id, assignmentData['orderId']);
                    });
                  }
                  return const SizedBox.shrink(); // Invisible widget
                },
              ),

            // 2. MAIN UI CONTENT
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 100.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                    title: Text(
                      isOnline ? 'You are Online' : 'You are Offline',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    background: Container(color: Theme.of(context).scaffoldBackgroundColor),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: isOnline,
                          onChanged: _toggleOnlineStatus,
                          activeColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // STATUS CARD
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isOnline ? Colors.green.shade200 : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isOnline ? Colors.green : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.power_settings_new, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOnline ? 'Ready for Orders' : 'Go Online',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isOnline ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                  Text(
                                    isOnline
                                        ? 'Waiting for new requests...'
                                        : 'Switch on to start receiving orders',
                                    style: TextStyle(
                                      color: isOnline ? Colors.green.shade600 : Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ACTIVE ORDER CARD (If assigned)
                        // Guard: Ensure assignedOrderId is truly valid string
                        if (assignedOrderId != null && assignedOrderId.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Current Delivery", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              // Fetch order details to pass to DeliveryCard
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('Orders').doc(assignedOrderId).get(),
                                builder: (context, orderSnapshot) {
                                  if (!orderSnapshot.hasData) {
                                    return const Center(child: CircularProgressIndicator());
                                  }

                                  if (!orderSnapshot.data!.exists) {
                                    return const Text("Error: Order not found");
                                  }

                                  // Get the order data
                                  var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
                                  // Determine status color
                                  Color statusColor = Colors.blue;
                                  String status = orderData['status'] ?? 'pending';
                                  if (status == 'picked_up') statusColor = Colors.orange;
                                  if (status == 'delivered') statusColor = Colors.green;

                                  // EXTRA GUARD: Don't build if we don't have data yet
                                  if (orderData.isEmpty) return const SizedBox.shrink();

                                  return DeliveryCard(
                                    orderId: assignedOrderId,
                                    orderData: orderData,
                                    statusColor: statusColor,
                                  );
                                },
                              ),
                            ],
                          )
                        else if (isOnline)
                        // Placeholder image when waiting
                          Column(
                            children: [
                              const SizedBox(height: 40),
                              Icon(Icons.delivery_dining, size: 100, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text("No active orders", style: TextStyle(color: Colors.grey.shade500)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
