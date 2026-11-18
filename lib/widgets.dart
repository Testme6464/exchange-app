// Shared widgets and helpers: cards, pills, order rows, slip images
// with zoom, copy buttons, the floating Telegram/Viber buttons, and
// slip-photo picking with client-side compression (mirrors the
// website's compressImage: max 1200px, JPEG quality 0.82).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'contact_icons.dart';
import 'models.dart';
import 'quote.dart';
import 'store.dart';
import 'strings.dart';
import 'theme.dart';

// ---------------------------------------------------------------------
// Layout primitives
// ---------------------------------------------------------------------

/// White card with the website's radius + soft shadow.
class AppCard extends StatelessWidget {
  const AppCard({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

/// Key/value row, mirroring the website's .kv rows.
class KvRow extends StatelessWidget {
  const KvRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading inside a card.
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}

/// Red inline error line under a form (empty when [text] is empty).
class FieldError extends StatelessWidget {
  const FieldError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.red, fontSize: 13),
      ),
    );
  }
}

/// Centered muted placeholder text (website's .empty).
class EmptyText extends StatelessWidget {
  const EmptyText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.red, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(s('retryAction')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Pills + chips
// ---------------------------------------------------------------------

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = statusPillColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: colors.fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class OpenClosedPill extends StatelessWidget {
  const OpenClosedPill(this.isOpen, {super.key});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.blue : AppColors.line,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOpen ? s('openNow') : s('closedNow'),
        style: TextStyle(
          color: isOpen ? Colors.white : AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Wrap of selectable chips (status filters, range filters, direction).
class ChipRow extends StatelessWidget {
  const ChipRow({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<({String id, String label})> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        return ChoiceChip(
          label: Text(opt.label),
          selected: selected == opt.id,
          onSelected: (_) => onSelected(opt.id),
        );
      }).toList(),
    );
  }
}

// Dropdown styled like the other form fields (label + bordered box),
// backed by DropdownButton so the selected value stays controlled by
// the parent (DropdownButtonFormField.value is deprecated in favor of
// an uncontrolled initialValue, which would not follow programmatic
// changes such as "use saved receiver").
class LabeledDropdown extends StatelessWidget {
  const LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final List<({String value, String label})> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item.value,
                child: Text(item.label),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Snackbars, copy, confirm
// ---------------------------------------------------------------------

void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.red : AppColors.ink,
    ),
  );
}

/// Mirrors the website's copy button: copies + shows the "copied" toast.
Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showSnack(context, s('copied'));
}

/// Confirmation dialog; returns true when the user confirms.
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String body,
  String? confirmLabel,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17)),
      content: Text(body, style: const TextStyle(fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(s('dialogCancel')),
        ),
        ElevatedButton(
          style: danger
              ? ElevatedButton.styleFrom(backgroundColor: AppColors.red)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel ?? s('dialogConfirm')),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Maps a store/auth error to the website's authErrorMessage() text.
String authErrorMessage(Object e) {
  if (e is StoreException) {
    switch (e.code) {
      case 'blocked':
        return s('blockedMsg');
      case 'email_in_use':
        return s('emailInUse');
      case 'wrong_password':
      case 'invalid_credentials':
        return s('loginFailed');
    }
  }
  return s('errorGeneric');
}

// ---------------------------------------------------------------------
// Order rows
// ---------------------------------------------------------------------

/// One order in a list — mirrors orderItemHtml() in js/app.js.
class OrderRow extends StatelessWidget {
  const OrderRow({required this.order, this.onTap, this.leading, super.key});

  final Order order;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNo,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        StatusPill(order.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fmtMoney(order.sendAmount, order.sendCurrency)} → '
                      '${fmtMoney(order.receiveAmount, order.receiveCurrency)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blueDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${orderDirectionLabel(order.direction)} · '
                      '${s('rate')} ${fmtNum(order.rate, 2)} · '
                      '${fmtDateTime(order.createdAt)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Slip / proof images (signed URLs + zoom)
// ---------------------------------------------------------------------

/// Loads a private-bucket image through a 1-hour signed URL and shows it.
/// Tapping opens the zoom dialog (InteractiveViewer), like the website's
/// slip zoom overlay.
class SlipImage extends StatelessWidget {
  const SlipImage({
    required this.store,
    required this.bucket,
    required this.path,
    this.height = 180,
    this.zoomable = true,
    super.key,
  });

  final ExchangeStore store;
  final String bucket;
  final String path;
  final double height;
  final bool zoomable;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: store.getFileUrl(bucket, path),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (url == null) {
          return SizedBox(
            height: height,
            child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.muted, size: 40),
            ),
          );
        }
        final image = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                height: height,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (ctx, _, _) => SizedBox(
              height: height,
              child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.muted, size: 40),
              ),
            ),
          ),
        );
        if (!zoomable) return image;
        return GestureDetector(
          onTap: () => showImageZoom(context, url),
          child: image,
        );
      },
    );
  }
}

