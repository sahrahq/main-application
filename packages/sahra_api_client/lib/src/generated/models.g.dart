// GENERATED — DO NOT EDIT BY HAND.
//
// Source: apps/api/openapi.json, exported from the running NestJS app.
// Regenerate: dart run tool/generate_client.dart
//
// Request and response models.
//
// Editing this file is how the client and the backend start to disagree
// without anyone noticing. client_drift_test.dart fails if you do.

class AdminRestaurantResponse {
  const AdminRestaurantResponse({
    required this.city,
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.neighborhood,
    required this.slug,
    required this.status,
  });

  factory AdminRestaurantResponse.fromJson(Map<String, dynamic> json) => AdminRestaurantResponse(
        city: json['city'] as String,
        id: json['id'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: json['nameEn'] as String,
        neighborhood: json['neighborhood'] == null ? null : json['neighborhood'] as String,
        slug: json['slug'] as String,
        status: json['status'] as String,
      );

  final String city;
  final String id;
  final String nameAr;
  final String nameEn;
  final String? neighborhood;
  final String slug;
  final String status;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'city': city,
        'id': id,
        'nameAr': nameAr,
        'nameEn': nameEn,
        if (neighborhood != null) 'neighborhood': neighborhood!,
        'slug': slug,
        'status': status,
      };
}

class ApiErrorBody {
  const ApiErrorBody({
    required this.code,
    this.details,
    required this.message,
    required this.messageAr,
    required this.requestId,
    this.retryAfter,
  });

  factory ApiErrorBody.fromJson(Map<String, dynamic> json) => ApiErrorBody(
        code: json['code'] as String,
        details: json['details'] == null ? null : (json['details'] as List<dynamic>).map((e) => ErrorDetailResponse.fromJson(e as Map<String, dynamic>)).toList(),
        message: json['message'] as String,
        messageAr: json['message_ar'] as String,
        requestId: json['request_id'] as String,
        retryAfter: json['retry_after'] == null ? null : (json['retry_after'] as num).toDouble(),
      );

  /// The only field a client should branch on.
  final String code;
  final List<ErrorDetailResponse>? details;
  final String message;
  final String messageAr;
  final String requestId;
  final double? retryAfter;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        if (details != null) 'details': details!.map((e) => e.toJson()).toList(),
        'message': message,
        'message_ar': messageAr,
        'request_id': requestId,
        if (retryAfter != null) 'retry_after': retryAfter!,
      };
}

class ApiErrorResponse {
  const ApiErrorResponse({
    required this.error,
  });

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) => ApiErrorResponse(
        error: ApiErrorBody.fromJson(json['error'] as Map<String, dynamic>),
      );

  final ApiErrorBody error;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'error': error.toJson(),
      };
}

class AvailabilityResponse {
  const AvailabilityResponse({
    required this.date,
    required this.partySize,
    required this.slots,
    required this.timezone,
  });

  factory AvailabilityResponse.fromJson(Map<String, dynamic> json) => AvailabilityResponse(
        date: json['date'] as String,
        partySize: (json['partySize'] as num).toInt(),
        slots: (json['slots'] as List<dynamic>).map((e) => SlotResponse.fromJson(e as Map<String, dynamic>)).toList(),
        timezone: json['timezone'] as String,
      );

  final String date;
  final int partySize;
  final List<SlotResponse> slots;
  /// IANA zone the `time` fields are expressed in.
  final String timezone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'partySize': partySize,
        'slots': slots.map((e) => e.toJson()).toList(),
        'timezone': timezone,
      };
}

class BookResponse {
  const BookResponse({
    required this.date,
    required this.reservations,
    required this.timezone,
  });

  factory BookResponse.fromJson(Map<String, dynamic> json) => BookResponse(
        date: json['date'] as String,
        reservations: (json['reservations'] as List<dynamic>).map((e) => BookRowResponse.fromJson(e as Map<String, dynamic>)).toList(),
        timezone: json['timezone'] as String,
      );

  final String date;
  final List<BookRowResponse> reservations;
  final String timezone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'reservations': reservations.map((e) => e.toJson()).toList(),
        'timezone': timezone,
      };
}

class BookRowResponse {
  const BookRowResponse({
    required this.code,
    this.guestName,
    this.guestPhone,
    required this.id,
    this.occasion,
    required this.partySize,
    required this.source,
    this.specialRequests,
    required this.startsAt,
    required this.status,
    required this.tables,
    required this.time,
  });

  factory BookRowResponse.fromJson(Map<String, dynamic> json) => BookRowResponse(
        code: json['code'] as String,
        guestName: json['guestName'] == null ? null : json['guestName'] as String,
        guestPhone: json['guestPhone'] == null ? null : json['guestPhone'] as String,
        id: json['id'] as String,
        occasion: json['occasion'] == null ? null : json['occasion'] as String,
        partySize: (json['partySize'] as num).toInt(),
        source: json['source'] as String,
        specialRequests: json['specialRequests'] == null ? null : json['specialRequests'] as String,
        startsAt: json['startsAt'] as String,
        status: json['status'] as String,
        tables: (json['tables'] as List<dynamic>).map((e) => e as String).toList(),
        time: json['time'] as String,
      );

  final String code;
  final String? guestName;
  final String? guestPhone;
  final String id;
  final String? occasion;
  final int partySize;
  /// app | walk_in | phone — which door it came through.
  final String source;
  final String? specialRequests;
  final String startsAt;
  final String status;
  final List<String> tables;
  /// HH:MM in the restaurant's local time.
  final String time;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        if (guestName != null) 'guestName': guestName!,
        if (guestPhone != null) 'guestPhone': guestPhone!,
        'id': id,
        if (occasion != null) 'occasion': occasion!,
        'partySize': partySize,
        'source': source,
        if (specialRequests != null) 'specialRequests': specialRequests!,
        'startsAt': startsAt,
        'status': status,
        'tables': tables.map((e) => e).toList(),
        'time': time,
      };
}

class CancelReservationDto {
  const CancelReservationDto({
    required this.reason,
  });

  factory CancelReservationDto.fromJson(Map<String, dynamic> json) => CancelReservationDto(
        reason: json['reason'] as String,
      );

  /// REQUIRED. Shown to the diner verbatim.
  final String reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'reason': reason,
      };
}

class CancelledReservationResponse {
  const CancelledReservationResponse({
    required this.cancelReason,
    required this.cancelledAt,
    required this.code,
    required this.id,
    required this.partySize,
    required this.startsAt,
    required this.status,
    required this.tableReleased,
  });

