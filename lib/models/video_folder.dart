import '../models/media_file.dart';

enum FolderSortType {
  name,
  size,
  count,
}

class VideoFolder {
  final String name;
  final String path;
  final List<MediaFile> videos;
  final int totalSizeBytes;
  final MediaFile coverVideo;

  VideoFolder({
    required this.name,
    required this.path,
    required this.videos,
    required this.totalSizeBytes,
    required this.coverVideo,
  });

  int get videoCount => videos.length;

  static List<VideoFolder> groupVideos(
    List<MediaFile> allVideos, {
    FolderSortType sortType = FolderSortType.count,
  }) {
    final map = <String, List<MediaFile>>{};

    for (final v in allVideos) {
      if (v.kind != MediaKind.video) continue;
      final folder = v.folderName;
      if (folder.isEmpty) continue;
      map.putIfAbsent(folder, () => []).add(v);
    }

    final folders = <VideoFolder>[];

    map.forEach((name, list) {
      if (list.isEmpty) return; // filter empty folders automatically

      // Sort videos inside folder by modifiedDate descending (newest first)
      list.sort((a, b) {
        final aDate = a.modifiedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.modifiedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      int totalSize = 0;
      for (final v in list) {
        totalSize += (v.fileSize ?? 0);
      }

      folders.add(VideoFolder(
        name: name,
        path: list.first.path,
        videos: list,
        totalSizeBytes: totalSize,
        coverVideo: list.first,
      ));
    });

    // Apply sorting
    switch (sortType) {
      case FolderSortType.name:
        folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case FolderSortType.size:
        folders.sort((a, b) => b.totalSizeBytes.compareTo(a.totalSizeBytes));
        break;
      case FolderSortType.count:
        folders.sort((a, b) => b.videoCount.compareTo(a.videoCount));
        break;
    }

    return folders;
  }
}
