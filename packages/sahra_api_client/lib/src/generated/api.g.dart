// GENERATED — DO NOT EDIT BY HAND.
//
// Source: apps/api/openapi.json, exported from the running NestJS app.
// Regenerate: dart run tool/generate_client.dart
//
// Typed endpoint methods.
//
// Editing this file is how the client and the backend start to disagree
// without anyone noticing. client_drift_test.dart fails if you do.

import 'models.g.dart';
import '../transport.dart';

/// Every endpoint in the committed spec, typed both ways.
class SahraApi {
  const SahraApi(this._transport);

  final SahraTransport _transport;

  /// `GET /v1/admin/restaurants`
  ///
  /// The pending_review queue, oldest first
  Future<List<AdminRestaurantResponse>> list() async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/admin/restaurants',
    );
    return (response as List<dynamic>).map((e) => AdminRestaurantResponse.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `POST /v1/admin/restaurants/{id}/approve`
  ///
  /// pending_review to active
  Future<AdminRestaurantResponse> approve({
    required String id,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/admin/restaurants/$id/approve',
    );
    return AdminRestaurantResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/admin/restaurants/{id}/reject`
  ///
  /// pending_review back to draft, with a reason
  Future<AdminRestaurantResponse> reject({
    required String id,
    required RejectRestaurantDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/admin/restaurants/$id/reject',
      body: body.toJson(),
    );
    return AdminRestaurantResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/auth/complete-registration`
  ///
  /// Create the account for a verified challenge
  Future<TokenPairResponse> completeRegistration({
    required CompleteRegistrationDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/auth/complete-registration',
      body: body.toJson(),
    );
    return TokenPairResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/auth/login`
  ///
  /// Password login
  Future<TokenPairResponse> login({
    required LoginDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/auth/login',
      body: body.toJson(),
    );
    return TokenPairResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/auth/logout`
  ///
  /// Revoke this refresh token, or every one for the user
  Future<void> logout({
    required LogoutDto body,
  }) async {
    await _transport.send(
      method: 'POST',
      path: '/v1/auth/logout',
      body: body.toJson(),
    );
    return;
  }

  /// `GET /v1/auth/me`
  ///
  /// The caller identified by the access token
  Future<UserResponse> me() async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/auth/me',
    );
    return UserResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/auth/refresh`
  ///
  /// Rotate the refresh token
  Future<TokenPairResponse> refresh({
    required RefreshDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/auth/refresh',
      body: body.toJson(),
    );
    return TokenPairResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/auth/register`
  ///
  /// Create an account (phone is the primary identity)
  Future<RegisterResponse> register({
    required RegisterDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/auth/register',
      body: body.toJson(),
    );
    return RegisterResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/auth/request-otp`
  ///
  /// Send a code to a phone. No account lookup.
  Future<OtpChallengeResponse> requestOtp({
    required RequestOtpDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/auth/request-otp',
      body: body.toJson(),
    );
    return OtpChallengeResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/auth/resend-otp`
  ///
  /// Re-send to the number the challenge went to
  Future<OtpChallengeResponse> resendOtp({
    required ResendOtpDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/auth/resend-otp',
      body: body.toJson(),
    );
    return OtpChallengeResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/auth/verify-otp`
  ///
  /// Answer a challenge; signs in or asks for a name
  Future<VerifyOtpResponse> verifyOtp({
    required VerifyOtpDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/auth/verify-otp',
      body: body.toJson(),
    );
    return VerifyOtpResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `DELETE /v1/devices`
  ///
  /// Revoke this handset — call on sign-out
  Future<void> revoke({
    required RevokeDeviceDto body,
  }) async {
    await _transport.send(
      method: 'DELETE',
      path: '/v1/devices',
      body: body.toJson(),
    );
    return;
  }

  /// `POST /v1/devices`
  ///
  /// Register this handset for push
  Future<DeviceResponse> register2({
    required RegisterDeviceDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/devices',
      body: body.toJson(),
    );
    return DeviceResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/owner/reservations/{id}/cancel`
  ///
  /// Cancel a booking, as the restaurant
  Future<CancelledReservationResponse> cancel({
    required String id,
    required CancelReservationDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/owner/reservations/$id/cancel',
      body: body.toJson(),
    );
    return CancelledReservationResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /v1/owner/restaurants`
  ///
  /// List my restaurants
  Future<List<RestaurantResponse>> listMine() async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/owner/restaurants',
    );
    return (response as List<dynamic>).map((e) => RestaurantResponse.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `POST /v1/owner/restaurants`
  ///
  /// Create a restaurant (lands in draft)
  Future<RestaurantResponse> create({
    required CreateRestaurantDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/owner/restaurants',
      body: body.toJson(),
    );
    return RestaurantResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /v1/owner/restaurants/{id}`
  ///
  /// Get one of my restaurants
  Future<RestaurantResponse> getOne({
    required String id,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/owner/restaurants/$id',
    );
    return RestaurantResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `PATCH /v1/owner/restaurants/{id}`
  ///
  /// Update profile, policies, amenities
  Future<RestaurantResponse> update({
    required String id,
    required UpdateRestaurantDto body,
  }) async {
    final response = await _transport.send(
      method: 'PATCH',
      path: '/v1/owner/restaurants/$id',
      body: body.toJson(),
    );
    return RestaurantResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /v1/owner/restaurants/{id}/reservations`
  ///
  /// Tonight's book, in the restaurant's local time
  Future<BookResponse> reservations({
    required String id,
    String? date,
    String? status,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/owner/restaurants/$id/reservations',
      query: <String, String>{
        if (date != null) 'date': date,
        if (status != null) 'status': status,
      },
    );
    return BookResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/owner/restaurants/{id}/submit`
  ///
  /// draft → pending_review
  Future<RestaurantResponse> submit({
    required String id,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/owner/restaurants/$id/submit',
    );
    return RestaurantResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/owner/restaurants/{restaurantId}/reservations`
  ///
  /// Seat a walk-in or take a phone booking
  Future<ReservationResponse> createWalkIn({
    required String restaurantId,
    required CreateWalkInDto body,
    required String idempotencyKey,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/owner/restaurants/$restaurantId/reservations',
      headers: <String, String>{
        'idempotency-key': idempotencyKey,
      },
      body: body.toJson(),
    );
    return ReservationResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /v1/owner/restaurants/{restaurantId}/shifts`
  ///
  /// List opening hours
  Future<List<ShiftResponse>> listShifts({
    required String restaurantId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/owner/restaurants/$restaurantId/shifts',
    );
    return (response as List<dynamic>).map((e) => ShiftResponse.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `POST /v1/owner/restaurants/{restaurantId}/shifts`
  ///
  /// Add a shift (weekly or one-off date)
  Future<ShiftResponse> createShift({
    required String restaurantId,
    required CreateShiftDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/owner/restaurants/$restaurantId/shifts',
      body: body.toJson(),
    );
    return ShiftResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `DELETE /v1/owner/restaurants/{restaurantId}/shifts/{shiftId}`
  ///
  /// Remove a shift
  Future<RemoveShiftResponse> removeShift({
    required String restaurantId,
    required String shiftId,
    String? force,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      path: '/v1/owner/restaurants/$restaurantId/shifts/$shiftId',
      query: <String, String>{
        if (force != null) 'force': force,
      },
    );
    return RemoveShiftResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /v1/owner/restaurants/{restaurantId}/shifts/{shiftId}`
  ///
  /// Get one shift
  Future<ShiftResponse> getShift({
    required String restaurantId,
    required String shiftId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/owner/restaurants/$restaurantId/shifts/$shiftId',
    );
    return ShiftResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `PATCH /v1/owner/restaurants/{restaurantId}/shifts/{shiftId}`
  ///
  /// Edit opening hours
  Future<ShiftWriteResponse> updateShift({
    required String restaurantId,
    required String shiftId,
    required UpdateShiftDto body,
    String? force,
  }) async {
    final response = await _transport.send(
      method: 'PATCH',
      path: '/v1/owner/restaurants/$restaurantId/shifts/$shiftId',
      query: <String, String>{
        if (force != null) 'force': force,
      },
      body: body.toJson(),
    );
    return ShiftWriteResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /v1/owner/restaurants/{restaurantId}/tables`
  ///
  /// List tables
  Future<List<TableResponse>> listTables({
    required String restaurantId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/owner/restaurants/$restaurantId/tables',
    );
    return (response as List<dynamic>).map((e) => TableResponse.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `POST /v1/owner/restaurants/{restaurantId}/tables`
  ///
  /// Add a table
  Future<TableResponse> createTable({
    required String restaurantId,
    required CreateTableDto body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/owner/restaurants/$restaurantId/tables',
      body: body.toJson(),
    );
    return TableResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `DELETE /v1/owner/restaurants/{restaurantId}/tables/{tableId}`
  ///
  /// Remove a table — hard delete if never used, otherwise retired so history survives
  Future<RemoveTableResponse> removeTable({
    required String restaurantId,
    required String tableId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      path: '/v1/owner/restaurants/$restaurantId/tables/$tableId',
    );
    return RemoveTableResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /v1/owner/restaurants/{restaurantId}/tables/{tableId}`
  ///
  /// Get one table
  Future<TableResponse> getTable({
    required String restaurantId,
    required String tableId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/owner/restaurants/$restaurantId/tables/$tableId',
    );
    return TableResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `PATCH /v1/owner/restaurants/{restaurantId}/tables/{tableId}`
  ///
  /// Edit a table
  Future<TableResponse> updateTable({
    required String restaurantId,
    required String tableId,
    required UpdateTableDto body,
  }) async {
    final response = await _transport.send(
      method: 'PATCH',
      path: '/v1/owner/restaurants/$restaurantId/tables/$tableId',
      body: body.toJson(),
    );
    return TableResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /v1/reservations`
  ///
  /// The caller's own reservations
  Future<List<MyReservationResponse>> list2({
    String? status,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/reservations',
      query: <String, String>{
        if (status != null) 'status': status,
      },
    );
    return (response as List<dynamic>).map((e) => MyReservationResponse.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `POST /v1/reservations/holds`
  ///
  /// Hold a table for 5 minutes
  Future<ReservationResponse> createHold({
    required CreateHoldDto body,
    required String idempotencyKey,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/reservations/holds',
      headers: <String, String>{
        'idempotency-key': idempotencyKey,
      },
      body: body.toJson(),
    );
    return ReservationResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/reservations/holds/{id}/confirm`
  ///
  /// Confirm a held table
  Future<ReservationResponse> confirm({
    required String id,
    required ConfirmHoldDto body,
    required String idempotencyKey,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: '/v1/reservations/holds/$id/confirm',
      headers: <String, String>{
        'idempotency-key': idempotencyKey,
      },
      body: body.toJson(),
    );
    return ReservationResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /v1/reservations/{id}`
  ///
  /// One of the caller's own reservations
  Future<MyReservationResponse> one({
    required String id,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/reservations/$id',
    );
    return MyReservationResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `POST /v1/reservations/{id}/acknowledge-cancellation`
  ///
  /// Mark a restaurant-initiated cancellation as seen
  Future<void> acknowledge({
    required String id,
  }) async {
    await _transport.send(
      method: 'POST',
      path: '/v1/reservations/$id/acknowledge-cancellation',
    );
    return;
  }

  /// `GET /v1/restaurants/search`
  ///
  /// Discovery search — text + facets, availability post-filtered
  Future<SearchResponse> find({
    String? q,
    String? cuisine,
    String? neighborhood,
    String? priceBand,
    String? ratingMin,
    String? lat,
    String? lng,
    String? radiusKm,
    String? availableAt,
    String? partySize,
    String? amenities,
    String? sort,
    String? cursor,
    String? limit,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/restaurants/search',
      query: <String, String>{
        if (q != null) 'q': q,
        if (cuisine != null) 'cuisine': cuisine,
        if (neighborhood != null) 'neighborhood': neighborhood,
        if (priceBand != null) 'price_band': priceBand,
        if (ratingMin != null) 'rating_min': ratingMin,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radiusKm != null) 'radius_km': radiusKm,
        if (availableAt != null) 'available_at': availableAt,
        if (partySize != null) 'party_size': partySize,
        if (amenities != null) 'amenities': amenities,
        if (sort != null) 'sort': sort,
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    return SearchResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /v1/restaurants/{idOrSlug}`
  ///
  /// Public restaurant profile, by id or slug
  Future<RestaurantProfileResponse> profile({
    required String idOrSlug,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/restaurants/$idOrSlug',
    );
    return RestaurantProfileResponse.fromJson(response as Map<String, dynamic>);
  }

  /// `GET /v1/restaurants/{id}/availability`
  ///
  /// Bookable slots for a date and party size
  Future<AvailabilityResponse> getSlots({
    required String id,
    String? date,
    String? partySize,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      path: '/v1/restaurants/$id/availability',
      query: <String, String>{
        if (date != null) 'date': date,
        if (partySize != null) 'party_size': partySize,
      },
    );
    return AvailabilityResponse.fromJson(response as Map<String, dynamic>);
  }
}