  factory CancelledReservationResponse.fromJson(Map<String, dynamic> json) => CancelledReservationResponse(
        cancelReason: json['cancel_reason'] as String,
        cancelledAt: json['cancelled_at'] as String,
        code: json['code'] as String,
        id: json['id'] as String,
        partySize: (json['party_size'] as num).toInt(),
        startsAt: json['starts_at'] as String,
        status: json['status'] as String,
        tableReleased: json['table_released'] as bool,
      );

  /// Shown to the diner verbatim.
  final String cancelReason;
  final String cancelledAt;
  final String code;
  final String id;
  final int partySize;
  final String startsAt;
  /// Always `cancelled_by_restaurant`.
  final String status;
  /// True when the table this booking held is now available again. Released by trg_resv_propagate, which flips reservation_tables.active off for any status outside held|pending|confirmed|seated.
  final bool tableReleased;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cancel_reason': cancelReason,
        'cancelled_at': cancelledAt,
        'code': code,
        'id': id,
        'party_size': partySize,
        'starts_at': startsAt,
        'status': status,
        'table_released': tableReleased,
      };
}

class ConfirmHoldDto {
  const ConfirmHoldDto({
    this.occasion,
    this.specialRequests,
  });

  factory ConfirmHoldDto.fromJson(Map<String, dynamic> json) => ConfirmHoldDto(
        occasion: json['occasion'] == null ? null : json['occasion'] as String,
        specialRequests: json['specialRequests'] == null ? null : json['specialRequests'] as String,
      );

  final String? occasion;
  final String? specialRequests;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (occasion != null) 'occasion': occasion!,
        if (specialRequests != null) 'specialRequests': specialRequests!,
      };
}

class CreateHoldDto {
  const CreateHoldDto({
    this.guestName,
    this.guestPhone,
    this.occasion,
    required this.partySize,
    required this.restaurantId,
    this.seatingPref,
    this.specialRequests,
    required this.startsAt,
  });

  factory CreateHoldDto.fromJson(Map<String, dynamic> json) => CreateHoldDto(
        guestName: json['guestName'] == null ? null : json['guestName'] as String,
        guestPhone: json['guestPhone'] == null ? null : json['guestPhone'] as String,
        occasion: json['occasion'] == null ? null : json['occasion'] as String,
        partySize: (json['partySize'] as num).toInt(),
        restaurantId: json['restaurantId'] as String,
        seatingPref: json['seatingPref'] == null ? null : json['seatingPref'] as String,
        specialRequests: json['specialRequests'] == null ? null : json['specialRequests'] as String,
        startsAt: json['startsAt'] as String,
      );

  final String? guestName;
  final String? guestPhone;
  final String? occasion;
  final int partySize;
  final String restaurantId;
  final String? seatingPref;
  final String? specialRequests;
  /// ISO 8601, UTC
  final String startsAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (guestName != null) 'guestName': guestName!,
        if (guestPhone != null) 'guestPhone': guestPhone!,
        if (occasion != null) 'occasion': occasion!,
        'partySize': partySize,
        'restaurantId': restaurantId,
        if (seatingPref != null) 'seatingPref': seatingPref!,
        if (specialRequests != null) 'specialRequests': specialRequests!,
        'startsAt': startsAt,
      };
}

class CreateRestaurantDto {
  const CreateRestaurantDto({
    this.bookingMode,
    this.city,
    this.cuisines,
    required this.lat,
    required this.lng,
    required this.nameAr,
    required this.nameEn,
    this.neighborhood,
    this.priceBand,
    this.slotIntervalMin,
  });

  factory CreateRestaurantDto.fromJson(Map<String, dynamic> json) => CreateRestaurantDto(
        bookingMode: json['bookingMode'] == null ? null : json['bookingMode'] as String,
        city: json['city'] == null ? null : json['city'] as String,
        cuisines: json['cuisines'] == null ? null : (json['cuisines'] as List<dynamic>).map((e) => e as String).toList(),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        nameAr: json['nameAr'] as String,
        nameEn: json['nameEn'] as String,
        neighborhood: json['neighborhood'] == null ? null : json['neighborhood'] as String,
        priceBand: json['priceBand'] == null ? null : (json['priceBand'] as num).toDouble(),
        slotIntervalMin: json['slotIntervalMin'] == null ? null : (json['slotIntervalMin'] as num).toDouble(),
      );

  final String? bookingMode;
  final String? city;
  final List<String>? cuisines;
  final double lat;
  final double lng;
  /// Arabic name — required, not optional (CLAUDE.md: bilingual by column)
  final String nameAr;
  final String nameEn;
  final String? neighborhood;
  final double? priceBand;
  final double? slotIntervalMin;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (bookingMode != null) 'bookingMode': bookingMode!,
        if (city != null) 'city': city!,
        if (cuisines != null) 'cuisines': cuisines!.map((e) => e).toList(),
        'lat': lat,
        'lng': lng,
        'nameAr': nameAr,
        'nameEn': nameEn,
        if (neighborhood != null) 'neighborhood': neighborhood!,
        if (priceBand != null) 'priceBand': priceBand!,
        if (slotIntervalMin != null) 'slotIntervalMin': slotIntervalMin!,
      };
}

class CreateShiftDto {
  const CreateShiftDto({
    this.active,
    required this.closesAt,
    this.dayOfWeek,
    this.defaultTurnMinutes,
    this.isRamadan,
    required this.nameAr,
    required this.nameEn,
    required this.opensAt,
    this.spansMidnight,
    this.specificDate,
  });

  factory CreateShiftDto.fromJson(Map<String, dynamic> json) => CreateShiftDto(
        active: json['active'] == null ? null : json['active'] as bool,
        closesAt: json['closesAt'] as String,
        dayOfWeek: json['dayOfWeek'] == null ? null : (json['dayOfWeek'] as num).toInt(),
        defaultTurnMinutes: json['defaultTurnMinutes'] == null ? null : (json['defaultTurnMinutes'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt())),
        isRamadan: json['isRamadan'] == null ? null : json['isRamadan'] as bool,
        nameAr: json['nameAr'] as String,
        nameEn: json['nameEn'] as String,
        opensAt: json['opensAt'] as String,
        spansMidnight: json['spansMidnight'] == null ? null : json['spansMidnight'] as bool,
        specificDate: json['specificDate'] == null ? null : json['specificDate'] as String,
      );

