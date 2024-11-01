class WatermarkSize {
  /// Width of the watermark image.
  final double width;

  /// Height of the watermark image.
  final double height;

  /// Specifies the dimensions of the image to ba added in the video as watermark
  const WatermarkSize(this.width, this.height);

  /// The height and width of the image are same as in [width].
  const WatermarkSize.symmertric(double width) : this(width, -1);

  String toCommand() {
    return 'scale=$width:$height, ';
  }
}
