import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
    required this.progressListenable,
    required this.axis,
    required this.scale,
    required this.begin,
    required this.end,
    required this.overlayColor,
    required this.underColor,
    required Widget super.child,
  });

  /// 当前字的演唱进度，0-1
  final ValueListenable<double> progressListenable;

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
        progressListenable: progressListenable,
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
      ..progressListenable = progressListenable
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
    required this._progressListenable,
    required this._axis,
    required this._scale,
    required this._begin,
    required this._end,
    required this._overlayColor,
    required this._underColor,
  });

  ValueListenable<double> _progressListenable;
  double? _paintedProgress;

  set progressListenable(ValueListenable<double> value) {
    if (identical(value, _progressListenable)) return;
    if (attached) _progressListenable.removeListener(_onProgress);
    _progressListenable = value;
    if (attached) _progressListenable.addListener(_onProgress);
    _markShaderDirty();
  }

  void _onProgress() {
    if (_paintedProgress != _progressListenable.value) _markShaderDirty();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progressListenable.addListener(_onProgress);
    _shaderDirty = true;
  }

  @override
  void detach() {
    _progressListenable.removeListener(_onProgress);
    super.detach();
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

  ui.Shader _buildShader(Rect bounds, double progress) {
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
        offset: extent * offsetFactor * (1 - progress),
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
      _shader?.dispose();
      final progress = _progressListenable.value;
      _shader = _buildShader(bounds, progress);
      _shaderBounds = bounds;
      _shaderDirty = false;
      _paintedProgress = progress;
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
}
