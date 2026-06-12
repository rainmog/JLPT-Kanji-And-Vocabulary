// Shared UI primitives for the redesigned practice-setup screens.
import 'package:flutter/material.dart';
import '../theme.dart';
import '../theme_provider.dart';

// ── Field label wrapper ───────────────────────────────────────────────────────

class KSetupField extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget child;
  const KSetupField({super.key, required this.label, required this.child, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0,
          color: Color(0xFF9A7E86),
        )),
        const SizedBox(height: 10),
        child,
        if (hint != null) ...[
          const SizedBox(height: 9),
          Text(hint!, style: const TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w600,
            color: Color(0xFFC7B4BA),
          )),
        ],
      ]),
    );
  }
}

// ── Segmented control ─────────────────────────────────────────────────────────

class KSegOption {
  final String id, label;
  const KSegOption({required this.id, required this.label});
}

class KSeg extends StatelessWidget {
  final List<KSegOption> options;
  final String value;
  final void Function(String) onChanged;
  final ThemeColors colors;
  const KSeg({super.key, required this.options, required this.value, required this.onChanged, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KDesign.line(colors)),
        boxShadow: KDesign.shadowSm(colors),
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: options.map((o) {
          final on = value == o.id;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 44,
                decoration: BoxDecoration(
                  color: on ? colors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: on ? KDesign.shadowAccent(colors) : null,
                ),
                alignment: Alignment.center,
                child: Text(o.label, style: TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700,
                  color: on ? Colors.white : KDesign.inkSoft(colors),
                )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Choice list (radio-style cards) ──────────────────────────────────────────

class KChoiceItem {
  final String id, label;
  final String? sub;
  final IconData? icon;
  const KChoiceItem({required this.id, required this.label, this.sub, this.icon});
}

class KChoiceList extends StatelessWidget {
  final List<KChoiceItem> options;
  final String value;
  final void Function(String) onChanged;
  final ThemeColors colors;
  const KChoiceList({super.key, required this.options, required this.value, required this.onChanged, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((o) {
        final on = value == o.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: GestureDetector(
            onTap: () => onChanged(o.id),
            child: Container(
              decoration: BoxDecoration(
                color: on ? KDesign.tint(colors) : colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: on ? colors.accent : KDesign.line(colors),
                  width: 1.5,
                ),
                boxShadow: on ? null : KDesign.shadowSm(colors),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 15,
                vertical: o.sub != null ? 13 : 15,
              ),
              child: Row(children: [
                if (o.icon != null) ...[
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: on ? colors.accent : KDesign.line(colors),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(o.icon, size: 18, color: on ? Colors.white : KDesign.inkSoft(colors)),
                  ),
                  const SizedBox(width: 13),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.label, style: TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w700,
                      color: on ? KDesign.deep(colors) : KDesign.ink(colors),
                    )),
                    if (o.sub != null)
                      Text(o.sub!, style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600,
                        color: KDesign.inkSoft(colors),
                      )),
                  ]),
                ),
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: on ? colors.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: on ? null : Border.all(color: KDesign.line(colors), width: 2),
                  ),
                  child: on ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                ),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Count chips ───────────────────────────────────────────────────────────────

class KCountChips extends StatelessWidget {
  final List<int> options;
  final int value;
  final void Function(int) onChanged;
  final ThemeColors colors;
  const KCountChips({super.key, required this.options, required this.value, required this.onChanged, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((n) {
        final on = value == n;
        final last = n == options.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: last ? 0 : 9),
            child: GestureDetector(
              onTap: () => onChanged(n),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 52,
                decoration: BoxDecoration(
                  color: on ? colors.accent : colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: on ? colors.accent : KDesign.line(colors)),
                  boxShadow: on ? KDesign.shadowAccent(colors) : KDesign.shadowSm(colors),
                ),
                alignment: Alignment.center,
                child: Text('$n', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: on ? Colors.white : KDesign.inkSoft(colors),
                )),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Dual-thumb range slider ───────────────────────────────────────────────────

class KDualRange extends StatelessWidget {
  final int lo, hi;
  final void Function(int, int) onChanged;
  final ThemeColors colors;
  const KDualRange({super.key, required this.lo, required this.hi, required this.onChanged, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          overlayShape: SliderComponentShape.noOverlay,
          trackShape: const RectangularSliderTrackShape(),
          trackHeight: 6,
          activeTrackColor: colors.accent,
          inactiveTrackColor: KDesign.soft(colors),
          thumbColor: Colors.white,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
        ),
        child: RangeSlider(
          values: RangeValues(lo.toDouble(), hi.toDouble()),
          min: 1, max: 9, divisions: 8,
          activeColor: colors.accent,
          inactiveColor: KDesign.soft(colors),
          onChanged: (v) => onChanged(v.start.round(), v.end.round()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(9, (i) {
            final n = i + 1;
            final active = n >= lo && n <= hi;
            return Text('$n', style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700,
              color: active ? colors.accent : KDesign.inkFaint(colors),
            ));
          }),
        ),
      ),
    ]);
  }
}

// ── Game button ───────────────────────────────────────────────────────────────

class KGameButton extends StatefulWidget {
  final IconData icon;
  final String label, sub;
  final ThemeColors colors;
  final VoidCallback onTap;
  const KGameButton({super.key, required this.icon, required this.label, required this.sub, required this.colors, required this.onTap});

  @override
  State<KGameButton> createState() => _KGameButtonState();
}

class _KGameButtonState extends State<KGameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KDesign.soft(c), width: 1.5),
          ),
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: KDesign.tint(c),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, size: 18, color: c.accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.label, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: KDesign.ink(c),
                )),
                Text(widget.sub, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: KDesign.inkSoft(c),
                )),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: KDesign.inkFaint(c)),
          ]),
        ),
      ),
    );
  }
}

