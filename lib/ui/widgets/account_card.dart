import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/crypto/base32.dart';
import '../../core/crypto/otp_engine.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import 'brand_icon.dart';
import 'countdown_ring.dart';

class AccountCard extends StatefulWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.now,
    required this.hideCode,
    required this.onCopy,
    required this.onMenu,
    required this.otp,
  });

  final TotpAccount account;
  final DateTime now;
  final bool hideCode;
  final VoidCallback onCopy;
  final VoidCallback onMenu;
  final OtpEngine otp;

  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  bool revealed = false;

  @override
  void didUpdateWidget(covariant AccountCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.id != widget.account.id) revealed = false;
  }

  @override
  Widget build(BuildContext context) {
    final secret = Base32.decode(widget.account.secret);
    final code = widget.otp.totp(
      secret: secret,
      time: widget.now,
      digits: widget.account.digits,
      period: widget.account.period,
      algorithm: widget.account.algorithm,
    );
    final remaining = widget.otp.remainingSeconds(
      time: widget.now,
      period: widget.account.period,
    );
    final progress = widget.otp.progress(
      time: widget.now,
      period: widget.account.period,
    );
    final hidden = widget.hideCode && !revealed;
    final pretty = hidden ? '••• •••' : widget.otp.formatCode(code);
    final width = MediaQuery.sizeOf(context).width;
    final codeSize = width < 360 ? 28.0 : 34.0;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          if (hidden) {
            setState(() => revealed = true);
            return;
          }
          HapticFeedback.mediumImpact();
          Clipboard.setData(ClipboardData(text: code));
          widget.onCopy();
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BrandIcon(
                    name: widget.account.issuer,
                    extra: widget.account.label,
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.account.issuer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.account.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Account options',
                    onPressed: widget.onMenu,
                    icon: const Icon(Icons.more_horiz, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: hidden
                          ? 'Code hidden. Tap to reveal.'
                          : 'One-time code ${widget.otp.formatCode(code)}. Tap to copy.',
                      excludeSemantics: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          pretty,
                          style: TextStyle(
                            fontSize: codeSize,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  CountdownRing(progress: progress, seconds: remaining),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
