import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Digital clock widget that displays current time and updates every second
class DigitalClock extends StatelessWidget {
  final TextStyle? timeStyle;
  final TextStyle? dateStyle;
  final Color? backgroundColor;
  final bool showDate;
  final bool showSeconds;
  final bool autoSize;
  final int maxFontSize;
  final bool blinkSeparator;
  final bool use24HourFormat;
  final Locale? locale;
  final String? dateFormat;

  const DigitalClock({
    super.key,
    this.timeStyle,
    this.dateStyle,
    this.backgroundColor,
    this.showDate = true,
    this.showSeconds = true,
    this.autoSize = false,
    this.maxFontSize = 80,
    this.blinkSeparator = false,
    this.use24HourFormat = true,
    this.locale,
    this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();

        // Get effective locale (from parameter or system)
        final effectiveLocale = locale ?? Localizations.localeOf(context);

        // Format date with locale support
        final dateString = dateFormat != null
            ? DateFormat(dateFormat, effectiveLocale.toString()).format(now)
            : DateFormat.yMMMEd(effectiveLocale.toString()).format(now);

        // Calculate hour based on format
        final int hour24 = now.hour;
        final int hour12 = hour24 == 0
            ? 12
            : hour24 > 12
                ? hour24 - 12
                : hour24;
        final String period = hour24 >= 12 ? 'PM' : 'AM';

        // Format time parts
        final int displayHour = use24HourFormat ? hour24 : hour12;
        final String h = displayHour.toString().padLeft(2, '0');
        final String m = now.minute.toString().padLeft(2, '0');
        final String s = now.second.toString().padLeft(2, '0');

        // Build base text styles
        final baseTimeStyle = timeStyle ??
            Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: autoSize ? maxFontSize.toDouble() : null,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [const FontFeature.tabularFigures()],
                );

        final baseDateStyle = dateStyle ??
            Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: autoSize ? maxFontSize / 4 : null,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                );

        // Build time widget
        Widget timeWidget;
        if (blinkSeparator && !showSeconds) {
          // Use RichText with opacity for blinking separators (no visual jump)
          final separatorOpacity = now.second.isEven ? 1.0 : 0.0;
          final separatorColor = baseTimeStyle?.color?.withValues(alpha: separatorOpacity);

          timeWidget = Text.rich(
            TextSpan(
              style: baseTimeStyle,
              children: [
                TextSpan(text: h),
                TextSpan(
                  text: ':',
                  style: TextStyle(color: separatorColor),
                ),
                TextSpan(text: m),
                if (showSeconds) ...[
                  TextSpan(
                    text: ':',
                    style: TextStyle(color: separatorColor),
                  ),
                  TextSpan(text: s),
                ],
                // Add AM/PM indicator for 12-hour format
                if (!use24HourFormat) ...[
                  const TextSpan(text: ''),
                  TextSpan(
                    text: period,
                    style: baseDateStyle,
                  ),
                ],
              ],
            ),
          );
        } else {
          // Standard text without blinking
          final timeString = showSeconds ? '$h:$m:$s' : '$h:$m';

          if (!use24HourFormat) {
            // Include AM/PM with smaller font
            timeWidget = Text.rich(
              TextSpan(
                style: baseTimeStyle,
                children: [
                  TextSpan(text: timeString),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: period,
                    style: baseDateStyle,
                  ),
                ],
              ),
            );
          } else {
            // Standard 24h format
            timeWidget = Text(
              timeString,
              style: baseTimeStyle,
            );
          }
        }

        // Build date widget
        Widget? dateWidget = showDate
            ? Text(
                dateString,
                style: baseDateStyle,
              )
            : null;

        // Combine time and date
        Widget clockContent = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            timeWidget,
            if (dateWidget != null) ...[
              const SizedBox(height: 8),
              dateWidget,
            ],
          ],
        );

        // Apply FittedBox if autoSize enabled
        if (autoSize) {
          clockContent = FittedBox(
            fit: BoxFit.scaleDown,
            child: clockContent,
          );
        }

        return Container(
          padding: backgroundColor != null
              ? const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0)
              : null,
          decoration: backgroundColor != null
              ? BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8.0),
                )
              : null,
          child: clockContent,
        );
      },
    );
  }
}
