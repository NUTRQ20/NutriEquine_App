import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  static const _storeUrl = 'https://nutriequine.com';

  static const _products = [
    _Product(
      name: 'NutriEquine GutCare',
      tagline: 'Advanced Digestive Support',
      description:
          'A scientifically formulated blend of prebiotics, probiotics, and digestive '
          'enzymes designed to support your horse\'s gut health. Helps maintain '
          'a balanced microbiome, reduce the risk of digestive upset, and '
          'support optimal nutrient absorption.',
      dosage: '1 scoop daily',
      duration: '30-day supply',
      emoji: '🌿',
      color: Color(0xFF2F5233),
    ),
    _Product(
      name: 'NutriEquine FlexSupport',
      tagline: 'Joint & Mobility Formula',
      description:
          'A premium joint supplement combining glucosamine, chondroitin, MSM, '
          'and hyaluronic acid. Supports cartilage health, reduces inflammation, '
          'and promotes ease of movement — ideal for performance and senior horses.',
      dosage: '2 scoops daily',
      duration: '30-day supply',
      emoji: '💪',
      color: Color(0xFF1565C0),
    ),
    _Product(
      name: 'NutriEquine CoatShine',
      tagline: 'Coat, Skin & Hoof Health',
      description:
          'An Omega-3 and biotin-rich formula that promotes a healthy, glossy coat, '
          'supple skin, and strong hoof growth. Contains flaxseed, biotin, zinc, '
          'and copper for comprehensive external health support.',
      dosage: '1 scoop daily',
      duration: '45-day supply',
      emoji: '✨',
      color: Color(0xFFF57C00),
    ),
    _Product(
      name: 'NutriEquine RecoveryBlend',
      tagline: 'Post-Exercise Recovery',
      description:
          'A targeted electrolyte and amino acid formula to support rapid recovery '
          'after intense training sessions or competition. Replenishes minerals lost '
          'through sweat and provides the building blocks for muscle repair.',
      dosage: '1 sachet after exercise',
      duration: '20-day supply',
      emoji: '⚡',
      color: Color(0xFF6A1B9A),
    ),
    _Product(
      name: 'NutriEquine CalmMag',
      tagline: 'Magnesium for Nervous Support',
      description:
          'A bioavailable magnesium supplement that helps reduce anxiety, '
          'nervousness, and excitability in horses. Supports healthy muscle '
          'function and promotes a calm, focused temperament — ideal for '
          'horses that are tense or spooky.',
      dosage: '1 scoop daily',
      duration: '30-day supply',
      emoji: '🧘',
      color: Color(0xFF00838F),
    ),
    _Product(
      name: 'NutriEquine DailyFoundation',
      tagline: 'Complete Daily Multivitamin',
      description:
          'A comprehensive daily vitamin and mineral supplement that fills '
          'nutritional gaps in your horse\'s diet. Contains vitamins A, D, E, '
          'B-complex, and key trace minerals to support immune function, energy '
          'metabolism, and overall wellbeing.',
      dosage: '2 scoops daily',
      duration: '30-day supply',
      emoji: '💊',
      color: Color(0xFFC62828),
    ),
  ];

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.parse(_storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open nutriequine.com'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Shop header banner
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2F5233), Color(0xFF4CAF50)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🐴 NutriEquine Shop',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Premium horse care supplements\ndelivered to your stable.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => _openStore(context),
                    icon: const Icon(Icons.open_in_browser, size: 18),
                    label: const Text('Visit nutriequine.com'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2F5233),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Product list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final p = _products[index];
                return _ProductCard(
                  product: p,
                  onBuy: () => _openStore(context),
                );
              },
              childCount: _products.length,
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Product card ─────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final _Product product;
  final VoidCallback onBuy;

  const _ProductCard({
    required this.product,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emoji icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: product.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      product.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: product.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.tagline,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              product.description,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 12),

            // Dosage and duration chips
            Row(
              children: [
                _InfoChip(
                  icon: Icons.medical_services_outlined,
                  label: product.dosage,
                  color: product.color,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: product.duration,
                  color: product.color,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Buy button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onBuy,
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: const Text('Buy / Purchase'),
                style: FilledButton.styleFrom(
                  backgroundColor: product.color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Redirects to nutriequine.com for checkout',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Product data model ───────────────────────────────────────────────
class _Product {
  final String name;
  final String tagline;
  final String description;
  final String dosage;
  final String duration;
  final String emoji;
  final Color color;

  const _Product({
    required this.name,
    required this.tagline,
    required this.description,
    required this.dosage,
    required this.duration,
    required this.emoji,
    required this.color,
  });
}
