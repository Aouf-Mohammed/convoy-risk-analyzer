import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'dart:ui' as ui;
import 'dart:async';


class HiveTileProvider extends TileProvider {
  final Box cacheBox = Hive.box('mapTiles');
  final Dio _dio = Dio();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return _HiveImageProvider(url, cacheBox, _dio);
  }
}

class _HiveImageProvider extends ImageProvider<_HiveImageProvider> {
  final String url;
  final Box cacheBox;
  final Dio dio;

  _HiveImageProvider(this.url, this.cacheBox, this.dio);

  @override
  Future<_HiveImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_HiveImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(_HiveImageProvider key, ImageDecoderCallback decode) {
    final chunkEvents = StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode, chunkEvents),
      chunkEvents: chunkEvents.stream,
      scale: 1.0,
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this)
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    _HiveImageProvider key, 
    ImageDecoderCallback decode, 
    StreamController<ImageChunkEvent> chunkEvents
  ) async {
    try {
      final Uint8List? cachedData = cacheBox.get(url) as Uint8List?;
      if (cachedData != null) {
        final buffer = await ui.ImmutableBuffer.fromUint8List(cachedData);
        return decode(buffer);
      }

      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (count, total) {
          if (total != -1) {
            chunkEvents.add(ImageChunkEvent(
              cumulativeBytesLoaded: count,
              expectedTotalBytes: total,
            ));
          }
        },
      );
      
      final bytes = Uint8List.fromList(response.data!);
      
      // Store to Hive cache asynchronously without blocking image loading
      cacheBox.put(url, bytes);
      
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (e) {
      // Return a transparent 1x1 image on error
      final Uint8List transparentPixel = Uint8List.fromList([
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
        0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0,
        0, 0, 11, 73, 68, 65, 84, 8, 215, 99, 96, 0, 2, 0, 0, 5, 0,
        1, 226, 38, 5, 155, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
      ]);
      final buffer = await ui.ImmutableBuffer.fromUint8List(transparentPixel);
      return decode(buffer);
    } finally {
      chunkEvents.close();
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _HiveImageProvider && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}
