import 'dart:io';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_min/session_state.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory;
import 'output_format.dart';
import 'trim_video.dart';
import 'watermark.dart';

class VideoWatermark {
  /// Source video to be added with watermark or trimmed.
  final String sourceVideoPath;

  ///Name of the ouput video file without video format.
  ///
  ///Default filename: `videowatermark_(current time in millisecond)`
  final String? videoFileName;

  /// [Watermark] characteristics of watermark image to be added in video.
  final Watermark? watermark;

  /// [OutputFormat] Video format for the output (converted) video
  ///
  /// Available formats
  /// .mp4,
  /// .mkv,
  /// .mov,
  /// .flv,
  /// .avi,
  /// .wmv,
  /// Deafult format: `.mp4`
  final OutputFormat? outputFormat;

  /// Path where the output video to be saved.
  ///
  /// The default path will be Application Documents Directory
  final String? savePath;

  /// [VideoTrim] For specifying the start and end time of the video to be trimmed.
  final VideoTrim? videoTrim;

  /// Callback triggered when the video convertion completed.
  ///
  /// Return value on successful conversion will be `path of converted video` else will be `null`.
  final void Function(String? path)? onSaved;

  /// Callback with video conversion completion percentage.
  ///
  /// Value from `0 - 1.0`
  final void Function(double progress)? onProgressUpdate;

  /// Creates Watermark in video with the image in local storage
  ///
  /// [watermark] defines the characteristics of watermark.
  ///
  /// Required paramater [sourceVideoPath] path of the video to be added watermark.
  const VideoWatermark({
    required this.sourceVideoPath,
    this.videoFileName,
    this.watermark,
    this.outputFormat = OutputFormat.mp4,
    this.savePath,
    this.videoTrim,
    this.onSaved,
    this.onProgressUpdate,
  });

  /// Genrates video in the output path.
  Future<void> generateVideo() async {
    final outputPath = await () async {
      if (savePath != null) return savePath;
      final appDocDir = await getApplicationDocumentsDirectory();
      return appDocDir.path.endsWith('/') ? appDocDir.path : '${appDocDir.path}/';
    }();
    final time = DateTime.now().millisecond;
    final ext = outputFormat.toString().split('.').last;
    final trimmedVideo = '$outputPath${'trimmed_$time'}.$ext';
    final outputVideo = '$outputPath${videoFileName ?? 'videowatermark_$time'}.$ext';

    if (videoTrim != null) {
      double _progress = 0;

      void onDone(bool tempVideoSave) {
        if (tempVideoSave) {
          if (watermark == null) {
            onSaved?.call(trimmedVideo);
            return;
          }

          void onDone(bool outputVideoSave) {
            if (outputVideoSave) {
              File(trimmedVideo).delete();
              onSaved?.call(outputVideo);
            }
          }

          void onProgress(double p) {
            onProgressUpdate?.call(_progress + p / 2);
          }

          _addWatermark(trimmedVideo, outputVideo, onDone, onProgress);
        }
      }

      void onProgress(double p) {
        if (watermark != null) {
          _progress = p / 2;
        } else {
          _progress = p;
        }
        onProgressUpdate?.call(_progress);
      }

      await _trimVideo(trimmedVideo, onDone, onProgress);
    } else {
      void onDone(bool outputVideoSave) {
        if (outputVideoSave) {
          onSaved?.call(outputVideo);
        }
      }

      await _addWatermark(sourceVideoPath, outputVideo, onDone, onProgressUpdate);
    }
  }

  Future<void> _addWatermark(
    String sourceVideo,
    String outputVideo,
    void Function(bool) onDone,
    void Function(double)? onProgressUpdate,
  ) async {
    final watermarkCmd = await watermark!.toCommand();
    final command = '-i $sourceVideo $watermarkCmd $outputVideo';
    await _runFFmpegCommand(command, onDone, onProgressUpdate);
  }

  Future<void> _trimVideo(
    String outputVideo,
    void Function(bool) onDone,
    void Function(double)? onProgressUpdate,
  ) async {
    final command = ' -ss ${videoTrim!.start}'
        ' -i $sourceVideoPath'
        ' -t ${videoTrim!.duration}'
        ' -avoid_negative_ts make_zero $outputVideo';

    await _runFFmpegCommand(command, onDone, onProgressUpdate);
  }

  Future<void> _runFFmpegCommand(
    String command,
    void Function(bool) onDone,
    void Function(double)? progress,
  ) async {
    Duration? videoDuration;
    bool getDuration = false;
    double _progress = 0;

    await FFmpegKit.executeAsync(
      command,
      (session) async {
        ReturnCode? returnCode = await session.getReturnCode();

        SessionState sessionState = await session.getState();

        debugPrint("Video conversion ${sessionState.name}");

        if (ReturnCode.isSuccess(returnCode)) {
          onDone.call(true);
        } else {
          debugPrint("Video save failed");
          onSaved?.call(null);
          onDone.call(false);
        }
      },
      (log) {
        String out = log.getMessage();
        if (videoTrim == null) {
          if (videoDuration == null && getDuration) {
            List<String> duration = out.split(':');
            videoDuration = Duration(
              hours: int.parse(duration[0]),
              minutes: int.parse(duration[1]),
              seconds: int.parse(duration[2].split('.').first),
              milliseconds: int.parse(duration[2].split('.').last),
            );
            getDuration = false;
          }
          if (videoDuration == null && out.contains("Duration:")) {
            getDuration = true;
          }
        } else {
          videoDuration = videoTrim?.duration;
        }
      },
      (statistics) {
        _progress = (statistics.getTime() / videoDuration!.inMilliseconds);
        if (_progress > 1) {
          _progress = 1;
        }
        progress?.call(_progress);
      },
    );
  }
}
