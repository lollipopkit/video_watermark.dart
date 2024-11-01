import 'watermark_source.dart';
import 'watermark_size.dart';
import 'watermark_alignment.dart';

class Watermark {
  /// Source of image to be added in the video as watermark.
  ///
  /// Supported sources: `File`, `Assets` and `Network`.
  final WatermarkSource image;

  /// [WatermarkSize] Height and width of the watermark image,
  ///
  /// Refers: [defaultWatermarkSize].
  final WatermarkSize watermarkSize;

  /// [WatermarkAlignment] Position of the watermark image in the video
  ///
  /// Refers: [defaultWatermarkAlignment].
  final WatermarkAlignment watermarkAlignment;

  /// Opacity of the watermark image varies between 0.0 - 1.0.
  ///
  /// Refers: [defaultOpacity].
  final double opacity;

  /// Bitrate of the video.
  /// eg.: `5M`
  ///
  /// Refers: [defaultBitRate].
  final String bitRate;

  /// Defines the characteristics of watermark image.
  ///
  /// Required parameter [image].
  Watermark({
    required this.image,
    this.watermarkSize = defaultWatermarkSize,
    this.opacity = defaultOpacity,
    this.watermarkAlignment = defaultWatermarkAlignment,
    this.bitRate = defaultBitRate,
  });

  static const defaultBitRate = '5M';
  static const defaultOpacity = 1.0;
  static const defaultWatermarkSize = WatermarkSize.symmertric(100);
  static const defaultWatermarkAlignment = WatermarkAlignment.center;

  Future<String> toCommand() async {
    final cmd = StringBuffer();

    // Add the image command
    final imgCmd = await image.toCommand();
    cmd.write('-i $imgCmd');

    // Add the filter complex
    final watermarkSizeCmd = watermarkSize.toCommand();
    final watermarkAlignmentCmd = watermarkAlignment.toCommand();
    cmd.write(
      ' -filter_complex "[1:v]${watermarkSizeCmd}format=argb,geq=r=\'r(X,Y)\':a=\'$opacity*alpha(X,Y)\'[i];[0:v][i]overlay=${watermarkAlignmentCmd}[o]"',
    );

    // Add the map
    cmd.write(' -map "[o]" -map "0:a?"');

    // Add the bitrate
    cmd.write(' -b:v $bitRate');

    return cmd.toString();
  }
}
