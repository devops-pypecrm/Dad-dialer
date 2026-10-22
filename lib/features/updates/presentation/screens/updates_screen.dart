import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/apk_download_controller.dart';
import '../../providers/apk_download_state.dart';
import '../../providers/app_update_provider.dart';

/// Reached via Settings, not a bottom-nav tab — shows the running build's
/// own version alongside whatever's currently published, and drives the
/// in-app download+install flow (`ApkDownloadController`) entirely. Mirrors
/// Dad-mobile/Dad-call-recorder's `UpdatesScreen`, plus two additions: a
/// live downloaded/total byte-size readout (not just a percentage), and a
/// "not working?" fallback linking to the public download page for anyone
/// the in-app flow fails for (a permission they won't grant, an OS quirk,
/// etc).
class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentInfoAsync = ref.watch(currentPackageInfoProvider);
    final updateAsync = ref.watch(availableUpdateProvider);
    final downloadState = ref.watch(apkDownloadControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Updates')),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.refresh(latestDialerReleaseProvider.future),
          ref.refresh(availableUpdateProvider.future),
        ]),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: currentInfoAsync.when(
                  data: (info) => Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: kBrandColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.smartphone_outlined, color: kBrandColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('You have', style: theme.textTheme.bodySmall),
                            Text(
                              'Version ${info.version} (${info.buildNumber})',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Text('Could not read app version: $error'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            updateAsync.when(
              data: (update) {
                if (update == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
                          SizedBox(width: 12),
                          Expanded(child: Text("You're up to date.")),
                        ],
                      ),
                    ),
                  );
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.new_releases_outlined, color: kBrandColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Version ${update.versionName} is available',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (update.releaseNotes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(update.releaseNotes, style: theme.textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 16),
                        _DownloadInstallSection(state: downloadState),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Could not check for updates: $error'),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(availableUpdateProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `received`/`total` in bytes -> "12.3 MB / 45.0 MB". `total` can be -1
/// (server didn't send a Content-Length yet, or on the very first
/// callback) — falls back to showing just what's been received so far.
String _formatBytes(int received, int total) {
  String mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
  if (total <= 0) return '${mb(received)} MB';
  return '${mb(received)} MB / ${mb(total)} MB';
}

/// The actual download/permission/install UI, switched entirely on
/// [ApkDownloadState] — kept as its own widget so `UpdatesScreen.build`
/// isn't one giant nested `switch`.
class _DownloadInstallSection extends ConsumerWidget {
  const _DownloadInstallSection({required this.state});

  final ApkDownloadState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(apkDownloadControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        state.when(
          idle: () => SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => notifier.downloadAndInstall(),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download & Install'),
            ),
          ),
          downloading: (progress, receivedBytes, totalBytes) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progress > 0 ? progress : null, minHeight: 8),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    progress > 0 ? 'Downloading… ${(progress * 100).toStringAsFixed(0)}%' : 'Downloading…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    _formatBytes(receivedBytes, totalBytes),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          permissionNeeded: (filePath) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pype Dialer needs permission to install updates. '
                'Enable "Allow from this source" in the settings screen, then come back and tap Install.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: notifier.openPermissionSettings,
                      child: const Text('Open Settings'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => notifier.retryInstall(filePath),
                      child: const Text('Install'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          installLaunched: (filePath) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Installer opened — follow the prompt to finish updating.')),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Closed it by accident? You don't need to re-download.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                onPressed: () => notifier.retryInstall(filePath),
                label: const Text('Reopen installer'),
              ),
            ],
          ),
          error: (message, filePath) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Something went wrong: $message', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  // If the .apk already finished downloading and only the
                  // install step failed, retry just that instead of
                  // pulling the whole file down again.
                  onPressed: () =>
                      filePath != null ? notifier.retryInstall(filePath) : notifier.downloadAndInstall(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        _NotWorkingLink(),
      ],
    );
  }
}

/// Always-visible fallback regardless of [ApkDownloadState] — the in-app
/// flow can fail in ways this app can't recover from itself (a permission
/// the user won't grant, a flaky connection, an OS quirk on a specific
/// OEM), so there's always a way out to the plain browser download that
/// doesn't depend on any of this app's own code working.
class _NotWorkingLink extends StatelessWidget {
  const _NotWorkingLink();

  static const _downloadPageUrl = 'https://pypecrm.com/download';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => launchUrl(Uri.parse(_downloadPageUrl), mode: LaunchMode.externalApplication),
        child: const Text('Not working? Download directly from pypecrm.com'),
      ),
    );
  }
}
