import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  static const _products = [
    _Product(
      name: 'Muscle +   Joint Supplement Powder',
      tagline: 'Enhance Muscle Strength',
      description:
          'A scientifically formulated blend of prebiotics, probiotics, and digestive '
          'enzymes designed to support your horse\'s gut health. Helps maintain '
          'a balanced microbiome, reduce the risk of digestive upset, and '
          'support optimal nutrient absorption.',
      dosage: 'Atleast 1 scoop daily',
      duration: '60-day supply',
      imagePath: 'assets/images/products/musclelogo.png',
      productUrl:
          'https://nutriequine.com/products/nutriequine-muscle-joint-supplement-powder',
      color: Color(0xFF2F5233),
    )
  ];

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not open the page. Check your internet connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
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
          // ── Header banner ─────────────────────────────────────────
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
                    onPressed: () => _openUrl(context,
                        'https://nutriequine.com/collections/shop-all'),
                    icon: const Icon(Icons.open_in_browser, size: 18),
                    label: const Text('Browse all products'),
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

          // ── Product list ──────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final p = _products[index];
                return _ProductCard(
                  product: p,
                  onBuy: () => _openUrl(context, p.productUrl),
                );
              },
              childCount: _products.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Product Card ─────────────────────────────────────────────────────
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Product image ───────────────────────────────────────
          Container(
            width: double.infinity,
            height: 200,
            color: Colors.white,
            child: Image.asset(
              product.imagePath,
              fit: BoxFit.contain, // ← was BoxFit.cover (was cropping)
              errorBuilder: (_, __, ___) => Container(
                color: product.color.withValues(alpha: 0.08),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined,
                          size: 48,
                          color: product.color.withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      Text(
                        product.name,
                        style: TextStyle(
                          color: product.color.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Product details ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + tagline
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 16,
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
                const SizedBox(height: 10),

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

                // Dosage + duration chips
                Row(
                  children: [
                    _Chip(
                      icon: Icons.medical_services_outlined,
                      label: product.dosage,
                      color: product.color,
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      icon: Icons.calendar_today_outlined,
                      label: product.duration,
                      color: product.color,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Buy button → specific product URL
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onBuy,
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: const Text(
                      'Buy / Purchase',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: product.color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Opens nutriequine.com for checkout',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Chip ────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

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

// ── Product model ────────────────────────────────────────────────────
class _Product {
  final String name;
  final String tagline;
  final String description;
  final String dosage;
  final String duration;
  final String imagePath;
  final String productUrl;
  final Color color;

  const _Product({
    required this.name,
    required this.tagline,
    required this.description,
    required this.dosage,
    required this.duration,
    required this.imagePath,
    required this.productUrl,
    required this.color,
  });
}