  final bool? active;
  final String closesAt;
  /// 0=Sunday. Exactly one of this or specificDate.
  final int? dayOfWeek;
  /// Party-size band → turn minutes. A bare `type: object` here would generate Map<String, dynamic> in the client, so the value type is declared.
  final Map<String, int>? defaultTurnMinutes;
  /// Flag only — Maghrib anchoring is not implemented yet
  final bool? isRamadan;
  final String nameAr;
  final String nameEn;
  /// Restaurant wall clock, 24h
  final String opensAt;
  /// Set for sohour-style shifts running past midnight
  final bool? spansMidnight;
  /// Exactly one of this or dayOfWeek.
  final String? specificDate;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (active != null) 'active': active!,
        'closesAt': closesAt,
        if (dayOfWeek != null) 'dayOfWeek': dayOfWeek!,
        if (defaultTurnMinutes != null) 'defaultTurnMinutes': defaultTurnMinutes!,
        if (isRamadan != null) 'isRamadan': isRamadan!,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'opensAt': opensAt,
        if (spansMidnight != null) 'spansMidnight': spansMidnight!,
        if (specificDate != null) 'specificDate': specificDate!,
      };
}

class CreateTableDto {
  const CreateTableDto({
    this.combinableWith,
    required this.maxCapacity,
    required this.minCapacity,
    required this.name,
    this.priority,
    this.zone,
  });

  factory CreateTableDto.fromJson(Map<String, dynamic> json) => CreateTableDto(
        combinableWith: json['combinableWith'] == null ? null : (json['combinableWith'] as List<dynamic>).map((e) => e as String).toList(),
        maxCapacity: (json['maxCapacity'] as num).toInt(),
        minCapacity: (json['minCapacity'] as num).toInt(),
        name: json['name'] as String,
        priority: json['priority'] == null ? null : (json['priority'] as num).toInt(),
        zone: json['zone'] == null ? null : json['zone'] as String,
      );

  /// Table ids in THIS restaurant
  final List<String>? combinableWith;
  final int maxCapacity;
  /// Smallest party this table is offered to
  final int minCapacity;
  final String name;
  /// Allocation preference — lower assigns first
  final int? priority;
  final String? zone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (combinableWith != null) 'combinableWith': combinableWith!.map((e) => e).toList(),
        'maxCapacity': maxCapacity,
        'minCapacity': minCapacity,
        'name': name,
        if (priority != null) 'priority': priority!,
        if (zone != null) 'zone': zone!,
      };
}

class CreateWalkInDto {
  const CreateWalkInDto({
    this.guestName,
    this.guestPhone,
    this.occasion,
    required this.partySize,
    this.seatingPref,
    this.source,
    this.specialRequests,
    this.startsAt,
  });

  factory CreateWalkInDto.fromJson(Map<String, dynamic> json) => CreateWalkInDto(
        guestName: json['guestName'] == null ? null : json['guestName'] as String,
        guestPhone: json['guestPhone'] == null ? null : json['guestPhone'] as String,
        occasion: json['occasion'] == null ? null : json['occasion'] as String,
        partySize: (json['partySize'] as num).toInt(),
        seatingPref: json['seatingPref'] == null ? null : json['seatingPref'] as String,
        source: json['source'] == null ? null : json['source'] as String,
        specialRequests: json['specialRequests'] == null ? null : json['specialRequests'] as String,
        startsAt: json['startsAt'] == null ? null : json['startsAt'] as String,
      );

  final String? guestName;
  final String? guestPhone;
  final String? occasion;
  final int partySize;
  final String? seatingPref;
  /// `app` is rejected — staff entries must stay distinguishable from customer ones
  final String? source;
  final String? specialRequests;
  /// ISO-8601 UTC. Omit for a party at the door — defaults to now.
  final String? startsAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (guestName != null) 'guestName': guestName!,
        if (guestPhone != null) 'guestPhone': guestPhone!,
        if (occasion != null) 'occasion': occasion!,
        'partySize': partySize,
        if (seatingPref != null) 'seatingPref': seatingPref!,
        if (source != null) 'source': source!,
        if (specialRequests != null) 'specialRequests': specialRequests!,
        if (startsAt != null) 'startsAt': startsAt!,
      };
}

class ErrorDetailResponse {
  const ErrorDetailResponse({
    required this.field,
    required this.issue,
  });

  factory ErrorDetailResponse.fromJson(Map<String, dynamic> json) => ErrorDetailResponse(
        field: json['field'] as String,
        issue: json['issue'] as String,
      );

  final String field;
  final String issue;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'field': field,
        'issue': issue,
      };
}

class LoginDto {
  const LoginDto({
    required this.identifier,
    required this.password,
  });

  factory LoginDto.fromJson(Map<String, dynamic> json) => LoginDto(
        identifier: json['identifier'] as String,
        password: json['password'] as String,
      );

  /// Phone or email
  final String identifier;
  final String password;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'identifier': identifier,
        'password': password,
      };
}

class LogoutDto {
  const LogoutDto({
    this.allDevices,
    required this.refreshToken,
  });

  factory LogoutDto.fromJson(Map<String, dynamic> json) => LogoutDto(
        allDevices: json['allDevices'] == null ? null : json['allDevices'] as bool,
        refreshToken: json['refreshToken'] as String,
      );

  final bool? allDevices;
  final String refreshToken;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (allDevices != null) 'allDevices': allDevices!,
        'refreshToken': refreshToken,
      };
}

class MyReservationResponse {
  const MyReservationResponse({
    this.cancelReason,
    this.cancelledAt,
    this.cancelledBy,
    required this.code,
    required this.date,
    required this.endsAt,
    required this.id,
    required this.needsAcknowledgement,
    this.occasion,
    required this.partySize,
    required this.restaurant,
    required this.source,
    this.specialRequests,
    required this.startsAt,
    required this.status,
    required this.time,
  });

  factory MyReservationResponse.fromJson(Map<String, dynamic> json) => MyReservationResponse(
        cancelReason: json['cancel_reason'] == null ? null : json['cancel_reason'] as String,
        cancelledAt: json['cancelled_at'] == null ? null : json['cancelled_at'] as String,
        cancelledBy: json['cancelled_by'] == null ? null : json['cancelled_by'] as String,
        code: json['code'] as String,
        date: json['date'] as String,
        endsAt: json['ends_at'] as String,
        id: json['id'] as String,
        needsAcknowledgement: json['needs_acknowledgement'] as bool,
        occasion: json['occasion'] == null ? null : json['occasion'] as String,
        partySize: (json['party_size'] as num).toInt(),
        restaurant: ReservationVenueResponse.fromJson(json['restaurant'] as Map<String, dynamic>),
        source: json['source'] as String,
        specialRequests: json['special_requests'] == null ? null : json['special_requests'] as String,
        startsAt: json['starts_at'] as String,
        status: json['status'] as String,
        time: json['time'] as String,
      );

