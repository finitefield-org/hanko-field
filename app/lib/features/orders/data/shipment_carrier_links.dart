// ignore_for_file: public_member_api_docs

import 'package:app/features/orders/data/models/order_models.dart';

class ShipmentCarrierLinks {
  const ShipmentCarrierLinks();

  Uri? trackingUri({
    required ShipmentCarrier carrier,
    required String tracking,
  }) {
    final encoded = Uri.encodeComponent(tracking);
    return switch (carrier) {
      ShipmentCarrier.jppost => Uri.parse(
        'https://trackings.post.japanpost.jp/services/srv/search/?requestNo1=$encoded',
      ),
      ShipmentCarrier.yamato => Uri.parse(
        'https://toi.kuronekoyamato.co.jp/cgi-bin/tneko?number00=$encoded',
      ),
      ShipmentCarrier.sagawa => Uri.parse(
        'https://k2k.sagawa-exp.co.jp/p/sagawa/web/okurijosearch.do?okurijoNo=$encoded',
      ),
      ShipmentCarrier.dhl => Uri.parse(
        'https://www.dhl.com/global-en/home/tracking.html?tracking-id=$encoded',
      ),
      ShipmentCarrier.ups => Uri.parse(
        'https://www.ups.com/track?tracknum=$encoded',
      ),
      ShipmentCarrier.fedex => Uri.parse(
        'https://www.fedex.com/fedextrack/?tracknumbers=$encoded',
      ),
      ShipmentCarrier.other => null,
    };
  }

  Uri? supportUri(ShipmentCarrier carrier) {
    return switch (carrier) {
      ShipmentCarrier.jppost => Uri.parse(
        'https://www.post.japanpost.jp/index_en.html',
      ),
      ShipmentCarrier.yamato => Uri.parse(
        'https://www.kuronekoyamato.co.jp/ytc/en/',
      ),
      ShipmentCarrier.sagawa => Uri.parse(
        'https://www.sagawa-exp.co.jp/english/',
      ),
      ShipmentCarrier.dhl => Uri.parse(
        'https://www.dhl.com/global-en/home/customer-service.html',
      ),
      ShipmentCarrier.ups => Uri.parse(
        'https://www.ups.com/us/en/help-support-center.page',
      ),
      ShipmentCarrier.fedex => Uri.parse(
        'https://www.fedex.com/en-us/customer-support.html',
      ),
      ShipmentCarrier.other => null,
    };
  }

  Uri mapsSearchUri(String query) {
    final encoded = Uri.encodeComponent(query);
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );
  }
}
