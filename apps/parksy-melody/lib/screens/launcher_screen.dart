import 'package:flutter/material.dart';
import 'melody_screen.dart';

const _kBg      = Color(0xFF0A0A0A);
const _kSurface = Color(0xFF141414);
const _kCard    = Color(0xFF1C1C1C);
const _kRed     = Color(0xFFE53935);
const _kRedDim  = Color(0xFF4A1010);
const _kText    = Color(0xFFF5F5F5);
const _kMuted   = Color(0xFF666666);
const _kBorder  = Color(0xFF2A2A2A);

class LauncherScreen extends StatelessWidget {
  const LauncherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  _buildSectionLabel('TOOLS'),
                  const SizedBox(height: 12),
                  _buildToolCard(
                    context,
                    icon: '🥷',
                    title: 'YOUTUBE 채집',
                    sub: 'URL → MP3 trim → Telegram',
                    badge: 'ACTIVE',
                    badgeColor: _kRed,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MelodyScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildToolCard(
                    context,
                    icon: '🎛️',
                    title: 'MIXER',
                    sub: 'Multi-track blend — v2.1',
                    badge: 'SOON',
                    badgeColor: _kMuted,
                    onTap: null,
                  ),
                  const SizedBox(height: 10),
                  _buildToolCard(
                    context,
                    icon: '📊',
                    title: 'ANALYZER',
                    sub: 'Waveform + BPM detect — v2.2',
                    badge: 'SOON',
                    badgeColor: _kMuted,
                    onTap: null,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionLabel('STATUS'),
                  const SizedBox(height: 12),
                  _buildStatusCard(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _kRedDim,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kRed.withOpacity(0.7), width: 1.5),
            ),
            child: const Center(
              child: Text('🎵', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PARKSY MELODY',
                style: TextStyle(
                  color: _kText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              Text(
                'Audio Collection Studio  v2.0',
                style: TextStyle(
                  color: _kRed.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: _kRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: _kMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String sub,
    required String badge,
    required Color badgeColor,
    required VoidCallback? onTap,
  }) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? _kRed.withOpacity(0.35) : _kBorder,
            width: active ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: active ? _kRedDim : const Color(0xFF181818),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? _kRed.withOpacity(0.5) : _kBorder,
                ),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: active ? _kText : _kMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: badgeColor.withOpacity(0.4)),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            if (active) ...[
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, color: _kMuted, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatusRow('Pipeline', '@parksy_bridges_bot', Colors.greenAccent),
          const SizedBox(height: 10),
          _buildStatusRow('Engine', 'NewPipeExtractor + FFmpeg', _kText),
          const SizedBox(height: 10),
          _buildStatusRow('Output', 'MP3 192k + fade trim', _kText),
          const SizedBox(height: 10),
          _buildStatusRow('Destination', 'Telegram → runner.py', _kText),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: _kMuted, fontSize: 11)),
        Text(value,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'PARKSY MELODY  v2.0  |  dtslib1979',
            style: TextStyle(color: _kMuted.withOpacity(0.5), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