  final String? cancelReason;
  final String? cancelledAt;
  /// 'user' | 'restaurant' | null. Derived, so no client parses a status string.
  final String? cancelledBy;
  /// Human-readable, quoted at the door. e.g. SAH-7K2M
  final String code;
  /// YYYY-MM-DD on the RESTAURANT'S wall clock.
  final String date;
  final String endsAt;
  final String id;
  /// The RESTAURANT cancelled and the diner has not seen it yet. THE CLIENT MUST SURFACE THIS. It is the only signal that a booking they believe they hold is gone, and a reservation carrying it stays in `upcoming` regardless of date until POST /reservations/{id}/acknowledge-cancellation.
  final bool needsAcknowledgement;
  final String? occasion;
  final int partySize;
  final ReservationVenueResponse restaurant;
  /// app | walk_in | phone — which door it came through.
  final String source;
  final String? specialRequests;
  /// Absolute instant, ISO-8601 UTC.
  final String startsAt;
  /// pending | confirmed | seated | completed | no_show | cancelled_*
  final String status;
  /// HH:MM on the RESTAURANT'S wall clock.
  final String time;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (cancelReason != null) 'cancel_reason': cancelReason!,
        if (cancelledAt != null) 'cancelled_at': cancelledAt!,
        if (cancelledBy != null) 'cancelled_by': cancelledBy!,
        'code': code,
        'date': date,
        'ends_at': endsAt,
        'id': id,
        'needs_acknowledgement': needsAcknowledgement,
        if (occasion != null) 'occasion': occasion!,
        'party_size': partySize,
        'restaurant': restaurant.toJson(),
        'source': source,
        if (specialRequests != null) 'special_requests': specialRequests!,
        'starts_at': startsAt,
        'status': status,
        'time': time,
      };
}

class OpeningHoursResponse {
  const OpeningHoursResponse({
    required this.closesAt,
    this.dayOfWeek,
    required this.nameAr,
    required this.nameEn,
    required this.opensAt,
    required this.spansMidnight,
    this.specificDate,
  });

  factory OpeningHoursResponse.fromJson(Map<String, dynamic> json) => OpeningHoursResponse(
        closesAt: json['closes_at'] as String,
        dayOfWeek: json['day_of_week'] == null ? null : (json['day_of_week'] as num).toInt(),
        nameAr: json['name_ar'] as String,
        nameEn: json['name_en'] as String,
        opensAt: json['opens_at'] as String,
        spansMidnight: json['spans_midnight'] as bool,
        specificDate: json['specific_date'] == null ? null : json['specific_date'] as String,
      );

  final String closesAt;
  /// 0=Sunday; null on a one-off date
  final int? dayOfWeek;
  final String nameAr;
  final String nameEn;
  /// HH:MM on the restaurant's wall clock.
  final String opensAt;
  final bool spansMidnight;
  /// YYYY-MM-DD; null on a weekly row
  final String? specificDate;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'closes_at': closesAt,
        if (dayOfWeek != null) 'day_of_week': dayOfWeek!,
        'name_ar': nameAr,
        'name_en': nameEn,
        'opens_at': opensAt,
        'spans_midnight': spansMidnight,
        if (specificDate != null) 'specific_date': specificDate!,
      };
}

class OtpSentResponse {
  const OtpSentResponse({
    required this.retryAfter,
    required this.sent,
  });

  factory OtpSentResponse.fromJson(Map<String, dynamic> json) => OtpSentResponse(
        retryAfter: (json['retryAfter'] as num).toDouble(),
        sent: json['sent'] as bool,
      );

  /// Seconds until another code may be requested.
  final double retryAfter;
  final bool sent;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'retryAfter': retryAfter,
        'sent': sent,
      };
}

class RefreshDto {
  const RefreshDto({
    required this.refreshToken,
  });

  factory RefreshDto.fromJson(Map<String, dynamic> json) => RefreshDto(
        refreshToken: json['refreshToken'] as String,
      );

  final String refreshToken;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'refreshToken': refreshToken,
      };
}

class RegisterDto {
  const RegisterDto({
    this.email,
    required this.fullName,
    this.locale,
    this.password,
    required this.phone,
  });

  factory RegisterDto.fromJson(Map<String, dynamic> json) => RegisterDto(
        email: json['email'] == null ? null : json['email'] as String,
        fullName: json['fullName'] as String,
        locale: json['locale'] == null ? null : json['locale'] as String,
        password: json['password'] == null ? null : json['password'] as String,
        phone: json['phone'] as String,
      );

  final String? email;
  final String fullName;
  final String? locale;
  /// Optional — OTP-only accounts are supported
  final String? password;
  /// E.164 or local Egyptian (01xxxxxxxxx)
  final String phone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (email != null) 'email': email!,
        'fullName': fullName,
        if (locale != null) 'locale': locale!,
        if (password != null) 'password': password!,
        'phone': phone,
      };
}

class RegisterResponse {
  const RegisterResponse({
    required this.otpRequired,
    required this.userId,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) => RegisterResponse(
        otpRequired: json['otpRequired'] as bool,
        userId: json['userId'] as String,
      );

  final bool otpRequired;
  final String userId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'otpRequired': otpRequired,
        'userId': userId,
      };
}

class RejectRestaurantDto {
  const RejectRestaurantDto({
    this.reason,
  });

  factory RejectRestaurantDto.fromJson(Map<String, dynamic> json) => RejectRestaurantDto(
        reason: json['reason'] == null ? null : json['reason'] as String,
      );

  /// Shown to the owner so they can fix it
  final String? reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (reason != null) 'reason': reason!,
      };
}

class RemoveShiftResponse {
  const RemoveShiftResponse({
    required this.deleted,
    required this.reservationsOutsideHours,
  });

  factory RemoveShiftResponse.fromJson(Map<String, dynamic> json) => RemoveShiftResponse(
        deleted: json['deleted'] as bool,
        reservationsOutsideHours: (json['reservationsOutsideHours'] as List<dynamic>).map((e) => e as String).toList(),
      );

  final bool deleted;
  final List<String> reservationsOutsideHours;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deleted': deleted,
        'reservationsOutsideHours': reservationsOutsideHours.map((e) => e).toList(),
      };
}

