import 'package:flutter/material.dart';
import '../models/article.dart';

class EducationHubScreen extends StatefulWidget {
  const EducationHubScreen({super.key});
  @override
  State<EducationHubScreen> createState() => _EducationHubScreenState();
}

class _EducationHubScreenState extends State<EducationHubScreen> {
  String _selectedCategory = 'All';

  List<String> get _categories => ['All', ...Article.categories];

  List<Article> get _filtered => _selectedCategory == 'All'
      ? Article.all
      : Article.all.where((a) => a.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category filter chips
        SizedBox(
          height: 48,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: _categories
                .map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (context, i) {
              final a = _filtered[i];
              return Card(
                child: ListTile(
                  leading: Text(a.emoji,
                      style: const TextStyle(fontSize: 32)),
                  title: Text(a.title,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${a.category} · ${a.readMinutes} min read\n${a.summary}'),
                  isThreeLine: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _ArticleDetailScreen(article: a)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArticleDetailScreen extends StatelessWidget {
  final Article article;
  const _ArticleDetailScreen({required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(article.category),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(article.emoji,
                style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(article.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${article.readMinutes} min read',
                style: const TextStyle(color: Colors.grey)),
            const Divider(height: 24),
            // Render basic markdown-like content
            ..._renderContent(context, article.content),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2F5233).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'This content is for educational purposes only and does not replace veterinary advice. Always consult your vet for health decisions.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _renderContent(BuildContext context, String content) {
    final lines = content.trim().split('\n');
    final widgets = <Widget>[];
    for (final line in lines) {
      if (line.startsWith('**') && line.endsWith('**')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            line.replaceAll('**', ''),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ));
      } else if (line.startsWith('- ') || line.startsWith('✓ ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• '),
              Expanded(
                  child: Text(line.replaceFirst(RegExp(r'^[-✓] '), ''))),
            ],
          ),
        ));
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(line.replaceAllMapped(
            RegExp(r'\*\*(.*?)\*\*'),
            (m) => m.group(1) ?? '',
          )),
        ));
      }
    }
    return widgets;
  }
}
