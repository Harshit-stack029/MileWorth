/// Google "encoded polyline algorithm format" implementation.
///
/// Used to compress a recorded trip's GPS route into a compact string for the
/// backend (`Trip.routePolyline`) and to decode it back into points for map
/// rendering. The algorithm is the standard one documented at
/// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
/// so the result is interoperable with Google Maps / any polyline tooling.
library;

/// A single decoded route point. Kept dependency-free (no LatLng) so this
/// utility stays unit-testable without the maps plugin.
class RoutePoint {
  final double lat;
  final double lng;
  const RoutePoint(this.lat, this.lng);
}

/// Encode [points] (in order) into a polyline string. Returns an empty string
/// for fewer than 2 points (nothing meaningful to draw).
String encodePolyline(List<RoutePoint> points) {
  if (points.length < 2) return '';
  final sb = StringBuffer();
  int lastLat = 0;
  int lastLng = 0;
  for (final p in points) {
    final lat = (p.lat * 1e5).round();
    final lng = (p.lng * 1e5).round();
    _encodeValue(sb, lat - lastLat);
    _encodeValue(sb, lng - lastLng);
    lastLat = lat;
    lastLng = lng;
  }
  return sb.toString();
}

/// Decode a polyline string back into points. Returns an empty list for empty
/// or malformed input rather than throwing, so callers can fall back to a
/// placeholder.
List<RoutePoint> decodePolyline(String encoded) {
  final points = <RoutePoint>[];
  if (encoded.isEmpty) return points;
  int index = 0;
  int lat = 0;
  int lng = 0;
  try {
    while (index < encoded.length) {
      lat += _decodeValue(encoded, () => index, (v) => index = v);
      lng += _decodeValue(encoded, () => index, (v) => index = v);
      points.add(RoutePoint(lat / 1e5, lng / 1e5));
    }
  } catch (_) {
    return const []; // truncated / corrupt string — treat as no route
  }
  return points;
}

/// Reduce a long route to at most [maxPoints] by uniform striding, always
/// keeping the first and last fix. Keeps the stored polyline bounded on long
/// drives (the GPS stream emits a fix every ~5m) without distorting the shape.
List<RoutePoint> downsample(List<RoutePoint> points, {int maxPoints = 1000}) {
  if (points.length <= maxPoints) return points;
  final stride = (points.length / maxPoints).ceil();
  final out = <RoutePoint>[];
  for (var i = 0; i < points.length; i += stride) {
    out.add(points[i]);
  }
  if (out.last != points.last) out.add(points.last);
  return out;
}

void _encodeValue(StringBuffer sb, int value) {
  // Left-shift and invert for negatives (two's-complement → zig-zag).
  int v = value < 0 ? ~(value << 1) : (value << 1);
  while (v >= 0x20) {
    sb.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  sb.writeCharCode(v + 63);
}

// The encoding only ever emits ASCII '?'(63) through '~'(126). Anything outside
// that range is not a polyline, so reject it instead of decoding it into junk
// coordinates — without this check a string like "!!!not-a-polyline!!!" decodes
// to plausible-looking points near (0,0) and gets drawn as a real route.
const int _minPolylineCharCode = 63;
const int _maxPolylineCharCode = 126;

int _decodeValue(String s, int Function() getIndex, void Function(int) setIndex) {
  int index = getIndex();
  int result = 0;
  int shift = 0;
  int b;
  do {
    final code = s.codeUnitAt(index++);
    if (code < _minPolylineCharCode || code > _maxPolylineCharCode) {
      throw const FormatException('invalid polyline character');
    }
    b = code - 63;
    result |= (b & 0x1f) << shift;
    shift += 5;
  } while (b >= 0x20);
  setIndex(index);
  // Reverse the zig-zag encoding.
  return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
}
