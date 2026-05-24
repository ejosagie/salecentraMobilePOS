import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? backgroundColor;

  const AppLogo({
    super.key,
    this.size = 100,
    this.showText = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(size * 0.24),
            boxShadow: [
              BoxShadow(
                color: (backgroundColor ?? const Color(0xFF2563EB)).withOpacity(0.3),
                blurRadius: size * 0.2,
                offset: Offset(0, size * 0.08),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.24),
            child: Image.asset(
              'assets/images/salecentra_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to icon if image fails to load
                return Icon(
                  Icons.point_of_sale_outlined,
                  size: size * 0.5,
                  color: Colors.white,
                );
              },
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.24),
          Text(
            'SaleCentra',
            style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: size * 0.08),
          Text(
            'Smart Sales Made Simple',
            style: TextStyle(
              fontSize: size * 0.14,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }
}

class AppIcon extends StatelessWidget {
  final double size;

  const AppIcon({
    super.key,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.asset(
        'assets/images/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(size * 0.2),
            ),
            child: Icon(
              Icons.point_of_sale_outlined,
              size: size * 0.5,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}
