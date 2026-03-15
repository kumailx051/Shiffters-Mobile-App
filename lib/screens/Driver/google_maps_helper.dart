import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shiffters/theme/app_colors.dart';

// Helper class for Google Maps functionality
class GoogleMapsHelper {
  // Build Google Maps markers for orders
  static Set<Marker> buildOrderMarkers(
      List<dynamic> orders, Function(dynamic) onOrderTap) {
    Set<Marker> markers = <Marker>{};

    for (int i = 0; i < orders.length; i++) {
      final order = orders[i];
      final orderLat = order.pickupLocation.latitude;
      final orderLng = order.pickupLocation.longitude;

      markers.add(
        Marker(
          markerId: MarkerId('order_${order.id}'),
          position: LatLng(orderLat, orderLng),
          infoWindow: InfoWindow(
            title: order.customerName,
            snippet:
                'Rs ${order.estimatedEarnings.toInt()} - ${order.packageType}',
            onTap: () {
              HapticFeedback.mediumImpact();
              onOrderTap(order);
            },
          ),
          icon: order.serviceType == 'shifting'
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          onTap: () {
            HapticFeedback.lightImpact();
            onOrderTap(order);
          },
        ),
      );
    }

    return markers;
  }

  // Build search radius circles
  static Set<Circle> buildSearchRadiusCircles(
      LatLng currentLocation, double searchRadius, bool isSearching) {
    Set<Circle> circles = <Circle>{};

    if (isSearching) {
      circles.add(
        Circle(
          circleId: const CircleId('search_radius'),
          center: currentLocation,
          radius: searchRadius * 1000, // Convert km to meters
          fillColor: AppColors.yellowAccent.withOpacity(0.1),
          strokeColor: AppColors.yellowAccent.withOpacity(0.4),
          strokeWidth: 2,
        ),
      );
    }

    return circles;
  }

  // Dark map style for Google Maps
  static const String darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#212121"
        }
      ]
    },
    {
      "elementType": "labels.icon",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#212121"
        }
      ]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.fill",
      "stylers": [
        {
          "color": "#2c2c2c"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#000000"
        }
      ]
    }
  ]
  ''';
}
