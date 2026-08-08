import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @errAccountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This account can\'t be used right now. Please contact support.'**
  String get errAccountUnavailable;

  /// No description provided for @errBadRequest.
  ///
  /// In en, this message translates to:
  /// **'Something about that request wasn\'t right. Please try again.'**
  String get errBadRequest;

  /// No description provided for @errBookingsOutsideNewHours.
  ///
  /// In en, this message translates to:
  /// **'Some confirmed bookings fall outside these hours.'**
  String get errBookingsOutsideNewHours;

  /// No description provided for @errCapacityConflictWithReservations.
  ///
  /// In en, this message translates to:
  /// **'Upcoming bookings on this table no longer fit the new capacity.'**
  String get errCapacityConflictWithReservations;

  /// No description provided for @errConflict.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t match the current state. Please refresh and try again.'**
  String get errConflict;

  /// No description provided for @errDuplicateRequest.
  ///
  /// In en, this message translates to:
  /// **'That request was already sent.'**
  String get errDuplicateRequest;

  /// No description provided for @errForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that.'**
  String get errForbidden;

  /// No description provided for @errForbiddenRole.
  ///
  /// In en, this message translates to:
  /// **'Your role doesn\'t allow that.'**
  String get errForbiddenRole;

  /// No description provided for @errHoldExpired.
  ///
  /// In en, this message translates to:
  /// **'Your hold expired. Pick a time again — it only takes a moment.'**
  String get errHoldExpired;

  /// No description provided for @errInternalError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Please try again.'**
  String get errInternalError;

  /// No description provided for @errInvalidAvailabilityFilter.
  ///
  /// In en, this message translates to:
  /// **'Choose a date and a party size together.'**
  String get errInvalidAvailabilityFilter;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'That phone number or password didn\'t match.'**
  String get errInvalidCredentials;

  /// No description provided for @errInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'That date doesn\'t look right.'**
  String get errInvalidDate;

  /// No description provided for @errInvalidIdempotencyKey.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong sending that. Please try again.'**
  String get errInvalidIdempotencyKey;

  /// No description provided for @errInvalidOtp.
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t right. Check it and try again.'**
  String get errInvalidOtp;

  /// No description provided for @errInvalidPartySize.
  ///
  /// In en, this message translates to:
  /// **'Choose a party size between 1 and 50.'**
  String get errInvalidPartySize;

  /// No description provided for @errInvalidQueryParam.
  ///
  /// In en, this message translates to:
  /// **'One of those filters isn\'t valid.'**
  String get errInvalidQueryParam;

  /// No description provided for @errInvalidSort.
  ///
  /// In en, this message translates to:
  /// **'That sort option isn\'t available.'**
  String get errInvalidSort;

  /// No description provided for @errInvalidStatusTransition.
  ///
  /// In en, this message translates to:
  /// **'That booking has already moved on. Refresh to see where it stands.'**
  String get errInvalidStatusTransition;

  /// No description provided for @errImageNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that photo.'**
  String get errImageNotFound;

  /// No description provided for @errImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That photo is too large. Keep it under 12 MB.'**
  String get errImageTooLarge;

  /// No description provided for @errInvalidImage.
  ///
  /// In en, this message translates to:
  /// **'That file couldn\'t be read as a photo.'**
  String get errInvalidImage;

  /// No description provided for @errStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t store that photo. Please try again.'**
  String get errStorageUnavailable;

  /// No description provided for @errUnsupportedImageType.
  ///
  /// In en, this message translates to:
  /// **'Use a JPEG, PNG or WebP photo.'**
  String get errUnsupportedImageType;

  /// No description provided for @errMissingIdempotencyKey.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong sending that. Please try again.'**
  String get errMissingIdempotencyKey;

  /// No description provided for @errNotAnOwner.
  ///
  /// In en, this message translates to:
  /// **'This account isn\'t registered as a restaurant owner.'**
  String get errNotAnOwner;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that.'**
  String get errNotFound;

  /// No description provided for @errOtpExpired.
  ///
  /// In en, this message translates to:
  /// **'That code has expired. Ask for a new one.'**
  String get errOtpExpired;

  /// No description provided for @errOtpRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You\'ve asked for a few codes already. Try again in a few minutes.'**
  String get errOtpRateLimited;

  /// No description provided for @errOtpSendingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We can\'t send codes right now. Please try again shortly.'**
  String get errOtpSendingUnavailable;

  /// No description provided for @errPacingLimitReached.
  ///
  /// In en, this message translates to:
  /// **'The kitchen is at capacity for that time. Try a slot nearby.'**
  String get errPacingLimitReached;

  /// No description provided for @errPayloadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is too large.'**
  String get errPayloadTooLarge;

  /// No description provided for @errRateLimited.
  ///
  /// In en, this message translates to:
  /// **'That\'s a lot of requests. Give it a moment.'**
  String get errRateLimited;

  /// No description provided for @errReservationNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that booking.'**
  String get errReservationNotFound;

  /// No description provided for @errReservationNotModifiable.
  ///
  /// In en, this message translates to:
  /// **'That booking has already started, so it can\'t be changed. You can still cancel it.'**
  String get errReservationNotModifiable;

  /// No description provided for @errRestaurantNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that restaurant.'**
  String get errRestaurantNotFound;

  /// No description provided for @errSearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Search is having a moment. Please try again.'**
  String get errSearchUnavailable;

  /// No description provided for @errServiceBusy.
  ///
  /// In en, this message translates to:
  /// **'This restaurant is busy right now. Try again in a moment.'**
  String get errServiceBusy;

  /// No description provided for @errServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That service is briefly unavailable. Please try again.'**
  String get errServiceUnavailable;

  /// No description provided for @errShiftNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find those opening hours.'**
  String get errShiftNotFound;

  /// No description provided for @errShiftOverlap.
  ///
  /// In en, this message translates to:
  /// **'Those hours overlap a shift you already have.'**
  String get errShiftOverlap;

  /// No description provided for @errSlotTaken.
  ///
  /// In en, this message translates to:
  /// **'That time has just been taken. Here are some others.'**
  String get errSlotTaken;

  /// No description provided for @errSlugUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That name is already in use.'**
  String get errSlugUnavailable;

  /// No description provided for @errTableHasFutureReservations.
  ///
  /// In en, this message translates to:
  /// **'This table has upcoming bookings. Move or cancel them first.'**
  String get errTableHasFutureReservations;

  /// No description provided for @errTableNameTaken.
  ///
  /// In en, this message translates to:
  /// **'You already have a table with that name.'**
  String get errTableNameTaken;

  /// No description provided for @errTableNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that table.'**
  String get errTableNotFound;

  /// Shown after 5 wrong OTP codes, when verification is locked for 15 minutes (doc 11 flow 1). TWO THINGS THIS COPY MUST DO. (1) Say that WAITING is required: the original said 'ask for a new code', which is exactly what does not work during a lock — the diner burns their three sends against a shut door and then calls support. (2) Put the fault on the ATTEMPT, not the person. An earlier draft opened with 'wrong codes, too many of them', which Egyptian readers take as being told off at the moment they are already locked out. If LOCK_SECONDS changes in otp.service.ts, change this.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait 15 minutes and try again — asking for a new code won\'t help until then.'**
  String get errTooManyAttempts;

  /// No description provided for @errUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Please sign in and try again.'**
  String get errUnauthenticated;

  /// No description provided for @errUnprocessable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t process that. Please check and try again.'**
  String get errUnprocessable;

  /// No description provided for @errValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Some of the details aren\'t right yet.'**
  String get errValidationFailed;

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. We\'ll try again when you\'re back.'**
  String get errOffline;

  /// No description provided for @errUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errUnknown;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get actionDismiss;

  /// No description provided for @errorReference.
  ///
  /// In en, this message translates to:
  /// **'Reference {requestId}'**
  String errorReference(String requestId);

  /// Short HEADING for an error state; the code's own sentence is the body. One per sealed Failure member (ENGINEERING-STANDARDS §7), so failureTitle's switch is exhaustive at compile time.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get errTitleOffline;

  /// No description provided for @errTitleNetwork.
  ///
  /// In en, this message translates to:
  /// **'That took too long'**
  String get errTitleNetwork;

  /// No description provided for @errTitleAuth.
  ///
  /// In en, this message translates to:
  /// **'You need an account for that'**
  String get errTitleAuth;

  /// No description provided for @errTitleConflict.
  ///
  /// In en, this message translates to:
  /// **'Something just changed'**
  String get errTitleConflict;

  /// No description provided for @errTitleValidation.
  ///
  /// In en, this message translates to:
  /// **'Check that again'**
  String get errTitleValidation;

  /// No description provided for @errTitleServer.
  ///
  /// In en, this message translates to:
  /// **'SAHRA is having a moment'**
  String get errTitleServer;

  /// No description provided for @errTitleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errTitleUnknown;

  /// Brand name. Not translated — it is the same word.
  ///
  /// In en, this message translates to:
  /// **'SAHRA'**
  String get appTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// SearchScreen.jsx t.city — the city chip inside the search bar.
  ///
  /// In en, this message translates to:
  /// **'CAIRO'**
  String get searchLocation;

  /// SearchScreen.jsx t.chips[0]. The only chip wired to real behaviour: it filters by tonight's availability.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get searchFilterTonight;

  /// SearchScreen.jsx t.open, made dynamic.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing open tonight} =1{1 place open tonight} other{{count} places open tonight}}'**
  String searchOpenTonight(int count);

  /// No description provided for @searchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No places} =1{1 place} other{{count} places}}'**
  String searchResultCount(int count);

  /// SearchScreen.jsx t.next.
  ///
  /// In en, this message translates to:
  /// **'Next: {time}'**
  String searchNextAvailable(String time);

  /// No description provided for @searchStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you eating tonight?'**
  String get searchStartTitle;

  /// No description provided for @searchStartMessage.
  ///
  /// In en, this message translates to:
  /// **'Search by name, cuisine or area — in Arabic, English, or however you type it.'**
  String get searchStartMessage;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that'**
  String get searchEmptyTitle;

  /// 11-user-flows §2: 'nothing matches — try nearby areas' + suggested alternatives.
  ///
  /// In en, this message translates to:
  /// **'Try a nearby area, or a different night.'**
  String get searchEmptyMessage;

  /// No description provided for @searchEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get searchEmptyAction;

  /// No description provided for @searchOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get searchOfflineTitle;

  /// No description provided for @searchOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'We can\'t reach SAHRA right now. Your connection came back before — it will again.'**
  String get searchOfflineMessage;

  /// No description provided for @venueBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get venueBack;

  /// No description provided for @venueShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get venueShare;

  /// No description provided for @venueSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get venueSave;

  /// No description provided for @venueSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get venueSaved;

  /// No description provided for @venueBook.
  ///
  /// In en, this message translates to:
  /// **'Book a table'**
  String get venueBook;

  /// No description provided for @venueBookingFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get venueBookingFrom;

  /// VenueDetailScreen.jsx t.free — SAHRA charges the diner nothing.
  ///
  /// In en, this message translates to:
  /// **'Free to book'**
  String get venueBookingFree;

  /// No description provided for @venueOpenTonight.
  ///
  /// In en, this message translates to:
  /// **'Open tonight'**
  String get venueOpenTonight;

  /// No description provided for @venueClosedToday.
  ///
  /// In en, this message translates to:
  /// **'Closed today'**
  String get venueClosedToday;

  /// No description provided for @venueHoursRange.
  ///
  /// In en, this message translates to:
  /// **'{opens} – {closes}'**
  String venueHoursRange(String opens, String closes);

  /// No description provided for @venueDirections.
  ///
  /// In en, this message translates to:
  /// **'Get directions'**
  String get venueDirections;

  /// No description provided for @venueCall.
  ///
  /// In en, this message translates to:
  /// **'Call venue'**
  String get venueCall;

  /// No description provided for @venueNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'We lost that one'**
  String get venueNotFoundTitle;

  /// No description provided for @venueNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This venue isn\'t taking bookings right now. Have a look at what else is open.'**
  String get venueNotFoundMessage;

  /// No description provided for @venueNotFoundAction.
  ///
  /// In en, this message translates to:
  /// **'Back to search'**
  String get venueNotFoundAction;

  /// No description provided for @amenityOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor seating'**
  String get amenityOutdoor;

  /// No description provided for @amenityShisha.
  ///
  /// In en, this message translates to:
  /// **'Shisha'**
  String get amenityShisha;

  /// No description provided for @amenityNileView.
  ///
  /// In en, this message translates to:
  /// **'Nile view'**
  String get amenityNileView;

  /// No description provided for @amenityValet.
  ///
  /// In en, this message translates to:
  /// **'Valet parking'**
  String get amenityValet;

  /// No description provided for @amenityFamilySection.
  ///
  /// In en, this message translates to:
  /// **'Family section'**
  String get amenityFamilySection;

  /// No description provided for @amenityAlcoholFree.
  ///
  /// In en, this message translates to:
  /// **'Alcohol-free'**
  String get amenityAlcoholFree;

  /// No description provided for @bookTitle.
  ///
  /// In en, this message translates to:
  /// **'Book a table'**
  String get bookTitle;

  /// No description provided for @bookDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get bookDate;

  /// No description provided for @bookParty.
  ///
  /// In en, this message translates to:
  /// **'Party size'**
  String get bookParty;

  /// No description provided for @bookTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get bookTime;

  /// No description provided for @bookDecreaseParty.
  ///
  /// In en, this message translates to:
  /// **'One fewer guest'**
  String get bookDecreaseParty;

  /// No description provided for @bookIncreaseParty.
  ///
  /// In en, this message translates to:
  /// **'One more guest'**
  String get bookIncreaseParty;

  /// BookingFlowScreen.jsx t.days[0][0] — the label for today's chip.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get bookToday;

  /// BookingFlowScreen.jsx t.confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm for {party} at {time}'**
  String bookConfirmFor(int party, String time);

  /// No description provided for @bookCancellationPolicy.
  ///
  /// In en, this message translates to:
  /// **'Free cancellation up to 2 hours before.'**
  String get bookCancellationPolicy;

  /// No description provided for @bookNoSlotsTitle.
  ///
  /// In en, this message translates to:
  /// **'No tables that night'**
  String get bookNoSlotsTitle;

  /// No description provided for @bookNoSlotsMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing free for {party} on that date. Try another night, or a smaller table.'**
  String bookNoSlotsMessage(int party);

  /// No description provided for @bookClosedTitle.
  ///
  /// In en, this message translates to:
  /// **'Closed that day'**
  String get bookClosedTitle;

  /// No description provided for @bookClosedMessage.
  ///
  /// In en, this message translates to:
  /// **'This venue doesn\'t open on the date you picked.'**
  String get bookClosedMessage;

  /// No description provided for @bookHolding.
  ///
  /// In en, this message translates to:
  /// **'Holding your table…'**
  String get bookHolding;

  /// 11-user-flows §3, node M. The slot went between seeing it and confirming it — the one thing the type system cannot prevent.
  ///
  /// In en, this message translates to:
  /// **'Just booked by someone else'**
  String get bookSlotTakenTitle;

  /// No description provided for @bookSlotTakenMessage.
  ///
  /// In en, this message translates to:
  /// **'That time went while you were choosing. These are still open.'**
  String get bookSlotTakenMessage;

  /// No description provided for @bookHoldExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Your hold ran out'**
  String get bookHoldExpiredTitle;

  /// No description provided for @bookHoldExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'We only hold a table for a few minutes. Pick a time again — it takes a moment.'**
  String get bookHoldExpiredMessage;

  /// No description provided for @bookPickAgain.
  ///
  /// In en, this message translates to:
  /// **'Pick another time'**
  String get bookPickAgain;

  /// No description provided for @confirmedOverline.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed'**
  String get confirmedOverline;

  /// ConfirmationScreen.jsx t.msg.
  ///
  /// In en, this message translates to:
  /// **'We told {venue} you\'re coming.'**
  String confirmedMessage(String venue);

  /// No description provided for @confirmedDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get confirmedDate;

  /// No description provided for @confirmedTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get confirmedTime;

  /// No description provided for @confirmedGuests.
  ///
  /// In en, this message translates to:
  /// **'Guests'**
  String get confirmedGuests;

  /// No description provided for @confirmedReference.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get confirmedReference;

  /// No description provided for @confirmedDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get confirmedDone;

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingLabel;

  /// Cuisine keys come from the API as enum-ish strings (levantine, street_food). Title-casing the key put English on the Arabic screen — found by looking at a golden. Unknown keys are skipped, not shown raw.
  ///
  /// In en, this message translates to:
  /// **'Levantine'**
  String get cuisineLevantine;

  /// No description provided for @cuisineEgyptian.
  ///
  /// In en, this message translates to:
  /// **'Egyptian'**
  String get cuisineEgyptian;

  /// No description provided for @cuisineMediterranean.
  ///
  /// In en, this message translates to:
  /// **'Mediterranean'**
  String get cuisineMediterranean;

  /// No description provided for @cuisineLebanese.
  ///
  /// In en, this message translates to:
  /// **'Lebanese'**
  String get cuisineLebanese;

  /// No description provided for @cuisineJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get cuisineJapanese;

  /// No description provided for @cuisineSushi.
  ///
  /// In en, this message translates to:
  /// **'Sushi'**
  String get cuisineSushi;

  /// No description provided for @cuisineStreetFood.
  ///
  /// In en, this message translates to:
  /// **'Street food'**
  String get cuisineStreetFood;

  /// No description provided for @cuisineCafe.
  ///
  /// In en, this message translates to:
  /// **'Cafe'**
  String get cuisineCafe;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to book'**
  String get signInTitle;

  /// C-1.6 asks the diner to sign up at the booking action. This is the ONE sentence that has to make thirty seconds feel worth it, so it states what they get — the table under their name, and being told if it changes — not what we need.
  ///
  /// In en, this message translates to:
  /// **'We hold your table under your name, and tell you if anything changes.'**
  String get signInWhy;

  /// No description provided for @signInPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get signInPhoneLabel;

  /// No description provided for @signInPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'01x xxx xxxx'**
  String get signInPhoneHint;

  /// No description provided for @signInNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get signInNameLabel;

  /// No description provided for @signInNameHint.
  ///
  /// In en, this message translates to:
  /// **'So the restaurant knows who to expect'**
  String get signInNameHint;

  /// No description provided for @signInContinue.
  ///
  /// In en, this message translates to:
  /// **'Send me a code'**
  String get signInContinue;

  /// No description provided for @signInSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get signInSending;

  /// No description provided for @signInCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get signInCodeTitle;

  /// No description provided for @signInCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}.'**
  String signInCodeSentTo(String phone);

  /// No description provided for @signInCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get signInCodeLabel;

  /// No description provided for @signInVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get signInVerify;

  /// No description provided for @signInVerifying.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get signInVerifying;

  /// No description provided for @signInResend.
  ///
  /// In en, this message translates to:
  /// **'Send another code'**
  String get signInResend;

  /// No description provided for @signInResending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get signInResending;

  /// No description provided for @signInChangePhone.
  ///
  /// In en, this message translates to:
  /// **'Use a different number'**
  String get signInChangePhone;

  /// DEV BUILDS ONLY — gated by showsOtpDevHint(), false in any release build regardless of dart-defines. The banner name is a PLACEHOLDER so the screen can wrap it in a bidi isolate: as part of the sentence, "OTP CODE" broke across a line in Arabic with the full stop landing before CODE. Found by looking at the walk-through screenshot, not by any assertion.
  ///
  /// In en, this message translates to:
  /// **'The code is not sent by SMS yet. Look in the API console for the {marker} banner.'**
  String signInDevHint(String marker);

  /// The party size is a PLURAL WITH ITS OWN {party} PLACEHOLDER INSIDE THIS MESSAGE, not a separately-formatted word passed in. It used to take `bookGuests`, which is `{count, plural, =1{guest} other{guests}}` — a noun selector with no number in it — and the screen rendered "…at 18:00, guests". The value was present and correct the whole time; the string it was handed had nowhere to put it.
  ///
  /// In en, this message translates to:
  /// **'Your table: {venue}, {date} at {time}, {party, plural, =1{1 guest} other{{party} guests}}'**
  String signInSlotHeld(String venue, String date, String time, int party);

  /// No description provided for @signInSlotNote.
  ///
  /// In en, this message translates to:
  /// **'We\'ll finish this booking as soon as you\'re in.'**
  String get signInSlotNote;

  /// No description provided for @signInCancel.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get signInCancel;

  /// No description provided for @bookingsTitle.
  ///
  /// In en, this message translates to:
  /// **'My bookings'**
  String get bookingsTitle;

  /// No description provided for @bookingsUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get bookingsUpcoming;

  /// No description provided for @bookingsPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get bookingsPast;

  /// No description provided for @bookingsEmptyUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing booked yet'**
  String get bookingsEmptyUpcomingTitle;

  /// No description provided for @bookingsEmptyUpcomingMessage.
  ///
  /// In en, this message translates to:
  /// **'When you book a table it will be here, with everything you need at the door.'**
  String get bookingsEmptyUpcomingMessage;

  /// No description provided for @bookingsEmptyUpcomingAction.
  ///
  /// In en, this message translates to:
  /// **'Find somewhere'**
  String get bookingsEmptyUpcomingAction;

  /// No description provided for @bookingsEmptyPastTitle.
  ///
  /// In en, this message translates to:
  /// **'No visits yet'**
  String get bookingsEmptyPastTitle;

  /// No description provided for @bookingsEmptyPastMessage.
  ///
  /// In en, this message translates to:
  /// **'Tables you have been to will be kept here.'**
  String get bookingsEmptyPastMessage;

  /// No description provided for @bookingsSignedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your bookings'**
  String get bookingsSignedOutTitle;

  /// No description provided for @bookingsSignedOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Your reservations are kept under your phone number.'**
  String get bookingsSignedOutMessage;

  /// No description provided for @bookingsSignedOutAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get bookingsSignedOutAction;

  /// No description provided for @bookingsCancelledByVenue.
  ///
  /// In en, this message translates to:
  /// **'The restaurant cancelled'**
  String get bookingsCancelledByVenue;

  /// No description provided for @bookingsCancelledByYou.
  ///
  /// In en, this message translates to:
  /// **'You cancelled'**
  String get bookingsCancelledByYou;

  /// No description provided for @bookingsPartyOf.
  ///
  /// In en, this message translates to:
  /// **'Table for {party}'**
  String bookingsPartyOf(int party);

  /// No description provided for @bookingsAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get bookingsAcknowledge;

  /// No description provided for @reservationTitle.
  ///
  /// In en, this message translates to:
  /// **'Your booking'**
  String get reservationTitle;

  /// No description provided for @reservationReference.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get reservationReference;

  /// No description provided for @reservationWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get reservationWhen;

  /// No description provided for @reservationParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get reservationParty;

  /// No description provided for @reservationStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get reservationStatus;

  /// No description provided for @reservationSpecialRequests.
  ///
  /// In en, this message translates to:
  /// **'You asked for'**
  String get reservationSpecialRequests;

  /// No description provided for @reservationOccasion.
  ///
  /// In en, this message translates to:
  /// **'Occasion'**
  String get reservationOccasion;

  /// No description provided for @reservationModify.
  ///
  /// In en, this message translates to:
  /// **'Change time or party'**
  String get reservationModify;

  /// No description provided for @reservationCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get reservationCancel;

  /// No description provided for @reservationCallInstead.
  ///
  /// In en, this message translates to:
  /// **'Something else to change? Call the restaurant.'**
  String get reservationCallInstead;

  /// No description provided for @cancelSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this booking?'**
  String get cancelSheetTitle;

  /// No description provided for @cancelSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Your table goes back to the restaurant and someone else can take it. You can\'t undo this.'**
  String get cancelSheetBody;

  /// No description provided for @cancelSheetReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get cancelSheetReasonLabel;

  /// No description provided for @cancelSheetReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Anything you\'d like the restaurant to know'**
  String get cancelSheetReasonHint;

  /// No description provided for @cancelSheetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get cancelSheetConfirm;

  /// No description provided for @cancelSheetWorking.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get cancelSheetWorking;

  /// No description provided for @cancelSheetKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep my booking'**
  String get cancelSheetKeep;

  /// No description provided for @moveSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Change your booking'**
  String get moveSheetTitle;

  /// No description provided for @moveSheetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get moveSheetConfirm;

  /// No description provided for @moveSheetWorking.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get moveSheetWorking;

  /// No description provided for @accountEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get accountEditName;

  /// No description provided for @accountEditNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get accountEditNameTitle;

  /// No description provided for @accountEditNameWhy.
  ///
  /// In en, this message translates to:
  /// **'This is the name the restaurant looks for at the door.'**
  String get accountEditNameWhy;

  /// No description provided for @accountEditNameSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get accountEditNameSave;

  /// No description provided for @accountEditNameSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get accountEditNameSaving;

  /// No description provided for @reservationVenuePhone.
  ///
  /// In en, this message translates to:
  /// **'Call the restaurant'**
  String get reservationVenuePhone;

  /// No description provided for @reservationCancelledNotice.
  ///
  /// In en, this message translates to:
  /// **'{venue} cancelled this booking: {reason}'**
  String reservationCancelledNotice(String venue, String reason);

  /// No description provided for @reservationNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'We lost that booking'**
  String get reservationNotFoundTitle;

  /// No description provided for @reservationNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'It may have been cancelled, or it belongs to another account.'**
  String get reservationNotFoundMessage;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusSeated.
  ///
  /// In en, this message translates to:
  /// **'Seated'**
  String get statusSeated;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get statusCompleted;

  /// No description provided for @statusNoShow.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statusNoShow;

  /// No description provided for @statusCancelledByUser.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by you'**
  String get statusCancelledByUser;

  /// No description provided for @statusCancelledByRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by the restaurant'**
  String get statusCancelledByRestaurant;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @tabDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get tabDiscover;

  /// No description provided for @tabBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get tabBookings;

  /// No description provided for @tabAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tabAccount;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountSignedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re browsing as a guest'**
  String get accountSignedOutTitle;

  /// No description provided for @accountSignedOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to book a table and keep your reservations in one place.'**
  String get accountSignedOutMessage;

  /// No description provided for @accountMyBookings.
  ///
  /// In en, this message translates to:
  /// **'My bookings'**
  String get accountMyBookings;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get accountSigningOut;

  /// No description provided for @accountLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountLanguage;

  /// No description provided for @accountLanguageValue.
  ///
  /// In en, this message translates to:
  /// **'Follows your device'**
  String get accountLanguageValue;

  /// ProfileScreen.jsx draws seven rows; three of them have no implementation. Naming them is more honest than drawing rows that fail on tap.
  ///
  /// In en, this message translates to:
  /// **'Saved places, payment methods and notification settings are not built yet.'**
  String get accountNotBuilt;

  /// Announced for the city label in the search pill. It is NOT a control — city switching is not built (SEARCH-1) — so the announcement states scope rather than offering an action.
  ///
  /// In en, this message translates to:
  /// **'Searching in {city}'**
  String searchLocationSemantic(String city);

  /// THE NOUN ONLY — "guest"/"guests" — with NO number. Correct for SahraPartyStepper, which draws the figure itself in display type and takes the unit beside it. It is NOT a sentence fragment: dropping it into prose loses the count silently, which is exactly what happened on the sign-in screen. Any sentence needs its own plural interpolating {count} by name — NOT `#`, which gen-l10n emits literally.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{guest} other{guests}}'**
  String bookGuestsUnit(int count);

  /// No description provided for @signInNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get signInNameTitle;

  /// The name step is reached only after a correct code, so the number is already proved. This sentence has to justify one more field to somebody who thought they had finished — hence 'nothing else is needed', which is also true.
  ///
  /// In en, this message translates to:
  /// **'The restaurant needs a name for the table. Nothing else is needed.'**
  String get signInNameWhy;

  /// No description provided for @signInNameSubmit.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get signInNameSubmit;

  /// No description provided for @signInNameSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Finishing…'**
  String get signInNameSubmitting;

  /// UNCONDITIONAL on the code step, in both locales. Not gated on the delivery stub and not gated on a failure: a code that does not arrive is the one situation where a diner has no way forward, and the lockout design assumes a human can be reached (see the decision doc). The contact itself is a PLACEHOLDER that FAILS THE BUILD until a real one is supplied — see support_contact.dart and support_contact_test.dart. The ADDRESS ITSELF is no longer interpolated here: it is a separate tappable widget, because making the whole sentence a link would give the link the sentence as its accessible name.
  ///
  /// In en, this message translates to:
  /// **'Code not arriving? Contact us:'**
  String get signInNoCodeHelp;

  /// No description provided for @signInEmailSupport.
  ///
  /// In en, this message translates to:
  /// **'Email SAHRA support'**
  String get signInEmailSupport;

  /// No description provided for @contactCannotOpen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open an app for this — copy it instead.'**
  String get contactCannotOpen;

  /// No description provided for @reservationCallVenue.
  ///
  /// In en, this message translates to:
  /// **'Call the restaurant'**
  String get reservationCallVenue;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