class RemoveTableResponse {
  const RemoveTableResponse({
    required this.deactivated,
    required this.deleted,
  });

  factory RemoveTableResponse.fromJson(Map<String, dynamic> json) => RemoveTableResponse(
        deactivated: json['deactivated'] as bool,
        deleted: json['deleted'] as bool,
      );

  /// True when it was retired so history survives.
  final bool deactivated;
  /// True only when the table had never been used.
  final bool deleted;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deactivated': deactivated,
        'deleted': deleted,
      };
}

class RequestOtpDto {
  const RequestOtpDto({
    required this.phone,
  });

  factory RequestOtpDto.fromJson(Map<String, dynamic> json) => RequestOtpDto(
        phone: json['phone'] as String,
      );

  /// E.164 or local Egyptian (01xxxxxxxxx)
  final String phone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'phone': phone,
      };
}

class ResendOtpDto {
  const ResendOtpDto({
    required this.userId,
  });

  factory ResendOtpDto.fromJson(Map<String, dynamic> json) => ResendOtpDto(
        userId: json['userId'] as String,
      );

  final String userId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userId': userId,
      };
}

class ReservationResponse {
  const ReservationResponse({
    required this.code,
    required this.endsAt,
    this.guestName,
    this.guestPhone,
    this.holdExpiresAt,
    required this.id,
    required this.partySize,
    required this.restaurantId,
    required this.source,
    required this.startsAt,
    required this.status,
    this.tables,
    this.userId,
  });

  factory ReservationResponse.fromJson(Map<String, dynamic> json) => ReservationResponse(
        code: json['code'] as String,
        endsAt: json['endsAt'] as String,
        guestName: json['guestName'] == null ? null : json['guestName'] as String,
        guestPhone: json['guestPhone'] == null ? null : json['guestPhone'] as String,
        holdExpiresAt: json['holdExpiresAt'] == null ? null : json['holdExpiresAt'] as String,
        id: json['id'] as String,
        partySize: (json['partySize'] as num).toInt(),
        restaurantId: json['restaurantId'] as String,
        source: json['source'] as String,
        startsAt: json['startsAt'] as String,
        status: json['status'] as String,
        tables: json['tables'] == null ? null : (json['tables'] as List<dynamic>).map((e) => ReservationTableResponse.fromJson(e as Map<String, dynamic>)).toList(),
        userId: json['userId'] == null ? null : json['userId'] as String,
      );

  final String code;
  final String endsAt;
  final String? guestName;
  final String? guestPhone;
  final String? holdExpiresAt;
  final String id;
  final int partySize;
  final String restaurantId;
  final String source;
  final String startsAt;
  final String status;
  final List<ReservationTableResponse>? tables;
  final String? userId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'endsAt': endsAt,
        if (guestName != null) 'guestName': guestName!,
        if (guestPhone != null) 'guestPhone': guestPhone!,
        if (holdExpiresAt != null) 'holdExpiresAt': holdExpiresAt!,
        'id': id,
        'partySize': partySize,
        'restaurantId': restaurantId,
        'source': source,
        'startsAt': startsAt,
        'status': status,
        if (tables != null) 'tables': tables!.map((e) => e.toJson()).toList(),
        if (userId != null) 'userId': userId!,
      };
}

class ReservationTableResponse {
  const ReservationTableResponse({
    required this.tableId,
  });

  factory ReservationTableResponse.fromJson(Map<String, dynamic> json) => ReservationTableResponse(
        tableId: json['tableId'] as String,
      );

  final String tableId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tableId': tableId,
      };
}

class ReservationVenueResponse {
  const ReservationVenueResponse({
    required this.city,
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.neighborhood,
    required this.slug,
    required this.timezone,
  });

  factory ReservationVenueResponse.fromJson(Map<String, dynamic> json) => ReservationVenueResponse(
        city: json['city'] as String,
        id: json['id'] as String,
        nameAr: json['name_ar'] as String,
        nameEn: json['name_en'] as String,
        neighborhood: json['neighborhood'] == null ? null : json['neighborhood'] as String,
        slug: json['slug'] as String,
        timezone: json['timezone'] as String,
      );

  final String city;
  final String id;
  final String nameAr;
  final String nameEn;
  final String? neighborhood;
  final String slug;
  /// IANA zone `date` and `time` are expressed in.
  final String timezone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'city': city,
        'id': id,
        'name_ar': nameAr,
        'name_en': nameEn,
        if (neighborhood != null) 'neighborhood': neighborhood!,
        'slug': slug,
        'timezone': timezone,
      };
}

class RestaurantProfileResponse {
  const RestaurantProfileResponse({
    this.addressAr,
    this.addressEn,
    required this.amenities,
    required this.bookingMode,
    required this.city,
    required this.cuisines,
    this.descriptionAr,
    this.descriptionEn,
    required this.hours,
    required this.id,
    this.lat,
    this.lng,
    required this.nameAr,
    required this.nameEn,
    this.neighborhood,
    this.phone,
    this.policies,
    this.priceBand,
    required this.rating,
    required this.ratingCount,
    required this.slug,
    required this.timezone,
    this.website,
  });

  factory RestaurantProfileResponse.fromJson(Map<String, dynamic> json) => RestaurantProfileResponse(
        addressAr: json['address_ar'] == null ? null : json['address_ar'] as String,
        addressEn: json['address_en'] == null ? null : json['address_en'] as String,
        amenities: (json['amenities'] as List<dynamic>).map((e) => e as String).toList(),
        bookingMode: json['booking_mode'] as String,
        city: json['city'] as String,
        cuisines: (json['cuisines'] as List<dynamic>).map((e) => e as String).toList(),
        descriptionAr: json['description_ar'] == null ? null : json['description_ar'] as String,
        descriptionEn: json['description_en'] == null ? null : json['description_en'] as String,
        hours: (json['hours'] as List<dynamic>).map((e) => OpeningHoursResponse.fromJson(e as Map<String, dynamic>)).toList(),
        id: json['id'] as String,
        lat: json['lat'] == null ? null : (json['lat'] as num).toDouble(),
        lng: json['lng'] == null ? null : (json['lng'] as num).toDouble(),
        nameAr: json['name_ar'] as String,
        nameEn: json['name_en'] as String,
        neighborhood: json['neighborhood'] == null ? null : json['neighborhood'] as String,
        phone: json['phone'] == null ? null : json['phone'] as String,
        policies: json['policies'] == null ? null : json['policies'] as Map<String, dynamic>,
        priceBand: json['price_band'] == null ? null : (json['price_band'] as num).toInt(),
        rating: (json['rating'] as num).toDouble(),
        ratingCount: (json['rating_count'] as num).toInt(),
        slug: json['slug'] as String,
        timezone: json['timezone'] as String,
        website: json['website'] == null ? null : json['website'] as String,
      );

