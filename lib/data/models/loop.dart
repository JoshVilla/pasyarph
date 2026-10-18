import 'package:latlong2/latlong.dart';

import '../geo/geo_codec.dart';
import 'enums.dart';
import 'json.dart';

/// `loops.main_stop` jsonb: {name, type, lat, lng, km_into_route}.
class MainStop {
  const MainStop({
    required this.location,
    this.name,
    this.type,
    this.kmIntoRoute,
  });

  /// Null for unnamed places and for the turnaround fallback.
  final String? name;

  /// viewpoint, waterfall, attraction, food, or turnaround (no place found:
  /// the farthest point of the loop).
  final String? type;
  final LatLng location;

  /// Distance along the loop from the start.
  final double? kmIntoRoute;

  factory MainStop.fromJson(Json json) => MainStop(
    name: json['name'] as String?,
    type: json['type'] as String?,
    location: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    ),
    kmIntoRoute: toDoubleOrNull(json['km_into_route']),
  );

  Json toJson() => {
    'name': name,
    'type': type,
    'lat': location.latitude,
    'lng': location.longitude,
    if (kmIntoRoute != null) 'km_into_route': kmIntoRoute,
  };
}

/// A fuel station along a generated loop.
class FuelStop {
  const FuelStop({required this.location, this.name, this.kmIntoRoute = 0});

  final String? name;
  final LatLng location;
  final double kmIntoRoute;

  factory FuelStop.fromJson(Json json) => FuelStop(
    name: json['name'] as String?,
    location: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    ),
    kmIntoRoute: toDoubleOrNull(json['km_into_route']) ?? 0,
  );
}

/// Row of `loops` as other riders (and the owner) can read it.
///
/// The full `route` column is never readable through the API (home privacy);
/// owners fetch it with the `loop_route` RPC. `select *` on loops is denied,
/// so always select [Loop.columns].
class Loop {
  const Loop({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.source,
    required this.distanceM,
    required this.durationS,
    required this.visibility,
    required this.createdAt,
    this.sharedRoute,
    this.curvinessScore,
    this.mainStop,
    this.clubId,
    this.province,
  });

  static const columns =
      'id,owner_id,name,source,shared_route,distance_m,duration_s,'
      'curviness_score,main_stop,province,visibility,club_id,created_at';

  final String id;
  final String ownerId;
  final String name;
  final LoopSource source;

  /// Route with the first and last 800 m trimmed. Null until trimmed.
  final List<LatLng>? sharedRoute;
  final int distanceM;
  final int durationS;
  final double? curvinessScore;
  final MainStop? mainStop;

  /// Province the loop is in (where its main stop is), e.g. "Ifugao".
  /// Null until provinces are loaded, or offshore.
  final String? province;
  final LoopVisibility visibility;
  final String? clubId;
  final DateTime createdAt;

  factory Loop.fromJson(Json json) => Loop(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    name: json['name'] as String,
    source: LoopSource.fromValue(json['source'] as String),
    sharedRoute: GeoCodec.parseLineStringOrNull(json['shared_route']),
    distanceM: (json['distance_m'] as num).toInt(),
    durationS: (json['duration_s'] as num).toInt(),
    curvinessScore: toDoubleOrNull(json['curviness_score']),
    mainStop: switch (json['main_stop']) {
      final Json m => MainStop.fromJson(m),
      _ => null,
    },
    visibility: LoopVisibility.fromValue(json['visibility'] as String),
    clubId: json['club_id'] as String?,
    province: json['province'] as String?,
    createdAt: parseTimestamp(json['created_at']),
  );
}

/// A loop from the `loops_near` RPC, with its distance from the rider.
class NearbyLoop {
  const NearbyLoop({required this.loop, required this.distanceAwayM});

  final Loop loop;
  final double distanceAwayM;

  factory NearbyLoop.fromJson(Json json) => NearbyLoop(
    loop: Loop.fromJson(json),
    distanceAwayM: (json['distance_away_m'] as num).toDouble(),
  );
}

/// Insert payload for a new loop. `owner_id` defaults to the signed-in user.
class NewLoop {
  const NewLoop({
    required this.name,
    required this.source,
    required this.route,
    required this.distanceM,
    required this.durationS,
    this.curvinessScore,
    this.mainStop,
    this.visibility = LoopVisibility.public,
    this.clubId,
  }) : assert(
         (visibility == LoopVisibility.club) == (clubId != null),
         'club visibility needs a clubId, and only then',
       );

  final String name;
  final LoopSource source;
  final List<LatLng> route;
  final int distanceM;
  final int durationS;
  final double? curvinessScore;
  final MainStop? mainStop;
  final LoopVisibility visibility;
  final String? clubId;

  Json toJson() => {
    'name': name,
    'source': source.value,
    'route': GeoCodec.lineStringToEwkt(route),
    'distance_m': distanceM,
    'duration_s': durationS,
    'curviness_score': curvinessScore,
    'main_stop': mainStop?.toJson(),
    'visibility': visibility.value,
    'club_id': clubId,
  };
}
