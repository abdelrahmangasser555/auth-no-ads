import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/brands.dart';

class BrandIcon extends StatelessWidget {
  const BrandIcon({
    super.key,
    required this.name,
    this.extra = '',
    this.size = 36,
  });

  final String name;
  final String extra;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = brandFor(name, extra);
    final radius = size / 2;
    if (brand.hasIcon) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x14000000)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(size * 0.18),
          child: SvgPicture.asset(
            brand.asset!,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            placeholderBuilder: (_) => _Letter(brand: brand, radius: radius - 2),
          ),
        ),
      );
    }
    return _Letter(brand: brand, radius: radius);
  }
}

class _Letter extends StatelessWidget {
  const _Letter({required this.brand, required this.radius});

  final BrandStyle brand;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: brand.color,
      child: Text(
        brand.letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }
}