  final String? addressAr;
  final String? addressEn;
  final List<String> amenities;
  /// instant | request
  final String bookingMode;
  final String city;
  final List<String> cuisines;
  final String? descriptionAr;
  final String? descriptionEn;
  final List<OpeningHoursResponse> hours;
  final String id;
  final double? lat;
  final double? lng;
  final String nameAr;
  final String nameEn;
  final String? neighborhood;
  final String? phone;
  final Map<String, dynamic>? policies;
  final int? priceBand;
  final double rating;
  final int ratingCount;
  final String slug;
  /// IANA zone every wall-clock time here is in.
  final String timezone;
  final String? website;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (addressAr != null) 'address_ar': addressAr!,
        if (addressEn != null) 'address_en': addressEn!,
        'amenities': amenities.map((e) => e).toList(),
        'booking_mode': bookingMode,
        'city': city,
        'cuisines': cuisines.map((e) => e).toList(),
        if (descriptionAr != null) 'description_ar': descriptionAr!,
        if (descriptionEn != null) 'description_en': descriptionEn!,
        'hours': hours.map((e) => e.toJson()).toList(),
        'id': id,
        if (lat != null) 'lat': lat!,
        if (lng != null) 'lng': lng!,
        'name_ar': nameAr,
        'name_en': nameEn,
        if (neighborhood != null) 'neighborhood': neighborhood!,
        if (phone != null) 'phone': phone!,
        if (policies != null) 'policies': policies!,
        if (priceBand != null) 'price_band': priceBand!,
        'rating': rating,
        'rating_count': ratingCount,
        'slug': slug,
        'timezone': timezone,
        if (website != null) 'website': website!,
      };
}

class RestaurantResponse {
  const RestaurantResponse({
    required this.city,
    this.descriptionAr,
    this.descriptionEn,
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.neighborhood,
    this.priceBand,
    required this.slug,
    required this.status,
  });

  factory RestaurantResponse.fromJson(Map<String, dynamic> json) => RestaurantResponse(
        city: json['city'] as String,
        descriptionAr: json['descriptionAr'] == null ? null : json['descriptionAr'] as String,
        descriptionEn: json['descriptionEn'] == null ? null : json['descriptionEn'] as String,
        id: json['id'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: json['nameEn'] as String,
        neighborhood: json['neighborhood'] == null ? null : json['neighborhood'] as String,
        priceBand: json['priceBand'] == null ? null : (json['priceBand'] as num).toInt(),
        slug: json['slug'] as String,
        status: json['status'] as String,
      );

  final String city;
  final String? descriptionAr;
  final String? descriptionEn;
  final String id;
  final String nameAr;
  final String nameEn;
  final String? neighborhood;
  final int? priceBand;
  final String slug;
  final String status;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'city': city,
        if (descriptionAr != null) 'descriptionAr': descriptionAr!,
        if (descriptionEn != null) 'descriptionEn': descriptionEn!,
        'id': id,
        'nameAr': nameAr,
        'nameEn': nameEn,
        if (neighborhood != null) 'neighborhood': neighborhood!,
        if (priceBand != null) 'priceBand': priceBand!,
        'slug': slug,
        'status': status,
      };
}

class SearchResponse {
  const SearchResponse({
    required this.availabilityFiltered,
    required this.estimatedTotal,
    this.nextCursor,
    required this.results,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) => SearchResponse(
        availabilityFiltered: json['availability_filtered'] as bool,
        estimatedTotal: (json['estimated_total'] as num).toInt(),
        nextCursor: json['next_cursor'] == null ? null : json['next_cursor'] as String,
        results: (json['results'] as List<dynamic>).map((e) => SearchResultResponse.fromJson(e as Map<String, dynamic>)).toList(),
      );

  final bool availabilityFiltered;
  final int estimatedTotal;
  final String? nextCursor;
  final List<SearchResultResponse> results;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'availability_filtered': availabilityFiltered,
        'estimated_total': estimatedTotal,
        if (nextCursor != null) 'next_cursor': nextCursor!,
        'results': results.map((e) => e.toJson()).toList(),
      };
}

class SearchResultResponse {
  const SearchResultResponse({
    required this.cuisines,
    this.distanceKm,
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.neighborhood,
    this.nextAvailable,
    this.priceBand,
    required this.rating,
    required this.ratingCount,
    required this.slug,
  });

  factory SearchResultResponse.fromJson(Map<String, dynamic> json) => SearchResultResponse(
        cuisines: (json['cuisines'] as List<dynamic>).map((e) => e as String).toList(),
        distanceKm: json['distance_km'] == null ? null : (json['distance_km'] as num).toDouble(),
        id: json['id'] as String,
        nameAr: json['name_ar'] as String,
        nameEn: json['name_en'] as String,
        neighborhood: json['neighborhood'] == null ? null : json['neighborhood'] as String,
        nextAvailable: json['next_available'] == null ? null : (json['next_available'] as List<dynamic>).map((e) => e as String).toList(),
        priceBand: json['price_band'] == null ? null : (json['price_band'] as num).toInt(),
        rating: (json['rating'] as num).toDouble(),
        ratingCount: (json['rating_count'] as num).toInt(),
        slug: json['slug'] as String,
      );

  final List<String> cuisines;
  final double? distanceKm;
  final String id;
  final String nameAr;
  final String nameEn;
  final String? neighborhood;
  /// Local HH:MM teasers. A HINT, not an offer — no absolute instant is given precisely so no client can treat one as bookable.
  final List<String>? nextAvailable;
  final int? priceBand;
  final double rating;
  final int ratingCount;
  final String slug;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cuisines': cuisines.map((e) => e).toList(),
        if (distanceKm != null) 'distance_km': distanceKm!,
        'id': id,
        'name_ar': nameAr,
        'name_en': nameEn,
        if (neighborhood != null) 'neighborhood': neighborhood!,
        if (nextAvailable != null) 'next_available': nextAvailable!.map((e) => e).toList(),
        if (priceBand != null) 'price_band': priceBand!,
        'rating': rating,
        'rating_count': ratingCount,
        'slug': slug,
      };
}