void showImageZoom(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          InteractiveViewer(
            child: Center(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
              tooltip: s('close'),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------
// Floating Telegram / Viber buttons
// ---------------------------------------------------------------------

/// Floating contact buttons, mirroring renderContactFloat() in js/app.js:
/// shown on every page when either contact link exists, built from the
/// shop settings (Telegram handle + phone number).
class ContactFloat extends StatelessWidget {
  const ContactFloat({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final tg = telegramLink(settings.shop.contactTelegram);
    final vb = viberLink(settings.shop.contactPhone);
    if (tg.isEmpty && vb.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tg.isNotEmpty)
          _ContactButton(
            color: AppColors.telegram,
            iconSvg: telegramIconSvg,
            label: 'Telegram',
            url: tg,
          ),
        if (tg.isNotEmpty && vb.isNotEmpty) const SizedBox(height: 10),
        if (vb.isNotEmpty)
          _ContactButton(
            color: AppColors.viber,
            iconSvg: viberIconSvg,
            label: 'Viber',
            url: vb,
          ),
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.color,
    required this.iconSvg,
    required this.label,
    required this.url,
  });

  final Color color;
  final String iconSvg;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: FloatingActionButton(
        heroTag: label,
        backgroundColor: color,
        elevation: 4,
        tooltip: label,
        onPressed: () async {
          final uri = Uri.parse(url);
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!ok && context.mounted) showSnack(context, s('errorGeneric'), isError: true);
        },
        child: SvgPicture.string(iconSvg, width: 28, height: 28),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Slip photo picking + compression
// ---------------------------------------------------------------------

class PickedImage {
  const PickedImage({required this.bytes, required this.fileName});

  final List<int> bytes;
  final String fileName;
}

/// Mirrors compressImage() in js/app.js: images are resized so the
/// longest side is at most 1200px and re-encoded as JPEG quality 0.82.
/// Un-decodable input passes through unchanged.
List<int> compressImageBytes(List<int> raw) {
  final decoded = img.decodeImage(Uint8List.fromList(raw));
  if (decoded == null) return raw;
  img.Image out = decoded;
  final longest = math.max(decoded.width, decoded.height);
  if (longest > 1200) {
    final scale = 1200 / longest;
    out = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
    );
  }
  return img.encodeJpg(out, quality: 82);
}

/// Bottom sheet offering Camera / Gallery, then picks + compresses.
/// Returns null when the user dismisses the sheet or cancels the picker.
Future<PickedImage?> pickSlipImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              s('pickPhotoTitle'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(s('pickCamera')),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(s('pickGallery')),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final picked = await ImagePicker().pickImage(source: source);
  if (picked == null) return null;
  final raw = await picked.readAsBytes();
  return PickedImage(
    bytes: compressImageBytes(raw),
    fileName: picked.name,
  );
}
