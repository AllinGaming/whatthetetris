import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const triangleGameUrl = 'https://allingaming.github.io/whatthetetris/';

enum TriangleShareAction { copy, x, facebook, whatsapp }

/// Shows only the sharing destinations the game intentionally supports.
/// This avoids the operating-system share sheet, where email clients cannot
/// be reliably hidden, and gives web/desktop players the same choices.
Future<TriangleShareAction?> showTriangleShareDialog(
  BuildContext context, {
  required String title,
  required String message,
  String copyLabel = 'Copy game link',
  String? copyText,
}) {
  return showDialog<TriangleShareAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            _ShareOption(
              icon: Icons.link,
              label: copyLabel,
              opensExternalApp: false,
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(text: copyText ?? triangleGameUrl),
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(TriangleShareAction.copy);
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$copyLabel copied.')));
              },
            ),
            _ShareOption(
              icon: Icons.alternate_email,
              label: 'Share on X',
              onTap: () => _launchSocial(
                pageContext: context,
                dialogContext: dialogContext,
                action: TriangleShareAction.x,
                uri: Uri.https('twitter.com', '/intent/tweet', {
                  'text': '$message\n$triangleGameUrl',
                }),
              ),
            ),
            _ShareOption(
              icon: Icons.facebook,
              label: 'Share on Facebook',
              onTap: () => _launchSocial(
                pageContext: context,
                dialogContext: dialogContext,
                action: TriangleShareAction.facebook,
                uri: Uri.https('www.facebook.com', '/sharer/sharer.php', {
                  'u': triangleGameUrl,
                  'quote': message,
                }),
              ),
            ),
            _ShareOption(
              icon: Icons.chat_bubble_outline,
              label: 'Share on WhatsApp',
              onTap: () => _launchSocial(
                pageContext: context,
                dialogContext: dialogContext,
                action: TriangleShareAction.whatsapp,
                uri: Uri.https('wa.me', '/', {
                  'text': '$message\n$triangleGameUrl',
                }),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

Future<void> _launchSocial({
  required BuildContext pageContext,
  required BuildContext dialogContext,
  required TriangleShareAction action,
  required Uri uri,
}) async {
  var launched = false;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    launched = false;
  }
  if (!dialogContext.mounted) return;
  if (launched) {
    Navigator.of(dialogContext).pop(action);
    return;
  }
  if (!pageContext.mounted) return;
  ScaffoldMessenger.of(pageContext).showSnackBar(
    const SnackBar(
      content: Text('Could not open that app. You can copy the link instead.'),
    ),
  );
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.opensExternalApp = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool opensExternalApp;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: Icon(
        opensExternalApp ? Icons.open_in_new : Icons.copy,
        size: 18,
      ),
      onTap: onTap,
    );
  }
}