class ShiftResponse {
  const ShiftResponse({
    required this.active,
    required this.closesAt,
    this.dayOfWeek,
    required this.defaultTurnMinutes,
    required this.id,
    required this.isRamadan,
    required this.nameAr,
    required this.nameEn,
    required this.opensAt,
    required this.spansMidnight,
    this.specificDate,
  });

  factory ShiftResponse.fromJson(Map<String, dynamic> json) => ShiftResponse(
        active: json['active'] as bool,
        closesAt: json['closesAt'] as String,
        dayOfWeek: json['dayOfWeek'] == null ? null : (json['dayOfWeek'] as num).toInt(),
        defaultTurnMinutes: (json['defaultTurnMinutes'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt())),
        id: json['id'] as String,
        isRamadan: json['isRamadan'] as bool,
        nameAr: json['nameAr'] as String,
        nameEn: json['nameEn'] as String,
        opensAt: json['opensAt'] as String,
        spansMidnight: json['spansMidnight'] as bool,
        specificDate: json['specificDate'] == null ? null : json['specificDate'] as String,
      );

  final bool active;
  final String closesAt;
  final int? dayOfWeek;
  /// Party-size band → turn minutes, e.g. {"1-2":90}.
  final Map<String, int> defaultTurnMinutes;
  final String id;
  final bool isRamadan;
  final String nameAr;
  final String nameEn;
  final String opensAt;
  final bool spansMidnight;
  final String? specificDate;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'active': active,
        'closesAt': closesAt,
        if (dayOfWeek != null) 'dayOfWeek': dayOfWeek!,
        'defaultTurnMinutes': defaultTurnMinutes,
        'id': id,
        'isRamadan': isRamadan,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'opensAt': opensAt,
        'spansMidnight': spansMidnight,
        if (specificDate != null) 'specificDate': specificDate!,
      };
}

class ShiftWriteResponse {
  const ShiftWriteResponse({
    required this.reservationsOutsideHours,
    required this.shift,
  });

  factory ShiftWriteResponse.fromJson(Map<String, dynamic> json) => ShiftWriteResponse(
        reservationsOutsideHours: (json['reservationsOutsideHours'] as List<dynamic>).map((e) => e as String).toList(),
        shift: ShiftResponse.fromJson(json['shift'] as Map<String, dynamic>),
      );

  /// Live future bookings now outside the shift. NEVER cancelled — returned so the restaurant can contact those guests.
  final List<String> reservationsOutsideHours;
  final ShiftResponse shift;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'reservationsOutsideHours': reservationsOutsideHours.map((e) => e).toList(),
        'shift': shift.toJson(),
      };
}

class SlotResponse {
  const SlotResponse({
    required this.startsAt,
    required this.time,
    required this.zones,
  });

  factory SlotResponse.fromJson(Map<String, dynamic> json) => SlotResponse(
        startsAt: json['startsAt'] as String,
        time: json['time'] as String,
        zones: (json['zones'] as List<dynamic>).map((e) => e as String).toList(),
      );

  /// Absolute instant, ISO-8601 UTC. POST this back.
  final String startsAt;
  /// HH:MM on the RESTAURANT'S wall clock.
  final String time;
  final List<String> zones;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'startsAt': startsAt,
        'time': time,
        'zones': zones.map((e) => e).toList(),
      };
}

class TableResponse {
  const TableResponse({
    required this.active,
    required this.combinableWith,
    required this.id,
    required this.maxCapacity,
    required this.minCapacity,
    required this.name,
    required this.priority,
    required this.zone,
  });

  factory TableResponse.fromJson(Map<String, dynamic> json) => TableResponse(
        active: json['active'] as bool,
        combinableWith: (json['combinableWith'] as List<dynamic>).map((e) => e as String).toList(),
        id: json['id'] as String,
        maxCapacity: (json['maxCapacity'] as num).toInt(),
        minCapacity: (json['minCapacity'] as num).toInt(),
        name: json['name'] as String,
        priority: (json['priority'] as num).toInt(),
        zone: json['zone'] as String,
      );

  final bool active;
  final List<String> combinableWith;
  final String id;
  final int maxCapacity;
  final int minCapacity;
  final String name;
  final int priority;
  final String zone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'active': active,
        'combinableWith': combinableWith.map((e) => e).toList(),
        'id': id,
        'maxCapacity': maxCapacity,
        'minCapacity': minCapacity,
        'name': name,
        'priority': priority,
        'zone': zone,
      };
}

class TokenPairResponse {
  const TokenPairResponse({
    required this.accessToken,
    required this.expiresIn,
    required this.refreshToken,
    required this.user,
  });

  factory TokenPairResponse.fromJson(Map<String, dynamic> json) => TokenPairResponse(
        accessToken: json['accessToken'] as String,
        expiresIn: (json['expiresIn'] as num).toInt(),
        refreshToken: json['refreshToken'] as String,
        user: UserResponse.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String accessToken;
  final int expiresIn;
  final String refreshToken;
  final UserResponse user;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accessToken': accessToken,
        'expiresIn': expiresIn,
        'refreshToken': refreshToken,
        'user': user.toJson(),
      };
}

class UpdateRestaurantDto {
  const UpdateRestaurantDto({
    this.bookingMode,
    this.city,
    this.cuisines,
    this.descriptionAr,
    this.descriptionEn,
    this.nameAr,
    this.nameEn,
    this.neighborhood,
    this.priceBand,
    this.slotIntervalMin,
  });

  factory UpdateRestaurantDto.fromJson(Map<String, dynamic> json) => UpdateRestaurantDto(
        bookingMode: json['bookingMode'] == null ? null : json['bookingMode'] as String,
        city: json['city'] == null ? null : json['city'] as String,
        cuisines: json['cuisines'] == null ? null : (json['cuisines'] as List<dynamic>).map((e) => e as String).toList(),
        descriptionAr: json['descriptionAr'] == null ? null : json['descriptionAr'] as String,
        descriptionEn: json['descriptionEn'] == null ? null : json['descriptionEn'] as String,
        nameAr: json['nameAr'] == null ? null : json['nameAr'] as String,
        nameEn: json['nameEn'] == null ? null : json['nameEn'] as String,
        neighborhood: json['neighborhood'] == null ? null : json['neighborhood'] as String,
        priceBand: json['priceBand'] == null ? null : (json['priceBand'] as num).toDouble(),
        slotIntervalMin: json['slotIntervalMin'] == null ? null : (json['slotIntervalMin'] as num).toDouble(),
      );