// ── Sticky footer gradient ────────────────────────────────────────────────────

class KStickyFooter extends StatelessWidget {
  final ThemeColors colors;
  final Widget child;
  const KStickyFooter({super.key, required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.bg.withValues(alpha: 0), colors.bg],
          stops: const [0, 0.3],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: child,
    );
  }
}

// ── Start/primary action button ───────────────────────────────────────────────

class KStartButton extends StatefulWidget {
  final String label;
  final ThemeColors colors;
  final VoidCallback onTap;
  const KStartButton({super.key, required this.label, required this.colors, required this.onTap});

  @override
  State<KStartButton> createState() => _KStartButtonState();
}

class _KStartButtonState extends State<KStartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            color: widget.colors.accent,
            borderRadius: BorderRadius.circular(17),
            boxShadow: KDesign.shadowAccent(widget.colors),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(widget.label, style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: -0.2,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class KBackButton extends StatelessWidget {
  final ThemeColors colors;
  const KBackButton({super.key, required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: KDesign.chipRadius,
          border: Border.all(color: KDesign.line(colors)),
          boxShadow: KDesign.shadowSm(colors),
        ),
        child: Icon(Icons.arrow_back_rounded, size: 22, color: KDesign.ink(colors)),
      ),
    );
  }
}

// ── Setup screen header (back + badge + title) ───────────────────────────────

class KSetupHeader extends StatelessWidget {
  final String badge, title;
  final ThemeColors colors;
  const KSetupHeader({super.key, required this.badge, required this.title, required this.colors});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(children: [
        if (canPop) ...[
          KBackButton(colors: colors),
          const SizedBox(width: 13),
        ],
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: colors.accent,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: Text(badge, style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w600,
            color: Colors.white, fontFamily: 'NotoSerifCJKjp',
          )),
        ),
        const SizedBox(width: 13),
        Text(title, style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800,
          color: KDesign.ink(colors), letterSpacing: -0.4,
        )),
      ]),
    );
  }
}

// ── Back header (title + back arrow) ─────────────────────────────────────────

class KBackHeader extends StatelessWidget {
  final String title;
  final ThemeColors colors;
  final Widget? trailing;
  const KBackHeader({super.key, required this.title, required this.colors, this.trailing});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        if (canPop) ...[
          KBackButton(colors: colors),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(title, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: KDesign.ink(colors), letterSpacing: -0.4,
          )),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// ── Settings toggle switch ────────────────────────────────────────────────────

class KToggle extends StatelessWidget {
  final bool value;
  final ThemeColors colors;
  final ValueChanged<bool> onChanged;
  const KToggle({super.key, required this.value, required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 50, height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? colors.accent : KDesign.soft(colors),
          borderRadius: KDesign.pillRadius,
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 3, offset: const Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

// ── Settings panel/card ───────────────────────────────────────────────────────

class KPanel extends StatelessWidget {
  final ThemeColors colors;
  final List<Widget> children;
  const KPanel({super.key, required this.colors, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KDesign.line(colors)),
        boxShadow: KDesign.shadowSm(colors),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

// ── Settings row ─────────────────────────────────────────────────────────────

class KSettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final Widget? trailing;
  final bool separator;
  final ThemeColors colors;
  final VoidCallback? onTap;
  const KSettingRow({
    super.key,
    required this.icon, required this.label, required this.colors,
    this.sub, this.trailing, this.separator = false, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      decoration: BoxDecoration(
        border: separator ? Border(top: BorderSide(color: KDesign.line(colors).withValues(alpha: 0.6))) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: KDesign.tint(colors),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: colors.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: KDesign.ink(colors))),
            if (sub != null)
              Text(sub!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: KDesign.inkSoft(colors), height: 1.35)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
    return onTap != null ? GestureDetector(onTap: onTap, child: child) : child;
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class KSectionLabel extends StatelessWidget {
  final String text;
  final ThemeColors colors;
  const KSectionLabel({super.key, required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w800,
          letterSpacing: 1.2, color: KDesign.inkFaint(colors),
        ),
      ),
    );
  }
}
