import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/premium_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isPremium = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ps = context.read<PremiumService>();
    final v = await ps.isPremium();
    setState(() { _isPremium = v; _loading = false; });
  }

  Future<void> _upgrade() async {
    // In production: integrate RevenueCat, Stripe, or in-app purchases here.
    // For now, this simulates a successful purchase.
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1)); // simulate payment
    await context.read<PremiumService>().activatePremium();
    setState(() { _isPremium = true; _loading = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Premium activated!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NutriEquine Premium')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F5233),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          _isPremium
                              ? 'You\'re a Premium member!'
                              : 'Upgrade to Premium',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        if (!_isPremium) ...[
                          const SizedBox(height: 4),
                          const Text(
                            '\$9.99 / month',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _FeatureSection(
                    title: 'Free',
                    features: PremiumService.freeFeatures,
                    color: Colors.grey,
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 16),
                  _FeatureSection(
                    title: 'Premium',
                    features: PremiumService.premiumFeatures,
                    color: const Color(0xFF2F5233),
                    icon: Icons.star,
                  ),
                  const SizedBox(height: 24),
                  if (!_isPremium)
                    FilledButton(
                      onPressed: _upgrade,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Upgrade Now — \$9.99/month',
                          style: TextStyle(fontSize: 16)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Premium Active',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cancel anytime. Payment processed securely. Premium features activate immediately after purchase.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  final String title;
  final List<String> features;
  final Color color;
  final IconData icon;
  const _FeatureSection(
      {required this.title,
      required this.features,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            const SizedBox(height: 10),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
