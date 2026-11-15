import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// Render assistant formatting; user messages must remain literal text.
class AIMessageBody extends StatelessWidget {
  final String text;
  final Color? color;
  const AIMessageBody({super.key, required this.text, this.color});

  static String normalize(String text) {
    var value = text.replaceAll('\r\n', '\n').trim();
    // Remove only an accidental presentation wrapper, never code fences.
    final wrapper = RegExp(r'^```(?:markdown|md)\s*\n([\s\S]*?)\n```$');
    final match = wrapper.firstMatch(value);
    if (match != null) value = match.group(1)!;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.onSurface;
    final base = TextStyle(fontSize: 14, height: 1.5, color: color);
    return LayoutBuilder(
      builder: (context, constraints) {
        return MarkdownBody(
          data: normalize(text),
          selectable: true,
          softLineBreak: true,
          shrinkWrap: true,
          extensionSet: md.ExtensionSet.gitHubFlavored,
          inlineSyntaxes: [_MathInlineSyntax()],
          blockSyntaxes: const [_MathBlockSyntax()],
          builders: {
            'mochi_math': _MathBuilder(constraints.maxWidth, color, false),
            'mochi_math_block': _MathBuilder(constraints.maxWidth, color, true),
          },
          // AI-generated image URLs must not trigger invisible network loads.
          imageBuilder: (uri, title, alt) =>
              Text(alt ?? title ?? 'Hình minh họa', style: base),
          styleSheet: MarkdownStyleSheet(
            p: base,
            h1: base.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            h2: base.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
            h3: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            strong: base.copyWith(fontWeight: FontWeight.w700),
            em: base.copyWith(fontStyle: FontStyle.italic),
            listBullet: base,
            code: base.copyWith(fontFamily: 'monospace', fontSize: 13),
            codeblockDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            codeblockPadding: const EdgeInsets.all(10),
            blockSpacing: 10,
            listIndent: 20,
            tableBody: base,
            tableHead: base.copyWith(fontWeight: FontWeight.bold),
            tableCellsPadding: const EdgeInsets.all(6),
          ),
        );
      },
    );
  }
}

class _MathInlineSyntax extends md.InlineSyntax {
  _MathInlineSyntax() : super(r'\$([^\$\n]+)\$|\\\((.+?)\\\)');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element.text('mochi_math', match.group(1) ?? match.group(2)!),
    );
    return true;
  }
}

class _MathBlockSyntax extends md.BlockSyntax {
  const _MathBlockSyntax();
  @override
  RegExp get pattern => RegExp(r'^\s*(\$\$|\\\[)(.*)$');
  @override
  md.Node parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content)!;
    final close = match.group(1) == r'$$' ? r'$$' : r'\]';
    final lines = <String>[];
    var line = match.group(2)!;
    parser.advance();
    while (true) {
      final end = line.indexOf(close);
      if (end >= 0) {
        lines.add(line.substring(0, end));
        break;
      }
      lines.add(line);
      if (parser.isDone) break;
      line = parser.current.content;
      parser.advance();
    }
    return md.Element.text('mochi_math_block', lines.join('\n').trim());
  }
}

class _MathBuilder extends MarkdownElementBuilder {
  final double width;
  final Color color;
  final bool block;
  _MathBuilder(this.width, this.color, this.block);
  @override
  bool isBlockElement() => block;
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return Semantics(
      label: 'Công thức: ${element.textContent}',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: block ? 8 : 0),
            child: Math.tex(
              element.textContent,
              mathStyle: block ? MathStyle.display : MathStyle.text,
              textStyle: TextStyle(
                color: color,
                fontSize: 15 * MediaQuery.textScalerOf(context).scale(1),
              ),
              onErrorFallback: (_) => Text(
                element.textContent,
                style: TextStyle(color: color, fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