  final String? bookingMode;
  final String? city;
  final List<String>? cuisines;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? nameAr;
  final String? nameEn;
  final String? neighborhood;
  final double? priceBand;
  final double? slotIntervalMin;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (bookingMode != null) 'bookingMode': bookingMode!,
        if (city != null) 'city': city!,
        if (cuisines != null) 'cuisines': cuisines!.map((e) => e).toList(),
        if (descriptionAr != null) 'descriptionAr': descriptionAr!,
        if (descriptionEn != null) 'descriptionEn': descriptionEn!,
        if (nameAr != null) 'nameAr': nameAr!,
        if (nameEn != null) 'nameEn': nameEn!,
        if (neighborhood != null) 'neighborhood': neighborhood!,
        if (priceBand != null) 'priceBand': priceBand!,
        if (slotIntervalMin != null) 'slotIntervalMin': slotIntervalMin!,
      };
}

class UpdateShiftDto {
  const UpdateShiftDto({
    this.active,
    this.closesAt,
    this.dayOfWeek,
    this.defaultTurnMinutes,
    this.isRamadan,
    this.nameAr,
    this.nameEn,
    this.opensAt,
    this.spansMidnight,
    this.specificDate,
  });

  factory UpdateShiftDto.fromJson(Map<String, dynamic> json) => UpdateShiftDto(
        active: json['active'] == null ? null : json['active'] as bool,
        closesAt: json['closesAt'] == null ? null : json['closesAt'] as String,
        dayOfWeek: json['dayOfWeek'] == null ? null : (json['dayOfWeek'] as num).toInt(),
        defaultTurnMinutes: json['defaultTurnMinutes'] == null ? null : (json['defaultTurnMinutes'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt())),
        isRamadan: json['isRamadan'] == null ? null : json['isRamadan'] as bool,
        nameAr: json['nameAr'] == null ? null : json['nameAr'] as String,
        nameEn: json['nameEn'] == null ? null : json['nameEn'] as String,
        opensAt: json['opensAt'] == null ? null : json['opensAt'] as String,
        spansMidnight: json['spansMidnight'] == null ? null : json['spansMidnight'] as bool,
        specificDate: json['specificDate'] == null ? null : json['specificDate'] as String,
      );

  final bool? active;
  final String? closesAt;
  /// 0=Sunday. Exactly one of this or specificDate.
  final int? dayOfWeek;
  /// Party-size band → turn minutes. A bare `type: object` here would generate Map<String, dynamic> in the client, so the value type is declared.
  final Map<String, int>? defaultTurnMinutes;
  /// Flag only — Maghrib anchoring is not implemented yet
  final bool? isRamadan;
  final String? nameAr;
  final String? nameEn;
  /// Restaurant wall clock, 24h
  final String? opensAt;
  /// Set for sohour-style shifts running past midnight
  final bool? spansMidnight;
  /// Exactly one of this or dayOfWeek.
  final String? specificDate;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (active != null) 'active': active!,
        if (closesAt != null) 'closesAt': closesAt!,
        if (dayOfWeek != null) 'dayOfWeek': dayOfWeek!,
        if (defaultTurnMinutes != null) 'defaultTurnMinutes': defaultTurnMinutes!,
        if (isRamadan != null) 'isRamadan': isRamadan!,
        if (nameAr != null) 'nameAr': nameAr!,
        if (nameEn != null) 'nameEn': nameEn!,
        if (opensAt != null) 'opensAt': opensAt!,
        if (spansMidnight != null) 'spansMidnight': spansMidnight!,
        if (specificDate != null) 'specificDate': specificDate!,
      };
}

class UpdateTableDto {
  const UpdateTableDto({
    this.active,
    this.combinableWith,
    this.maxCapacity,
    this.minCapacity,
    this.name,
    this.priority,
    this.zone,
  });

  factory UpdateTableDto.fromJson(Map<String, dynamic> json) => UpdateTableDto(
        active: json['active'] == null ? null : json['active'] as bool,
        combinableWith: json['combinableWith'] == null ? null : (json['combinableWith'] as List<dynamic>).map((e) => e as String).toList(),
        maxCapacity: json['maxCapacity'] == null ? null : (json['maxCapacity'] as num).toInt(),
        minCapacity: json['minCapacity'] == null ? null : (json['minCapacity'] as num).toInt(),
        name: json['name'] == null ? null : json['name'] as String,
        priority: json['priority'] == null ? null : (json['priority'] as num).toInt(),
        zone: json['zone'] == null ? null : json['zone'] as String,
      );

  /// false retires the table; 409 if it has future bookings
  final bool? active;
  final List<String>? combinableWith;
  final int? maxCapacity;
  final int? minCapacity;
  final String? name;
  final int? priority;
  final String? zone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (active != null) 'active': active!,
        if (combinableWith != null) 'combinableWith': combinableWith!.map((e) => e).toList(),
        if (maxCapacity != null) 'maxCapacity': maxCapacity!,
        if (minCapacity != null) 'minCapacity': minCapacity!,
        if (name != null) 'name': name!,
        if (priority != null) 'priority': priority!,
        if (zone != null) 'zone': zone!,
      };
}

class UserResponse {
  const UserResponse({
    this.email,
    required this.fullName,
    required this.id,
    required this.locale,
    required this.phone,
    required this.roles,
    required this.status,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) => UserResponse(
        email: json['email'] == null ? null : json['email'] as String,
        fullName: json['fullName'] as String,
        id: json['id'] as String,
        locale: json['locale'] as String,
        phone: json['phone'] as String,
        roles: (json['roles'] as List<dynamic>).map((e) => e as String).toList(),
        status: json['status'] as String,
      );

  final String? email;
  final String fullName;
  final String id;
  final String locale;
  final String phone;
  final List<String> roles;
  final String status;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (email != null) 'email': email!,
        'fullName': fullName,
        'id': id,
        'locale': locale,
        'phone': phone,
        'roles': roles.map((e) => e).toList(),
        'status': status,
      };
}

class VerifyOtpDto {
  const VerifyOtpDto({
    required this.code,
    this.purpose,
    required this.userId,
  });

  factory VerifyOtpDto.fromJson(Map<String, dynamic> json) => VerifyOtpDto(
        code: json['code'] as String,
        purpose: json['purpose'] == null ? null : json['purpose'] as String,
        userId: json['userId'] as String,
      );

  final String code;
  final String? purpose;
  final String userId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        if (purpose != null) 'purpose': purpose!,
        'userId': userId,
      };
}

