// 渲染对象用「私有字段 + 在 setter 里判重并触发重绘」的写法，这是框架自身
// （如 RenderShaderMask）的惯用结构；构造函数若改用 initializing formal，
// 具名参数就会变成 `_progress:` 这种私有名字，因此在本文件豁免该规则。
// ignore_for_file: prefer_initializing_formals

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 沿 [axis] 平移渐变并在该方向上缩放，用于把「已唱 / 未唱」的分界推到字的某个位置。
class _ProgressGradientTransform extends GradientTransform {
  const _ProgressGradientTransform({
    required this.axis,
    required this.offset,
    required this.scale,
  });

  final Axis axis;
  final double offset;
  final double scale;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      axis == Axis.vertical
      ? (Matrix4.diagonal3Values(1, scale, 1)
          ..setTranslationRaw(0, scale * offset, 0))
      : (Matrix4.diagonal3Values(scale, 1, 1)
          ..setTranslationRaw(scale * offset, 0, 0));

  @override
  bool operator ==(Object other) =>
      other is _ProgressGradientTransform &&
      other.axis == axis &&
      other.offset == offset &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(axis, offset, scale);
}

///逐字渐变遮罩
///
/// 这里自己管理 Shader 生命周期：区域与进度都没变就复用，变了先释放旧的
///
/// 渲染对象销毁时一并释放。
class ProgressShaderMask extends SingleChildRenderObjectWidget {
  const ProgressShaderMask({
    super.key,
    required this.progress,
    required this.axis,
    required this.scale,
    required this.begin,
    required this.end,
    required this.overlayColor,
    required this.underColor,
    required Widget super.child,
  });

  /// 当前字的演唱进度，0-1
  final double progress;

  /// 分界推进的方向
  final Axis axis;

  /// 渐变在推进方向上的缩放，决定过渡带的宽窄
  final double scale;

  /// 渐变起点，应与歌词自身的排版方向一致
  final Alignment begin;

  /// 渐变终点
  final Alignment end;

  /// 已唱部分的颜色
  final Color overlayColor;

  /// 未唱部分的颜色
  final Color underColor;

  @override
  RenderProgressShaderMask createRenderObject(BuildContext context) =>
      RenderProgressShaderMask(
        progress: progress,
        axis: axis,
        scale: scale,
        begin: begin,
        end: end,
        overlayColor: overlayColor,
        underColor: underColor,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderProgressShaderMask renderObject,
  ) {
    renderObject
      ..progress = progress
      ..axis = axis
      ..scale = scale
      ..begin = begin
      ..end = end
      ..overlayColor = overlayColor
      ..underColor = underColor;
  }
}

/// [ProgressShaderMask] 的渲染对象，负责着色器的复用与释放。
class RenderProgressShaderMask extends RenderProxyBox {
  RenderProgressShaderMask({
    required double progress,
    required Axis axis,
    required double scale,
    required Alignment begin,
    required Alignment end,
    required Color overlayColor,
    required Color underColor,
  }) : _progress = progress,
       _axis = axis,
       _scale = scale,
       _begin = begin,
       _end = end,
       _overlayColor = overlayColor,
       _underColor = underColor;

  double _progress;

  double get progress => _progress;

  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    _markShaderDirty();
  }

  Axis _axis;

  Axis get axis => _axis;

  set axis(Axis value) {
    if (_axis == value) return;
    _axis = value;
    _markShaderDirty();
  }

  double _scale;

  double get scale => _scale;

  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    _markShaderDirty();
  }

  Alignment _begin;

  Alignment get begin => _begin;

  set begin(Alignment value) {
    if (_begin == value) return;
    _begin = value;
    _markShaderDirty();
  }

  Alignment _end;

  Alignment get end => _end;

  set end(Alignment value) {
    if (_end == value) return;
    _end = value;
    _markShaderDirty();
  }

  Color _overlayColor;

  Color get overlayColor => _overlayColor;

  set overlayColor(Color value) {
    if (_overlayColor == value) return;
    _overlayColor = value;
    _markShaderDirty();
  }

  Color _underColor;

  Color get underColor => _underColor;

  set underColor(Color value) {
    if (_underColor == value) return;
    _underColor = value;
    _markShaderDirty();
  }

  /// 当前复用中的着色器，以及它对应的区域。
  ui.Shader? _shader;
  Rect? _shaderBounds;
  bool _shaderDirty = true;

  void _markShaderDirty() {
    _shaderDirty = true;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  ui.Shader _buildShader(Rect bounds) {
    // 让分界在 progress 为 0 时完全退到字外，为 1 时推到字尾
    const offsetFactor = -0.666;
    final extent = _axis == Axis.vertical ? bounds.height : bounds.width;
    return LinearGradient(
      begin: _begin,
      end: _end,
      colors: [_overlayColor, _overlayColor, _underColor],
      stops: const [0.0, 0.333, 0.666],
      transform: _ProgressGradientTransform(
        axis: _axis,
        offset: extent * offsetFactor * (1 - _progress),
        scale: _scale,
      ),
    ).createShader(bounds);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }

    final bounds = Offset.zero & size;
    if (_shaderDirty || _shader == null || _shaderBounds != bounds) {
      // 换上新的之前先把上一个还回去，否则原生着色器只能等 GC 才归还。
      // 此刻旧着色器若仍被已提交的图层引用，原生侧的引用计数会替我们留住它。
      _shader?.dispose();
      _shader = _buildShader(bounds);
      _shaderBounds = bounds;
      _shaderDirty = false;
    }

    layer ??= ShaderMaskLayer();
    layer!
      ..shader = _shader
      ..maskRect = offset & size
      ..blendMode = BlendMode.srcIn;
    context.pushLayer(layer!, super.paint, offset);
  }

  @override
  void dispose() {
    _shader?.dispose();
    _shader = null;
    _shaderBounds = null;
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('progress', progress))
      ..add(EnumProperty<Axis>('axis', axis))
      ..add(DoubleProperty('scale', scale))
      ..add(ColorProperty('overlayColor', overlayColor))
      ..add(ColorProperty('underColor', underColor));
  }
}
