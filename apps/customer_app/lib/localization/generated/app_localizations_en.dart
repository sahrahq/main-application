// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get errAccountUnavailable =>
      'This account can\'t be used right now. Please contact support.';

  @override
  String get errBadRequest =>
      'Something about that request wasn\'t right. Please try again.';

  @override
  String get errBookingsOutsideNewHours =>
      'Some confirmed bookings fall outside these hours.';

  @override
  String get errCapacityConflictWithReservations =>
      'Upcoming bookings on this table no longer fit the new capacity.';

  @override
  String get errConflict =>
      'That doesn\'t match the current state. Please refresh and try again.';

  @override
  String get errDuplicateRequest => 'That request was already sent.';

  @override
  String get errForbidden => 'You don\'t have permission to do that.';

  @override
  String get errForbiddenRole => 'Your role doesn\'t allow that.';

  @override
  String get errHoldExpired =>
      'Your hold expired. Pick a time again — it only takes a moment.';

  @override
  String get errInternalError =>
      'Something went wrong on our side. Please try again.';

  @override
  String get errInvalidAvailabilityFilter =>
      'Choose a date and a party size together.';

  @override
  String get errInvalidCredentials =>
      'That phone number or password didn\'t match.';

  @override
  String get errInvalidDate => 'That date doesn\'t look right.';

  @override
  String get errInvalidIdempotencyKey =>
      'Something went wrong sending that. Please try again.';

  @override
  String get errInvalidOtp => 'That code isn\'t right. Check it and try again.';

  @override
  String get errInvalidPartySize => 'Choose a party size between 1 and 50.';

  @override
  String get errInvalidQueryParam => 'One of those filters isn\'t valid.';

  @override
  String get errInvalidSort => 'That sort option isn\'t available.';

  @override
  String get errInvalidStatusTransition =>
      'That booking has already moved on. Refresh to see where it stands.';

  @override
  String get errMissingIdempotencyKey =>
      'Something went wrong sending that. Please try again.';

  @override
  String get errNotAnOwner =>
      'This account isn\'t registered as a restaurant owner.';

  @override
  String get errNotFound => 'We couldn\'t find that.';

  @override
  String get errOtpExpired => 'That code has expired. Ask for a new one.';

  @override
  String get errOtpRateLimited =>
      'You\'ve asked for a few codes already. Try again in a few minutes.';

  @override
  String get errPacingLimitReached =>
      'The kitchen is at capacity for that time. Try a slot nearby.';

  @override
  String get errPayloadTooLarge => 'That file is too large.';

  @override
  String get errRateLimited => 'That\'s a lot of requests. Give it a moment.';

  @override
  String get errReservationNotFound => 'We couldn\'t find that booking.';

  @override
  String get errRestaurantNotFound => 'We couldn\'t find that restaurant.';

  @override
  String get errSearchUnavailable =>
      'Search is having a moment. Please try again.';

  @override
  String get errServiceBusy =>
      'This restaurant is busy right now. Try again in a moment.';

  @override
  String get errServiceUnavailable =>
      'That service is briefly unavailable. Please try again.';

  @override
  String get errShiftNotFound => 'We couldn\'t find those opening hours.';

  @override
  String get errShiftOverlap => 'Those hours overlap a shift you already have.';

  @override
  String get errSlotTaken =>
      'That time has just been taken. Here are some others.';

  @override
  String get errSlugUnavailable => 'That name is already in use.';

  @override
  String get errTableHasFutureReservations =>
      'This table has upcoming bookings. Move or cancel them first.';

  @override
  String get errTableNameTaken => 'You already have a table with that name.';

  @override
  String get errTableNotFound => 'We couldn\'t find that table.';

  @override
  String get errTooManyAttempts =>
      'Too many attempts. Please wait 15 minutes and try again — asking for a new code won\'t help until then.';

  @override
  String get errUnauthenticated => 'Please sign in and try again.';

  @override
  String get errUnprocessable =>
      'We couldn\'t process that. Please check and try again.';

  @override
  String get errValidationFailed => 'Some of the details aren\'t right yet.';

  @override
  String get errOffline =>
      'You\'re offline. We\'ll try again when you\'re back.';

  @override
  String get errUnknown => 'Something went wrong. Please try again.';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionDismiss => 'Dismiss';

  @override
  String errorReference(String requestId) {
    return 'Reference $requestId';
  }

  @override
  String get errTitleOffline => 'You\'re offline';

  @override
  String get errTitleNetwork => 'That took too long';

  @override
  String get errTitleAuth => 'You need an account for that';

  @override
  String get errTitleConflict => 'Something just changed';

  @override
  String get errTitleValidation => 'Check that again';

  @override
  String get errTitleServer => 'SAHRA is having a moment';

  @override
  String get errTitleUnknown => 'Something went wrong';

  @override
  String get appTitle => 'SAHRA';

  @override
  String get searchHint => 'Search';

  @override
  String get searchLocation => 'CAIRO';

  @override
  String get searchFilterTonight => 'Tonight';

  @override
  String searchOpenTonight(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places open tonight',
      one: '1 place open tonight',
      zero: 'Nothing open tonight',
    );
    return '$_temp0';
  }

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places',
      one: '1 place',
      zero: 'No places',
    );
    return '$_temp0';
  }

  @override
  String searchNextAvailable(String time) {
    return 'Next: $time';
  }

  @override
  String get searchStartTitle => 'Where are you eating tonight?';

  @override
  String get searchStartMessage =>
      'Search by name, cuisine or area — in Arabic, English, or however you type it.';

  @override
  String get searchEmptyTitle => 'Nothing matches that';

  @override
  String get searchEmptyMessage => 'Try a nearby area, or a different night.';

  @override
  String get searchEmptyAction => 'Start over';

  @override
  String get searchOfflineTitle => 'You\'re offline';

  @override
  String get searchOfflineMessage =>
      'We can\'t reach SAHRA right now. Your connection came back before — it will again.';

  @override
  String get venueBack => 'Back';

  @override
  String get venueShare => 'Share';

  @override
  String get venueSave => 'Save';

  @override
  String get venueSaved => 'Saved';

  @override
  String get venueBook => 'Book a table';

  @override
  String get venueBookingFrom => 'From';

  @override
  String get venueBookingFree => 'Free to book';

  @override
  String get venueOpenTonight => 'Open tonight';

  @override
  String get venueClosedToday => 'Closed today';

  @override
  String venueHoursRange(String opens, String closes) {
    return '$opens – $closes';
  }

  @override
  String get venueDirections => 'Get directions';

  @override
  String get venueCall => 'Call venue';

  @override
  String get venueNotFoundTitle => 'We lost that one';

  @override
  String get venueNotFoundMessage =>
      'This venue isn\'t taking bookings right now. Have a look at what else is open.';

  @override
  String get venueNotFoundAction => 'Back to search';

  @override
  String get amenityOutdoor => 'Outdoor seating';

  @override
  String get amenityShisha => 'Shisha';

  @override
  String get amenityNileView => 'Nile view';

  @override
  String get amenityValet => 'Valet parking';

  @override
  String get amenityFamilySection => 'Family section';

  @override
  String get amenityAlcoholFree => 'Alcohol-free';

  @override
  String get bookTitle => 'Book a table';

  @override
  String get bookDate => 'Date';

  @override
  String get bookParty => 'Party size';

  @override
  String get bookTime => 'Time';

  @override
  String get bookDecreaseParty => 'One fewer guest';

  @override
  String get bookIncreaseParty => 'One more guest';

  @override
  String get bookToday => 'Tonight';

  @override
  String bookConfirmFor(int party, String time) {
    return 'Confirm for $party at $time';
  }

  @override
  String get bookCancellationPolicy =>
      'Free cancellation up to 2 hours before.';

  @override
  String get bookNoSlotsTitle => 'No tables that night';

  @override
  String bookNoSlotsMessage(int party) {
    return 'Nothing free for $party on that date. Try another night, or a smaller table.';
  }

  @override
  String get bookClosedTitle => 'Closed that day';

  @override
  String get bookClosedMessage =>
      'This venue doesn\'t open on the date you picked.';

  @override
  String get bookHolding => 'Holding your table…';

  @override
  String get bookSlotTakenTitle => 'Just booked by someone else';

  @override
  String get bookSlotTakenMessage =>
      'That time went while you were choosing. These are still open.';

  @override
  String get bookHoldExpiredTitle => 'Your hold ran out';

  @override
  String get bookHoldExpiredMessage =>
      'We only hold a table for a few minutes. Pick a time again — it takes a moment.';

  @override
  String get bookPickAgain => 'Pick another time';

  @override
  String get confirmedOverline => 'Booking confirmed';

  @override
  String confirmedMessage(String venue) {
    return 'We told $venue you\'re coming.';
  }

  @override
  String get confirmedDate => 'Date';

  @override
  String get confirmedTime => 'Time';

  @override
  String get confirmedGuests => 'Guests';

  @override
  String get confirmedReference => 'Confirmation';

  @override
  String get confirmedDone => 'Done';

  @override
  String get loadingLabel => 'Loading';

  @override
  String get cuisineLevantine => 'Levantine';

  @override
  String get cuisineEgyptian => 'Egyptian';

  @override
  String get cuisineMediterranean => 'Mediterranean';

  @override
  String get cuisineLebanese => 'Lebanese';

  @override
  String get cuisineJapanese => 'Japanese';

  @override
  String get cuisineSushi => 'Sushi';

  @override
  String get cuisineStreetFood => 'Street food';

  @override
  String get cuisineCafe => 'Cafe';

  @override
  String get signInTitle => 'Sign in to book';

  @override
  String get signInWhy =>
      'We hold your table under your name, and tell you if anything changes.';

  @override
  String get signInPhoneLabel => 'Phone number';

  @override
  String get signInPhoneHint => '01x xxx xxxx';

  @override
  String get signInNameLabel => 'Your name';

  @override
  String get signInNameHint => 'So the restaurant knows who to expect';

  @override
  String get signInContinue => 'Send me a code';

  @override
  String get signInSending => 'Sending…';

  @override
  String get signInCodeTitle => 'Enter the code';

  @override
  String signInCodeSentTo(String phone) {
    return 'We sent a 6-digit code to $phone.';
  }

  @override
  String get signInCodeLabel => '6-digit code';

  @override
  String get signInVerify => 'Verify';

  @override
  String get signInVerifying => 'Checking…';

  @override
  String get signInResend => 'Send another code';

  @override
  String get signInResending => 'Sending…';

  @override
  String get signInChangePhone => 'Use a different number';

  @override
  String signInDevHint(String marker) {
    return 'The code is not sent by SMS yet. Look in the API console for the $marker banner.';
  }

  @override
  String signInSlotHeld(String venue, String date, String time, int party) {
    String _temp0 = intl.Intl.pluralLogic(
      party,
      locale: localeName,
      other: '# guests',
      one: '1 guest',
    );
    return 'Your table: $venue, $date at $time, $_temp0';
  }

  @override
  String get signInSlotNote =>
      'We\'ll finish this booking as soon as you\'re in.';

  @override
  String get signInCancel => 'Not now';

  @override
  String get bookingsTitle => 'My bookings';

  @override
  String get bookingsUpcoming => 'Upcoming';

  @override
  String get bookingsPast => 'Past';

  @override
  String get bookingsEmptyUpcomingTitle => 'Nothing booked yet';

  @override
  String get bookingsEmptyUpcomingMessage =>
      'When you book a table it will be here, with everything you need at the door.';

  @override
  String get bookingsEmptyUpcomingAction => 'Find somewhere';

  @override
  String get bookingsEmptyPastTitle => 'No visits yet';

  @override
  String get bookingsEmptyPastMessage =>
      'Tables you have been to will be kept here.';

  @override
  String get bookingsSignedOutTitle => 'Sign in to see your bookings';

  @override
  String get bookingsSignedOutMessage =>
      'Your reservations are kept under your phone number.';

  @override
  String get bookingsSignedOutAction => 'Sign in';

  @override
  String get bookingsCancelledByVenue => 'The restaurant cancelled';

  @override
  String get bookingsCancelledByYou => 'You cancelled';

  @override
  String bookingsPartyOf(int party) {
    return 'Table for $party';
  }

  @override
  String get bookingsAcknowledge => 'Got it';

  @override
  String get reservationTitle => 'Your booking';

  @override
  String get reservationReference => 'Confirmation';

  @override
  String get reservationWhen => 'When';

  @override
  String get reservationParty => 'Party';

  @override
  String get reservationStatus => 'Status';

  @override
  String get reservationSpecialRequests => 'You asked for';

  @override
  String get reservationOccasion => 'Occasion';

  @override
  String get reservationModify => 'Change time or party';

  @override
  String get reservationCancel => 'Cancel booking';

  @override
  String get reservationNotYetAvailable =>
      'Not available yet — call the restaurant to change or cancel.';

  @override
  String get reservationVenuePhone => 'Call the restaurant';

  @override
  String reservationCancelledNotice(String venue, String reason) {
    return '$venue cancelled this booking: $reason';
  }

  @override
  String get reservationNotFoundTitle => 'We lost that booking';

  @override
  String get reservationNotFoundMessage =>
      'It may have been cancelled, or it belongs to another account.';

  @override
  String get statusPending => 'Awaiting confirmation';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusSeated => 'Seated';

  @override
  String get statusCompleted => 'Visited';

  @override
  String get statusNoShow => 'Missed';

  @override
  String get statusCancelledByUser => 'Cancelled by you';

  @override
  String get statusCancelledByRestaurant => 'Cancelled by the restaurant';

  @override
  String get signOut => 'Sign out';

  @override
  String get tabDiscover => 'Discover';

  @override
  String get tabBookings => 'Bookings';

  @override
  String get tabAccount => 'Account';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSignedOutTitle => 'You\'re browsing as a guest';

  @override
  String get accountSignedOutMessage =>
      'Sign in to book a table and keep your reservations in one place.';

  @override
  String get accountMyBookings => 'My bookings';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSigningOut => 'Signing out…';

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountLanguageValue => 'Follows your device';

  @override
  String get accountNotBuilt =>
      'Saved places, payment methods and notification settings are not built yet.';

  @override
  String searchLocationSemantic(String city) {
    return 'Searching in $city';
  }

  @override
  String bookGuestsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'guests',
      one: 'guest',
    );
    return '$_temp0';
  }

  @override
  String get signInNameTitle => 'What should we call you?';

  @override
  String get signInNameWhy =>
      'The restaurant needs a name for the table. Nothing else is needed.';

  @override
  String get signInNameSubmit => 'Finish';

  @override
  String get signInNameSubmitting => 'Finishing…';

  @override
  String signInNoCodeHelp(String contact) {
    return 'Code not arriving? Contact us: $contact';
  }
}
