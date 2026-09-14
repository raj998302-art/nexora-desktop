import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ui_provider.dart';
import '../widgets/nexora_ui.dart';

/// Extensions marketplace panel — visual port of the Web Prototype's
/// ExtensionPanel (mock catalog; install buttons are non-functional by
/// design in this phase).
class ExtensionPanel extends StatelessWidget {
  const ExtensionPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return Container(
      color: c.activityBar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: NexoraField(
              controller: TextEditingController(),
              hint: 'Search Extensions...',
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              children: const [
                _ExtensionCard(
                  name: 'Prettier - Code formatter',
                  author: 'Prettier',
                  desc: 'Code formatter using prettier',
                  installs: '40M',
                ),
                _ExtensionCard(
                  name: 'ESLint',
                  author: 'Microsoft',
                  desc: 'Integrates ESLint JavaScript into VS Code.',
                  installs: '35M',
                ),
                _ExtensionCard(
                  name: 'Python',
                  author: 'Microsoft',
                  desc: 'IntelliSense, Linting, Debugging.',
                  installs: '100M',
                ),
                _ExtensionCard(
                  name: 'GitLens — supercharged',
                  author: 'GitKraken',
                  desc: 'Supercharge Git within VS Code.',
                  installs: '30M',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  final String name;
  final String author;
  final String desc;
  final String installs;

  const _ExtensionCard({
    required this.name,
    required this.author,
    required this.desc,
    required this.installs,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: NxMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.hoverBackground2,
                borderRadius: BorderRadius.circular(6),
              ),
              child:
                  Icon(Icons.inventory_2_outlined, size: 20, color: c.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.textOnAccent)),
                  const SizedBox(height: 2),
                  Text(desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(author,
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: c.textSecondary)),
                      const SizedBox(width: 10),
                      Icon(Icons.download_outlined,
                          size: 10, color: c.textSecondary),
                      const SizedBox(width: 2),
                      Text(installs,
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: c.textSecondary)),
                      const SizedBox(width: 10),
                      Icon(Icons.star_outline,
                          size: 10, color: c.textSecondary),
                      const SizedBox(width: 2),
                      Text('4.5',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: c.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  NexoraPrimaryButton(
                    onPressed: () {},
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    child: const Text('Install',
                        style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
