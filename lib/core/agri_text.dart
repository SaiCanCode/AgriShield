import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

class AgriText extends StatelessWidget {
  const AgriText(
    this.text, {
    super.key,
    this.size = 14,
    this.weight = FontWeight.w400,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.letterSpacing,
    this.height,
    this.decoration,
    this.serif = false,
  });

  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? letterSpacing;
  final double? height;
  final TextDecoration? decoration;
  final bool serif;

  // Heading 1 — 28px Bold
  factory AgriText.h1(
    String text, {
    Key? key,
    Color? color,
    TextAlign? textAlign,
  }) => AgriText(
    text,
    key: key,
    size: 28,
    weight: FontWeight.w700,
    color: color,
    textAlign: textAlign,
    height: 1.1,
    serif: true,
  );

  // Heading 2 — 22px SemiBold
  factory AgriText.h2(
    String text, {
    Key? key,
    Color? color,
    TextAlign? textAlign,
  }) => AgriText(
    text,
    key: key,
    size: 22,
    weight: FontWeight.w600,
    color: color,
    textAlign: textAlign,
    height: 1.1,
    serif: true,
  );

  // Heading 3 — 18px SemiBold
  factory AgriText.h3(
    String text, {
    Key? key,
    Color? color,
    TextAlign? textAlign,
  }) => AgriText(
    text,
    key: key,
    size: 18,
    weight: FontWeight.w600,
    color: color,
    textAlign: textAlign,
    height: 1.15,
    serif: true,
  );

  // Title — 16px Medium
  factory AgriText.title(
    String text, {
    Key? key,
    Color? color,
    TextAlign? textAlign,
  }) => AgriText(
    text,
    key: key,
    size: 16,
    weight: FontWeight.w500,
    color: color,
    textAlign: textAlign,
    height: 1.4,
  );

  // Body — 14px Regular
  factory AgriText.body(
    String text, {
    Key? key,
    Color? color,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) => AgriText(
    text,
    key: key,
    size: 14,
    weight: FontWeight.w400,
    color: color,
    textAlign: textAlign,
    height: 1.5,
    maxLines: maxLines,
    overflow: overflow,
  );

  // Body Medium — 14px Medium
  factory AgriText.bodyMedium(
    String text, {
    Key? key,
    Color? color,
    TextAlign? textAlign,
  }) => AgriText(
    text,
    key: key,
    size: 14,
    weight: FontWeight.w500,
    color: color,
    textAlign: textAlign,
    height: 1.5,
  );

  // Bold — 14px Bold─
  factory AgriText.bold(
    String text, {
    Key? key,
    Color? color,
    double size = 14,
    TextAlign? textAlign,
  }) => AgriText(
    text,
    key: key,
    size: size,
    weight: FontWeight.w700,
    color: color,
    textAlign: textAlign,
  );

  // Label — 12px SemiBold Uppercase
  factory AgriText.label(String text, {Key? key, Color? color}) => AgriText(
    text.toUpperCase(),
    key: key,
    size: 11,
    weight: FontWeight.w600,
    color: color ?? AgriColors.textSecondary,
    letterSpacing: 1.2,
    height: 1.2,
  );

  // Caption — 12px Regular
  factory AgriText.caption(
    String text, {
    Key? key,
    Color? color,
    TextAlign? textAlign,
  }) => AgriText(
    text,
    key: key,
    size: 12,
    weight: FontWeight.w400,
    color: color ?? AgriColors.textSecondary,
    textAlign: textAlign,
    height: 1.4,
  );

  // Caption Medium — 12px Medium
  factory AgriText.captionMedium(String text, {Key? key, Color? color}) =>
      AgriText(
        text,
        key: key,
        size: 12,
        weight: FontWeight.w500,
        color: color ?? AgriColors.textSecondary,
        height: 1.4,
      );

  // Sensor Value — 36px Bold
  // Use for the big number on metric cards e.g. "64%"
  factory AgriText.sensorValue(String text, {Key? key, Color? color}) =>
      AgriText(
        text,
        key: key,
        size: 36,
        weight: FontWeight.w700,
        color: color ?? AgriColors.textPrimary,
        height: 1.0,
      );

  // Alert — 13px SemiBold
  factory AgriText.alert(String text, {Key? key, Color? color}) => AgriText(
    text,
    key: key,
    size: 13,
    weight: FontWeight.w600,
    color: color ?? AgriColors.warning,
    height: 1.3,
  );

  factory AgriText.custom(
    String text, {
    Key? key,
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    TextAlign? textAlign,
    double? letterSpacing,
    double? height,
    int? maxLines,
    TextOverflow? overflow,
    TextDecoration? decoration,
    bool serif = false,
  }) => AgriText(
    text,
    key: key,
    size: size,
    weight: weight,
    color: color,
    textAlign: textAlign,
    letterSpacing: letterSpacing,
    height: height,
    maxLines: maxLines,
    overflow: overflow,
    decoration: decoration,
    serif: serif,
  );

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AgriColors.textPrimary,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );

    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: serif
          ? GoogleFonts.newsreader(textStyle: baseStyle)
          : GoogleFonts.manrope(textStyle: baseStyle),
    );
  }
}
