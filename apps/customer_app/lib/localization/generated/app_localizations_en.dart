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
  String get errAlreadyOnWaitlist =>
      'You\'re already on the list for that night.';

  @override
  String get errWaitlistEntryNotFound =>
      'We could not find that waitlist request.';

  @override
  String get errReviewAlreadyExists => 'You\'ve already reviewed this visit.';

  @override
  String get errReviewNotEligible => 'Reviews are for visits that happened.';

  @override
  String get errReviewTooEarly =>
      'You can review this once your table time is over.';

  @override
  String get errReviewNotFound => 'We could not find that review.';

  @override
  String get errCannotReportOwnReview => 'That\'s your own review.';

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
  String get errImageNotFound => 'We couldn\'t find that photo.';

  @override
  String get errImageTooLarge =>
      'That photo is too large. Keep it under 12 MB.';

  @override
  String get errInvalidImage => 'That file couldn\'t be read as a photo.';

  @override
  String get errStorageUnavailable =>
      'We couldn\'t store that photo. Please try again.';

  @override
  String get errUnsupportedImageType => 'Use a JPEG, PNG or WebP photo.';

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
  String get errOtpSendingUnavailable =>
      'We can\'t send codes right now. Please try again shortly.';

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
  String get errReservationNotModifiable =>
      'That booking has already started, so it can\'t be changed. You can still cancel it.';

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
      other: '$party guests',
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
  String get reservationCallInstead =>
      'Something else to change? Call the restaurant.';

  @override
  String get cancelSheetTitle => 'Cancel this booking?';

  @override
  String get cancelSheetBody =>
      'Your table goes back to the restaurant and someone else can take it. You can\'t undo this.';

  @override
  String get cancelSheetReasonLabel => 'Reason (optional)';

  @override
  String get cancelSheetReasonHint =>
      'Anything you\'d like the restaurant to know';

  @override
  String get cancelSheetConfirm => 'Cancel booking';

  @override
  String get cancelSheetWorking => 'Cancelling…';

  @override
  String get cancelSheetKeep => 'Keep my booking';

  @override
  String get moveSheetTitle => 'Change your booking';

  @override
  String get moveSheetConfirm => 'Save changes';

  @override
  String get moveSheetWorking => 'Saving…';

  @override
  String get accountEditName => 'Edit name';

  @override
  String get accountEditNameTitle => 'Your name';

  @override
  String get accountEditNameWhy =>
      'This is the name the restaurant looks for at the door.';

  @override
  String get accountEditNameSave => 'Save';

  @override
  String get accountEditNameSaving => 'Saving…';

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
  String get savedTitle => 'Saved';

  @override
  String discoverGreeting(String name) {
    return 'Good evening, $name';
  }

  @override
  String get discoverGreetingAnonymous => 'Good evening';

  @override
  String get discoverCity => 'Cairo';

  @override
  String get discoverTonight => 'Available tonight';

  @override
  String get onboardKicker1 => 'Cairo, tonight';

  @override
  String get onboardTitle1 => 'Find the vibe for tonight';

  @override
  String get onboardBody1 =>
      'Rooftops, late-night kitchens, live oud — the city\'s best tables, in one place.';

  @override
  String get onboardKicker2 => 'No phone calls';

  @override
  String get onboardTitle2 => 'Book a table in seconds';

  @override
  String get onboardBody2 =>
      'Real-time availability. Pick a time, we\'ll tell them you\'re coming.';

  @override
  String get onboardKicker3 => 'For every occasion';

  @override
  String get onboardTitle3 => 'From iftar to date night';

  @override
  String get onboardBody3 =>
      'Curated for Ramadan, birthdays, or just a Tuesday that deserves better.';

  @override
  String get onboardNext => 'Next';

  @override
  String onboardSlideOf(int index, int total) {
    return 'Slide $index of $total';
  }

  @override
  String get onboardStart => 'Get started';

  @override
  String get onboardHaveAccount => 'Already with us?';

  @override
  String get onboardSignIn => 'Sign in';

  @override
  String get filterTitle => 'Filters';

  @override
  String get filterCuisine => 'Cuisine';

  @override
  String get filterPrice => 'Price';

  @override
  String get filterRating => 'Rating';

  @override
  String get filterAmenities => 'Good for';

  @override
  String get filterApply => 'Show results';

  @override
  String get filterClear => 'Clear all';

  @override
  String filterRatingPlus(String rating) {
    return '$rating+';
  }

  @override
  String get filterOpen => 'Filters';

  @override
  String filterOpenWithCount(int count) {
    return 'Filters ($count)';
  }

  @override
  String get discoverSeeAll => 'See all';

  @override
  String get discoverNothingTonightTitle => 'Nothing free tonight';

  @override
  String get discoverNothingTonightMessage =>
      'Every table we can see is taken. Try another night.';

  @override
  String get discoverNothingTonightAction => 'Search';

  @override
  String get tabDiscoverHome => 'Discover';

  @override
  String get savedFailed =>
      'That did not save. Check your connection and try again.';

  @override
  String get savedEmptyTitle => 'Nothing saved yet';

  @override
  String get savedEmptyMessage =>
      'Tap the heart on a place you like and it will wait for you here.';

  @override
  String get savedEmptyAction => 'Find somewhere';

  @override
  String get savedSignedOutTitle => 'Sign in to see your saved places';

  @override
  String get savedSignedOutMessage => 'Your list follows you between phones.';

  @override
  String savedRemoveLabel(String venue) {
    return 'Remove $venue from saved';
  }

  @override
  String savedAddLabel(String venue) {
    return 'Save $venue';
  }

  @override
  String get accountSavedPlaces => 'Saved places';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSigningOut => 'Signing out…';

  @override
  String get accountLanguage => 'Language';

  @override
  String get languageFollowDevice => 'Follows your device';

  @override
  String get accountLanguageValue => 'Follows your device';

  @override
  String get accountNotBuilt =>
      'Invite friends, payment methods, help & support and per-type notification settings are not built yet.';

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
  String get signInNoCodeHelp => 'Code not arriving? Contact us:';

  @override
  String get signInEmailSupport => 'Email SAHRA support';

  @override
  String get contactCannotOpen =>
      'Couldn\'t open an app for this — copy it instead.';

  @override
  String get reservationCallVenue => 'Call the restaurant';

  @override
  String get venueMenuTitle => 'From the menu';

  @override
  String get venueMenuFull => 'Full menu';

  @override
  String get menuSheetTitle => 'Menu';

  @override
  String get menuEmptyTitle => 'No menu here yet';

  @override
  String get menuEmptyMessage =>
      'This restaurant hasn\'t shared its menu with us. Call them and they\'ll tell you what\'s good tonight.';

  @override
  String get menuPdfOpen => 'Open the menu';

  @override
  String get menuPdfNote =>
      'This venue\'s menu is a document. It opens outside the app.';

  @override
  String menuItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dishes',
      one: '1 dish',
    );
    return '$_temp0';
  }

  @override
  String menuPrice(String price, String currency) {
    return '$price $currency';
  }

  @override
  String get currencyEgp => 'EGP';

  @override
  String get dietVegetarian => 'Vegetarian';

  @override
  String get dietVegan => 'Vegan';

  @override
  String get dietGlutenFree => 'Gluten free';

  @override
  String get dietNutFree => 'Nut free';

  @override
  String get dietDairyFree => 'Dairy free';

  @override
  String get dietShellfish => 'Shellfish';

  @override
  String get dietSpicy => 'Spicy';

  @override
  String get dietContainsAlcohol => 'Contains alcohol';

  @override
  String get dietContainsPork => 'Contains pork';

  @override
  String get venueReviewsTitle => 'Reviews';

  @override
  String get venueReviewsAll => 'All reviews';

  @override
  String get reviewsSheetTitle => 'Reviews';

  @override
  String get reviewsEmptyTitle => 'No reviews yet';

  @override
  String get reviewsEmptyMessage =>
      'Only diners who booked and turned up can review, so the first one takes a while.';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'No reviews',
    );
    return '$_temp0';
  }

  @override
  String get reviewsVerifiedNote =>
      'Every review here is from a diner who booked a table and came.';

  @override
  String get reviewOwnerReply => 'From the restaurant';

  @override
  String get reviewFood => 'Food';

  @override
  String get reviewService => 'Service';

  @override
  String get reviewAmbience => 'Ambience';

  @override
  String get reviewsShowMore => 'Show more';

  @override
  String reviewStarsLabel(String rating) {
    return '$rating out of 5';
  }

  @override
  String reviewBreakdownLabel(int stars, int count) {
    return '$stars stars: $count';
  }

  @override
  String get writeReviewCta => 'Write a review';

  @override
  String get writeReviewTitle => 'How was it?';

  @override
  String writeReviewVenue(String name, String date) {
    return '$name, $date';
  }

  @override
  String get writeReviewOverall => 'Overall';

  @override
  String get writeReviewDetail => 'More detail, if you like';

  @override
  String get writeReviewBodyLabel => 'Anything you\'d tell a friend?';

  @override
  String get writeReviewBodyHint =>
      'What you ate, where you sat, whether you\'d go back.';

  @override
  String get writeReviewSubmit => 'Post review';

  @override
  String get writeReviewSubmitting => 'Posting…';

  @override
  String get writeReviewPosted => 'Posted. Thank you.';

  @override
  String writeReviewStar(int n) {
    return '$n of 5 stars';
  }

  @override
  String get writeReviewNeedsRating => 'Pick a rating first.';

  @override
  String get reviewAlreadyWritten => 'You reviewed this visit';

  @override
  String get reviewPublicNote =>
      'Your first name and the initial of your surname will be shown.';

  @override
  String venueGalleryLabel(int index, int total) {
    return 'Photo $index of $total';
  }

  @override
  String get filterDistance => 'Distance';

  @override
  String get filterNearMe => 'Near me';

  @override
  String filterNearMeRadius(String km) {
    return 'Within $km km';
  }

  @override
  String get filterSort => 'Sort by';

  @override
  String get sortRelevance => 'Best match';

  @override
  String get sortRating => 'Highest rated';

  @override
  String get sortDistance => 'Nearest first';

  @override
  String get locationAsking => 'Finding you…';

  @override
  String get locationDenied =>
      'We can\'t sort by distance without your location.';

  @override
  String get locationDeniedForever =>
      'Location is off for SAHRA. Turn it on in your phone\'s settings to sort by distance.';

  @override
  String get locationServiceDisabled =>
      'Location is switched off on this phone.';

  @override
  String get locationUnavailable =>
      'We couldn\'t find you. Search a neighbourhood instead.';

  @override
  String resultDistance(String km) {
    return '$km km';
  }

  @override
  String get reviewReport => 'Report';

  @override
  String get reviewReportTitle => 'Report this review';

  @override
  String get reviewReportWhy => 'What\'s wrong with it?';

  @override
  String get reviewReportReasonSpam => 'Spam or an advert';

  @override
  String get reviewReportReasonAbusive => 'Abusive or offensive';

  @override
  String get reviewReportReasonNotMyVisit => 'This isn\'t my visit';

  @override
  String get reviewReportReasonWrongVenue => 'Wrong restaurant';

  @override
  String get reviewReportReasonOther => 'Something else';

  @override
  String get reviewReportNoteLabel => 'Anything to add?';

  @override
  String get reviewReportNoteHint =>
      'Optional. It goes to whoever reviews this.';

  @override
  String get reviewReportSubmit => 'Send report';

  @override
  String get reviewReportSubmitting => 'Sending…';

  @override
  String get reviewReportSent => 'Thank you. Someone will look at it.';

  @override
  String get reviewReportNoReasonYet => 'Pick a reason first.';

  @override
  String get reviewReportHonest =>
      'Reporting doesn\'t hide the review. A person reads it and decides.';

  @override
  String get reviewReportAlready => 'You\'ve already reported this one.';

  @override
  String get accountNotifications => 'Notifications';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmptyTitle => 'Nothing yet';

  @override
  String get notificationsEmptyMessage =>
      'When a restaurant changes something, or a table opens up, you\'ll find it here.';

  @override
  String get notificationsSignedOutTitle => 'Sign in to see your notifications';

  @override
  String get notificationsFailed => 'We couldn\'t load your notifications.';

  @override
  String notificationsUnreadBadge(int count) {
    return '$count new';
  }

  @override
  String get notificationsToday => 'Today';

  @override
  String get notificationsEarlier => 'Earlier';

  @override
  String notifCancelledTitle(String venue) {
    return '$venue cancelled your table';
  }

  @override
  String notifCancelledBody(String date, String time) {
    return '$date at $time';
  }

  @override
  String notifConfirmedTitle(String venue) {
    return 'Table booked at $venue';
  }

  @override
  String notifConfirmedBody(
      String date, String time, String party, String code) {
    return '$date at $time · $party people · $code';
  }

  @override
  String notifReminder24hTitle(String venue) {
    return 'Tomorrow at $venue';
  }

  @override
  String notifReminder24hBody(String time) {
    return 'At $time. Can\'t make it? Cancel so the table goes to someone else.';
  }

  @override
  String notifReminder2hTitle(String venue) {
    return 'In 2 hours at $venue';
  }

  @override
  String notifReminder2hBody(String time, String party, String code) {
    return 'At $time · $party people · $code';
  }

  @override
  String notifWaitlistOfferTitle(String venue) {
    return 'A table opened up at $venue';
  }

  @override
  String notifWaitlistOfferBody(String date, String time) {
    return '$date at $time. Book now — it\'s first come, first served.';
  }

  @override
  String notifWaitlistExpiredTitle(String venue) {
    return 'That table went at $venue';
  }

  @override
  String notifWaitlistExpiredBody(String date) {
    return 'You\'re still on the list for $date.';
  }

  @override
  String get notifFallbackVenue => 'the restaurant';
}
