import 'package:flutter/material.dart';
import 'package:agenda_app/repositories/friendship_repository.dart';
import '../../core/utils/temporal_activity_utils.dart';
import '../../models/activity.dart';
import '../../models/availability.dart';
import '../../services/activity_clipboard_service.dart';
import '../../services/firestore/activity_firestore_service.dart';
import '../../services/firestore/availability_firestore_service.dart';
import '../../services/firestore/search_firestore_service.dart';
import '../03_activities/activity_detail_page.dart';
import '../03_activities/create_activity_page.dart';
import '../03_activities/search_activity_page.dart';
import '../03_activities/search_detail_page.dart';
import 'availability_detail_page.dart';
import 'note_slot_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

enum CalendarFilterType {
  none,
  created,
  joined,
  searches,
  availabilities,
  full,
  cancelled,
  done,
  ownerRequired,
  tonight,
  weekend,
}

class _CalendarPageState extends State<CalendarPage> {
  final ActivityFirestoreService activityService = ActivityFirestoreService();
  final AvailabilityFirestoreService availabilityService =
      AvailabilityFirestoreService();
  final SearchFirestoreService searchService = SearchFirestoreService();
  final FriendshipRepository _friendshipRepository = FriendshipRepository();

  List<String> _friendIds = [];

  final List<String> days = const [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  late final List<String> _timeSlots;

  CalendarFilterType _activeFilter = CalendarFilterType.none;
  CalendarFilterType? _timeFilter;
  bool _filterByFriends = false;
  bool _showAdvancedFilters = false;
  late DateTime _displayedWeekAnchor;

  bool get _hasActiveFilter =>
      _activeFilter != CalendarFilterType.none ||
      _timeFilter != null ||
      _filterByFriends;

  @override
  void initState() {
    super.initState();
    _timeSlots = generateTimeSlots();
    _displayedWeekAnchor = _normalizeDate(DateTime.now());
    _loadFriendIds();
  }

  Future<void> _loadFriendIds() async {
    try {
      final friendships = await _friendshipRepository.getAcceptedFriendships();
      if (!mounted) return;
      setState(() {
        _friendIds = friendships
            .map((f) => _friendshipRepository.getOtherUserId(f))
            .toList();
      });
    } catch (e) {
      debugPrint('CalendarPage: erreur chargement amis: $e');
    }
  }

  List<String> generateTimeSlots() {
    final List<String> slots = [];
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final hourStr = hour.toString().padLeft(2, '0');
        final minuteStr = minute.toString().padLeft(2, '0');
        slots.add('$hourStr:$minuteStr');
      }
    }
    return slots;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return hour * 60 + minute;
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _normalizeDate(date);
    final weekday = normalized.weekday;
    return normalized.subtract(Duration(days: weekday - 1));
  }

  DateTime _endOfWeek(DateTime date) {
    return _startOfWeek(date).add(const Duration(days: 6));
  }

  DateTime _startOfNextWeek(DateTime date) {
    return _startOfWeek(date).add(const Duration(days: 7));
  }

  DateTime _getDateForDay(String day) {
    final weekStart = _startOfWeek(_displayedWeekAnchor);
    final dayIndex = days.indexOf(day);

    if (dayIndex == -1) {
      return weekStart;
    }

    return DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + dayIndex,
    );
  }

  void _changeWeek(int delta) {
    setState(() {
      _displayedWeekAnchor = _displayedWeekAnchor.add(
        Duration(days: 7 * delta),
      );
    });
  }

  String _monthLabel(int month) {
    const months = [
      '',
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return months[month];
  }

  String _formatWeekRange() {
    final start = _startOfWeek(_displayedWeekAnchor);
    final end = _endOfWeek(_displayedWeekAnchor);

    if (start.month == end.month && start.year == end.year) {
      return 'Semaine du ${start.day} au ${end.day} ${_monthLabel(start.month)}';
    }

    if (start.year == end.year) {
      return 'Semaine du ${start.day} ${_monthLabel(start.month)} au ${end.day} ${_monthLabel(end.month)}';
    }

    return 'Semaine du ${start.day} ${_monthLabel(start.month)} ${start.year} au ${end.day} ${_monthLabel(end.month)} ${end.year}';
  }

  DateTime? _searchResolvedStartDateTime(Map<String, dynamic> search) {
    final value = search['startDateTime'];
    if (value is DateTime) return value;
    return null;
  }

  DateTime? _searchResolvedEndDateTime(Map<String, dynamic> search) {
    final value = search['endDateTime'];
    if (value is DateTime) return value;
    return null;
  }

  bool _isRangeIntersectingDisplayedWeek(DateTime? start, DateTime? end) {
    if (start == null) return false;

    final weekStart = _startOfWeek(_displayedWeekAnchor);
    final weekEndExclusive = _startOfNextWeek(_displayedWeekAnchor);
    final effectiveEnd = end ?? start;

    return start.isBefore(weekEndExclusive) && effectiveEnd.isAfter(weekStart);
  }

  List<Activity> _filterActivitiesForDisplayedWeek(List<Activity> activities) {
    return activities.where((activity) {
      return _isRangeIntersectingDisplayedWeek(
        activity.resolvedStartDateTime,
        activity.resolvedEndDateTime,
      );
    }).toList();
  }

  List<Availability> _filterAvailabilitiesForDisplayedWeek(
    List<Availability> availabilities,
  ) {
    return availabilities.where((availability) {
      return _isRangeIntersectingDisplayedWeek(
        availability.resolvedStartDateTime,
        availability.resolvedEndDateTime,
      );
    }).toList();
  }

  List<Map<String, dynamic>> _filterSearchesForDisplayedWeek(
    List<Map<String, dynamic>> searches,
  ) {
    return searches.where((search) {
      return _isRangeIntersectingDisplayedWeek(
        _searchResolvedStartDateTime(search),
        _searchResolvedEndDateTime(search),
      );
    }).toList();
  }

  Activity? getActivityForSlot(
    String day,
    String slotTime,
    List<Activity> activities,
  ) {
    final slotMinutes = timeToMinutes(slotTime);
    final slotDate = _getDateForDay(day);

    for (final activity in activities) {
      final activityStart = activity.resolvedStartDateTime;
      final activityEnd = activity.resolvedEndDateTime;

      if (activityStart == null || activityEnd == null) continue;

      final isOvernight = activityEnd.isAfter(
            DateTime(
              activityStart.year,
              activityStart.month,
              activityStart.day,
              23,
              59,
            ),
          ) &&
          !DateUtils.isSameDay(activityStart, activityEnd);

      if (DateUtils.isSameDay(activityStart, slotDate)) {
        final start = activityStart.hour * 60 + activityStart.minute;
        final end = isOvernight
            ? 24 * 60
            : (activityEnd.hour * 60 + activityEnd.minute);
        if (slotMinutes >= start && slotMinutes < end) return activity;
      }

      // Jour intermédiaire (multi-jours : ni début ni fin)
      final startDay = DateTime(
        activityStart.year, activityStart.month, activityStart.day,
      );
      final endDay = DateTime(
        activityEnd.year, activityEnd.month, activityEnd.day,
      );
      final slotDay = DateTime(
        slotDate.year, slotDate.month, slotDate.day,
      );
      if (isOvernight &&
          slotDay.isAfter(startDay) &&
          slotDay.isBefore(endDay)) {
        if (slotMinutes >= 0 && slotMinutes < 24 * 60) return activity;
      }

      if (isOvernight && DateUtils.isSameDay(activityEnd, slotDate)) {
        final end = activityEnd.hour * 60 + activityEnd.minute;
        if (slotMinutes < end) return activity;
      }
    }
    return null;
  }

  Availability? getAvailabilityForSlot(
    String day,
    String slotTime,
    List<Availability> availabilities,
  ) {
    final slotMinutes = timeToMinutes(slotTime);
    final slotDate = _getDateForDay(day);

    for (final availability in availabilities) {
      final availabilityStart = availability.resolvedStartDateTime;
      final availabilityEnd = availability.resolvedEndDateTime;

      if (availabilityStart == null || availabilityEnd == null) continue;
      if (!DateUtils.isSameDay(availabilityStart, slotDate)) continue;

      final start = availabilityStart.hour * 60 + availabilityStart.minute;
      final end = availabilityEnd.hour * 60 + availabilityEnd.minute;

      if (slotMinutes >= start && slotMinutes < end) {
        return availability;
      }
    }
    return null;
  }

  Map<String, dynamic>? getSearchForSlot(
    String day,
    String slotTime,
    List<Map<String, dynamic>> searches,
  ) {
    final slotMinutes = timeToMinutes(slotTime);
    final slotDate = _getDateForDay(day);

    for (final search in searches) {
      final startDateTime = _searchResolvedStartDateTime(search);
      final endDateTime = _searchResolvedEndDateTime(search);

      if (startDateTime == null || endDateTime == null) continue;
      if (!DateUtils.isSameDay(startDateTime, slotDate)) continue;

      final start = startDateTime.hour * 60 + startDateTime.minute;
      final end = endDateTime.hour * 60 + endDateTime.minute;

      if (slotMinutes >= start && slotMinutes < end) {
        return search;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> getSearchesForSlot(
    String day,
    String slotTime,
    List<Map<String, dynamic>> searches,
  ) {
    final slotMinutes = timeToMinutes(slotTime);
    final slotDate = _getDateForDay(day);
    final result = <Map<String, dynamic>>[];

    for (final search in searches) {
      final startDateTime = _searchResolvedStartDateTime(search);
      final endDateTime = _searchResolvedEndDateTime(search);

      if (startDateTime == null || endDateTime == null) continue;
      if (!DateUtils.isSameDay(startDateTime, slotDate)) continue;

      final start = startDateTime.hour * 60 + startDateTime.minute;
      final end = endDateTime.hour * 60 + endDateTime.minute;

      if (slotMinutes >= start && slotMinutes < end) {
        result.add(search);
      }
    }
    return result;
  }

  List<Activity> _deduplicateJoinedActivities(
    List<Activity> createdActivities,
    List<Activity> joinedActivities,
  ) {
    final createdIds = createdActivities.map((activity) => activity.id).toSet();

    return joinedActivities
        .where((activity) => !createdIds.contains(activity.id))
        .toList();
  }

  bool _isActivityStartSlot(Activity activity, String slotTime) {
    final start = activity.resolvedStartDateTime;
    if (start == null) return false;

    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    return time == slotTime;
  }

  bool _isAvailabilityStartSlot(Availability availability, String slotTime) {
    final start = availability.resolvedStartDateTime;
    if (start == null) return false;

    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    return time == slotTime;
  }

  bool _isSearchStartSlot(
    Map<String, dynamic> search,
    String slotTime,
  ) {
    final start = _searchResolvedStartDateTime(search);
    if (start == null) return false;

    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    return time == slotTime;
  }

  bool _matchesCreatedFilter(Activity activity) {
    switch (_activeFilter) {
      case CalendarFilterType.none:
      case CalendarFilterType.created:
        return _matchesTimeFilter(activity);
      case CalendarFilterType.full:
        return activity.isFull && _matchesTimeFilter(activity);
      case CalendarFilterType.cancelled:
        return activity.isCancelled && _matchesTimeFilter(activity);
      case CalendarFilterType.done:
        return activity.isDone && _matchesTimeFilter(activity);
      case CalendarFilterType.ownerRequired:
        return activity.requiresOwner && _matchesTimeFilter(activity);
      case CalendarFilterType.joined:
      case CalendarFilterType.searches:
      case CalendarFilterType.availabilities:
      case CalendarFilterType.tonight:
      case CalendarFilterType.weekend:
        return false;
    }
  }

  bool _matchesJoinedFilter(Activity activity) {
    switch (_activeFilter) {
      case CalendarFilterType.none:
      case CalendarFilterType.joined:
        return _matchesTimeFilter(activity);
      case CalendarFilterType.full:
        return activity.isFull && _matchesTimeFilter(activity);
      case CalendarFilterType.cancelled:
        return activity.isCancelled && _matchesTimeFilter(activity);
      case CalendarFilterType.done:
        return activity.isDone && _matchesTimeFilter(activity);
      case CalendarFilterType.ownerRequired:
        return activity.requiresOwner && _matchesTimeFilter(activity);
      case CalendarFilterType.created:
      case CalendarFilterType.searches:
      case CalendarFilterType.availabilities:
      case CalendarFilterType.tonight:
      case CalendarFilterType.weekend:
        return false;
    }
  }

  bool _matchesAvailabilityFilter(Availability availability) {
    switch (_activeFilter) {
      case CalendarFilterType.none:
      case CalendarFilterType.availabilities:
        return true;
      default:
        return false;
    }
  }

  bool _matchesSearchFilter(Map<String, dynamic> search) {
    switch (_activeFilter) {
      case CalendarFilterType.none:
      case CalendarFilterType.searches:
        return true;
      default:
        return false;
    }
  }

  bool _matchesFriendsFilter(Activity activity) {
    if (!_filterByFriends) return true;
    if (_friendIds.isEmpty) return false;
    return _friendIds.contains(activity.ownerId);
  }

  void _jumpToCurrentWeek() {
    setState(() {
      _displayedWeekAnchor = _normalizeDate(DateTime.now());
    });
  }

  void _jumpToWeekendWeek() {
    final now = _normalizeDate(DateTime.now());
    final weekday = now.weekday;
    final daysUntilSaturday = weekday <= 6 ? 6 - weekday : 0;
    final saturday = now.add(Duration(days: daysUntilSaturday));
    setState(() {
      _displayedWeekAnchor = saturday;
    });
  }

  bool _matchesTimeFilter(Activity activity) {
    if (_timeFilter == null) return true;

    final start = activity.resolvedStartDateTime;
    if (start == null) return false;

    if (_timeFilter == CalendarFilterType.tonight) {
      return TemporalActivityUtils.isTonightActivity(
        activity.resolvedStartDateTime,
      );
    }

    if (_timeFilter == CalendarFilterType.weekend) {
      return TemporalActivityUtils.isWeekendActivity(
        activity.resolvedStartDateTime,
      );
    }

    return true;
  }

  void _setActiveFilter(CalendarFilterType filter) {
    setState(() {
      _activeFilter = filter;
      if (filter == CalendarFilterType.none) {
        _timeFilter = null;
        _filterByFriends = false;
      }
    });
  }

  bool _isInactiveActivity(Activity activity) {
    return activity.isCancelled || activity.isDone;
  }

  Color _getActivityBaseColor({
    required bool isCreated,
    required Activity activity,
  }) {
    if (activity.isCancelled) {
      return const Color(0xFFFFF0EF);
    }

    if (activity.isDone) {
      return const Color(0xFFF1EFEB);
    }

    return isCreated ? const Color(0xFFB8ECE6) : const Color(0xFFFFD6D3);
  }

  Color _getMutedColor(Color baseColor) {
    return Color.lerp(baseColor, Colors.white, 0.62) ?? baseColor;
  }

  int _countFullActivities(
    List<Activity> createdActivities,
    List<Activity> joinedActivities,
  ) {
    return [...createdActivities, ...joinedActivities]
        .where((activity) => activity.isFull)
        .length;
  }

  int _countCancelledActivities(
    List<Activity> createdActivities,
    List<Activity> joinedActivities,
  ) {
    return [...createdActivities, ...joinedActivities]
        .where((activity) => activity.isCancelled)
        .length;
  }

  int _countDoneActivities(
    List<Activity> createdActivities,
    List<Activity> joinedActivities,
  ) {
    return [...createdActivities, ...joinedActivities]
        .where((activity) => activity.isDone)
        .length;
  }

  int _countOwnerRequiredActivities(
    List<Activity> createdActivities,
    List<Activity> joinedActivities,
  ) {
    return [...createdActivities, ...joinedActivities]
        .where((activity) => activity.requiresOwner)
        .length;
  }

  Widget _buildActivityStartContent(
    Activity activity, {
    required bool isCreated,
    bool isDimmed = false,
  }) {
    final isInactive = _isInactiveActivity(activity);
    final isTonightActivity = TemporalActivityUtils.isTonightActivity(
      activity.resolvedStartDateTime,
    );
    final isWeekendActivity = TemporalActivityUtils.isWeekendActivity(
      activity.resolvedStartDateTime,
    );

    return Opacity(
      opacity: isDimmed ? 0.38 : (isInactive ? 0.72 : 1),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: isInactive || isDimmed ? Colors.black54 : Colors.black87,
                decoration: activity.isCancelled
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                _buildMiniBadge(
                  isCreated ? 'Créée' : 'Rejointe',
                  backgroundColor: isCreated
                      ? const Color(0xFF00B4A6)
                      : const Color(0xFFF9635E),
                  textColor: Colors.white,
                  isDimmed: isDimmed,
                ),
                if (!isDimmed && isTonightActivity)
                  _buildMiniBadge(
                    'Ce soir',
                    backgroundColor: const Color(0xFFFFF4E6),
                    textColor: const Color(0xFFF4B266),
                    isDimmed: false,
                  ),
                if (!isDimmed && !isTonightActivity && isWeekendActivity)
                  _buildMiniBadge(
                    'Ce week-end',
                    backgroundColor: const Color(0xFFF0EEFF),
                    textColor: const Color(0xFF8B80F9),
                    isDimmed: false,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityStartContent(
    Availability availability, {
    bool isDimmed = false,
  }) {
    return Opacity(
      opacity: isDimmed ? 0.38 : 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            availability.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: isDimmed ? Colors.black54 : Colors.black87,
            ),
          ),
          const SizedBox(height: 3),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              _buildMiniBadge(
                availability.typeLabel,
                backgroundColor: Colors.white.withOpacity(0.85),
                textColor: Colors.black87,
                isDimmed: isDimmed,
              ),
              if (availability.note.trim().isNotEmpty)
                _buildMiniBadge(
                  'Note',
                  backgroundColor: Colors.white.withOpacity(0.85),
                  textColor: Colors.black87,
                  isDimmed: isDimmed,
                ),
              if (isDimmed)
                _buildMiniBadge(
                  'Hors filtre',
                  backgroundColor: Colors.grey.shade200,
                  textColor: Colors.grey.shade700,
                ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSearchStartContent(
    Map<String, dynamic> search, {
    bool isDimmed = false,
  }) {
    final category = (search['category'] ?? '').toString().trim();

    return Opacity(
      opacity: isDimmed ? 0.38 : 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔍 Recherche',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: isDimmed ? Colors.black54 : Colors.black87,
              ),
            ),
            if (category.isNotEmpty) ...[
              const SizedBox(height: 3),
              _buildMiniBadge(
                category,
                backgroundColor: const Color(0xFFFFF4E6),
                textColor: const Color(0xFFF4B266),
                isDimmed: isDimmed,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(
    String text, {
    required Color backgroundColor,
    required Color textColor,
    bool isDimmed = false,
  }) {
    final resolvedBackgroundColor =
        isDimmed ? _getMutedColor(backgroundColor) : backgroundColor;
    final resolvedTextColor = isDimmed
        ? Color.lerp(textColor, Colors.grey.shade600, 0.45) ?? textColor
        : textColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: resolvedBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w600,
          color: resolvedTextColor,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildAggregateSearchContent(
    int count, {
    bool isDimmed = false,
  }) {
    return Opacity(
      opacity: isDimmed ? 0.38 : 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 48),
        child: Text(
          '🔍 $count recherches',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: isDimmed ? Colors.black54 : Colors.black87,
          ),
        ),
      ),
    );
  }

  void _showMultipleSearchesBottomSheet(
    BuildContext context,
    List<Map<String, dynamic>> searches,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recherches sur ce créneau',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...searches.map((search) {
                final startDt = search['startDateTime'] as DateTime?;
                final endDt = search['endDateTime'] as DateTime?;
                final cat = (search['category'] ?? '').toString().trim();

                final startStr = startDt != null
                    ? '${startDt.hour.toString().padLeft(2, '0')}:${startDt.minute.toString().padLeft(2, '0')}'
                    : (search['startTime'] ?? '').toString();
                final endStr = endDt != null
                    ? '${endDt.hour.toString().padLeft(2, '0')}:${endDt.minute.toString().padLeft(2, '0')}'
                    : (search['endTime'] ?? '').toString();

                final timeRange = '$startStr - $endStr';
                final label = cat.isNotEmpty ? '$timeRange • $cat' : timeRange;

                return ListTile(
                  title: Text(label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchDetailPage(
                          searchId: (search['id'] ?? '').toString(),
                          day: (search['day'] ?? '').toString(),
                          startTime: (search['startTime'] ?? '').toString(),
                          endTime: (search['endTime'] ?? '').toString(),
                          category: (search['category'] ?? '').toString(),
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContinuationMarker({
    bool isInactive = false,
    bool isDimmed = false,
  }) {
    return Align(
      alignment: Alignment.topLeft,
      child: Opacity(
        opacity: isDimmed ? 0.28 : (isInactive ? 0.55 : 1),
        child: Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(
              isDimmed ? 0.08 : (isInactive ? 0.12 : 0.18),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFilterRow({
    required List<Widget> children,
  }) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  Widget _buildWeekNavigator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _changeWeek(-1),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Semaine précédente',
          ),
          Expanded(
            child: Text(
              _formatWeekRange(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _changeWeek(1),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Semaine suivante',
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySummary(
    List<Activity> createdActivities,
    List<Activity> joinedActivities,
    List<Availability> availabilities,
    List<Map<String, dynamic>> searches,
  ) {
    final fullCount = _countFullActivities(
      createdActivities,
      joinedActivities,
    );
    final cancelledCount = _countCancelledActivities(
      createdActivities,
      joinedActivities,
    );
    final doneCount = _countDoneActivities(
      createdActivities,
      joinedActivities,
    );
    final ownerRequiredCount = _countOwnerRequiredActivities(
      createdActivities,
      joinedActivities,
    );

    final mainFilters = [
      _buildSummaryChip(
        label: 'Tout',
        value: null,
        backgroundColor: const Color(0xFFF1EFEB),
        textColor: const Color(0xFF1E1E1E),
        isActive: _activeFilter == CalendarFilterType.none,
        onTap: () => _setActiveFilter(CalendarFilterType.none),
      ),
      _buildSummaryChip(
        label: 'Ce soir',
        value: null,
        backgroundColor: const Color(0xFFFFF4E6),
        textColor: const Color(0xFFF4B266),
        isActive: _timeFilter == CalendarFilterType.tonight,
        onTap: () {
          setState(() {
            _timeFilter = _timeFilter == CalendarFilterType.tonight
                ? null
                : CalendarFilterType.tonight;
          });
          if (_timeFilter == CalendarFilterType.tonight) _jumpToCurrentWeek();
        },
      ),
      _buildSummaryChip(
        label: 'Ce week-end',
        value: null,
        backgroundColor: const Color(0xFFF0EEFF),
        textColor: const Color(0xFF8B80F9),
        isActive: _timeFilter == CalendarFilterType.weekend,
        onTap: () {
          setState(() {
            _timeFilter = _timeFilter == CalendarFilterType.weekend
                ? null
                : CalendarFilterType.weekend;
          });
          if (_timeFilter == CalendarFilterType.weekend) _jumpToWeekendWeek();
        },
      ),
      _buildSummaryChip(
        label: _friendIds.isEmpty ? 'Amis' : 'Amis (${_friendIds.length})',
        value: null,
        backgroundColor: const Color(0xFFE6FAF8),
        textColor: const Color(0xFF00B4A6),
        isActive: _filterByFriends,
        onTap: () {
          if (_friendIds.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Aucun ami pour le moment'),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
          setState(() => _filterByFriends = !_filterByFriends);
        },
      ),
      _buildSummaryChip(
        label: 'Créées',
        value: createdActivities.length,
        backgroundColor: const Color(0xFFE6FAF8),
        textColor: const Color(0xFF00B4A6),
        isActive: _activeFilter == CalendarFilterType.created,
        onTap: () => _setActiveFilter(CalendarFilterType.created),
      ),
      _buildSummaryChip(
        label: 'Rejointes',
        value: joinedActivities.length,
        backgroundColor: const Color(0xFFFFF0EF),
        textColor: const Color(0xFFF9635E),
        isActive: _activeFilter == CalendarFilterType.joined,
        onTap: () => _setActiveFilter(CalendarFilterType.joined),
      ),
      _buildSummaryChip(
        label: 'Recherches',
        value: searches.length,
        backgroundColor: const Color(0xFFFFF4E6),
        textColor: const Color(0xFFF4B266),
        isActive: _activeFilter == CalendarFilterType.searches,
        onTap: () => _setActiveFilter(CalendarFilterType.searches),
      ),
      _buildSummaryChip(
        label: 'Notes/Dispos',
        value: availabilities.length,
        backgroundColor: const Color(0xFFECFDF4),
        textColor: const Color(0xFF34C759),
        isActive: _activeFilter == CalendarFilterType.availabilities,
        onTap: () => _setActiveFilter(CalendarFilterType.availabilities),
      ),
    ];

    final advancedFilters = [
      _buildSubSummaryChip(
        label: 'Complètes',
        value: fullCount,
        backgroundColor: const Color(0xFFFFF4E6),
        textColor: const Color(0xFFF4B266),
        isActive: _activeFilter == CalendarFilterType.full,
        onTap: () => _setActiveFilter(CalendarFilterType.full),
      ),
      _buildSubSummaryChip(
        label: 'Annulées',
        value: cancelledCount,
        backgroundColor: const Color(0xFFFFF0EF),
        textColor: const Color(0xFFF9635E),
        isActive: _activeFilter == CalendarFilterType.cancelled,
        onTap: () => _setActiveFilter(CalendarFilterType.cancelled),
      ),
      _buildSubSummaryChip(
        label: 'Terminées',
        value: doneCount,
        backgroundColor: const Color(0xFFF1EFEB),
        textColor: const Color(0xFF6F6F6F),
        isActive: _activeFilter == CalendarFilterType.done,
        onTap: () => _setActiveFilter(CalendarFilterType.done),
      ),
      _buildSubSummaryChip(
        label: 'Owner requis',
        value: ownerRequiredCount,
        backgroundColor: const Color(0xFFF0EEFF),
        textColor: const Color(0xFF8B80F9),
        isActive: _activeFilter == CalendarFilterType.ownerRequired,
        onTap: () => _setActiveFilter(CalendarFilterType.ownerRequired),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactFilterRow(children: mainFilters),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _showAdvancedFilters = !_showAdvancedFilters;
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 0,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _showAdvancedFilters ? 'Moins de filtres' : 'Filtres avancés',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _showAdvancedFilters ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, size: 18),
                  ),
                ],
              ),
            ),
          ),
          if (_showAdvancedFilters) ...[
            const SizedBox(height: 2),
            _buildCompactFilterRow(children: advancedFilters),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required int? value,
    required Color backgroundColor,
    required Color textColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final resolvedBackgroundColor =
        isActive ? textColor.withOpacity(0.16) : backgroundColor;
    final resolvedBorderColor = isActive ? textColor : backgroundColor;
    final resolvedTextColor = textColor;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: resolvedBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: resolvedBorderColor,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) ...[
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: resolvedTextColor,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: resolvedTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubSummaryChip({
    required String label,
    required int value,
    required Color backgroundColor,
    required Color textColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final resolvedBackgroundColor =
        isActive ? textColor.withOpacity(0.16) : backgroundColor;
    final resolvedBorderColor = isActive ? textColor : backgroundColor;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: resolvedBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: resolvedBorderColor,
            width: isActive ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarBody(
    BuildContext context,
    List<Activity> createdActivities,
    List<Activity> joinedActivities,
    List<Availability> availabilities,
    List<Map<String, dynamic>> searches,
  ) {
    return Column(
      children: [
        _buildWeekNavigator(),
        _buildWeeklySummary(
          createdActivities,
          joinedActivities,
          availabilities,
          searches,
        ),
        buildDaysHeader(),
        Expanded(
          child: buildCalendarGrid(
            context,
            _timeSlots,
            createdActivities,
            joinedActivities,
            availabilities,
            searches,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Activity>>(
        stream: activityService.getCreatedActivities(),
        builder: (context, createdSnapshot) {
          if (createdSnapshot.hasError) {
            return Center(
              child: Text(
                'Erreur activités créées : ${createdSnapshot.error}',
              ),
            );
          }

          if (!createdSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return StreamBuilder<List<Activity>>(
            stream: activityService.getJoinedActivities(),
            builder: (context, joinedSnapshot) {
              if (joinedSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Erreur activités rejointes : ${joinedSnapshot.error}',
                  ),
                );
              }

              if (!joinedSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return StreamBuilder<List<Availability>>(
                stream: availabilityService.getAvailabilities(),
                builder: (context, availabilitySnapshot) {
                  if (availabilitySnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erreur disponibilités : ${availabilitySnapshot.error}',
                      ),
                    );
                  }

                  if (!availabilitySnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: searchService.getSearches(),
                    builder: (context, searchSnapshot) {
                      if (searchSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Erreur recherches : ${searchSnapshot.error}',
                          ),
                        );
                      }

                      if (!searchSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final rawCreatedActivities = createdSnapshot.data ?? [];
                      final rawJoinedActivities = joinedSnapshot.data ?? [];
                      final rawAvailabilities = availabilitySnapshot.data ?? [];
                      final rawSearches = searchSnapshot.data ?? [];

                      final createdActivities =
                          _filterActivitiesForDisplayedWeek(
                        rawCreatedActivities,
                      );

                      final joinedActivities =
                          _filterActivitiesForDisplayedWeek(
                        _deduplicateJoinedActivities(
                          rawCreatedActivities,
                          rawJoinedActivities,
                        ),
                      );

                      final availabilities =
                          _filterAvailabilitiesForDisplayedWeek(
                        rawAvailabilities,
                      );

                      final searches = _filterSearchesForDisplayedWeek(
                        rawSearches,
                      );

                      return _buildCalendarBody(
                        context,
                        createdActivities,
                        joinedActivities,
                        availabilities,
                        searches,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
  }

  Widget buildDaysHeader() {
    final weekStart = _startOfWeek(_displayedWeekAnchor);
    const dayAbbreviations = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    return Row(
      children: [
        const SizedBox(width: 46),
        for (int i = 0; i < days.length; i++)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Text(
                    dayAbbreviations[i],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${weekStart.add(Duration(days: i)).day}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget buildCalendarGrid(
    BuildContext context,
    List<String> timeSlots,
    List<Activity> createdActivities,
    List<Activity> joinedActivities,
    List<Availability> availabilities,
    List<Map<String, dynamic>> searches,
  ) {
    return ListView.builder(
      itemCount: timeSlots.length,
      itemBuilder: (context, index) {
        final hour = timeSlots[index];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 58,
              alignment: Alignment.center,
              child: Text(
                hour,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            for (var day in days)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final slotDate = _getDateForDay(day);
                    final rawCreatedActivity =
                        getActivityForSlot(day, hour, createdActivities);
                    final rawJoinedActivity =
                        getActivityForSlot(day, hour, joinedActivities);
                    final rawAvailability =
                        getAvailabilityForSlot(day, hour, availabilities);
                    final rawSearches = getSearchesForSlot(day, hour, searches);
                    final rawSearch = rawSearches.length == 1 ? rawSearches.first : null;
                    final hasMultipleSearches = rawSearches.length >= 2;
                    final rawSearchProxy = hasMultipleSearches ? rawSearches.first : rawSearch;

                    final matchedCreatedActivity =
                        rawCreatedActivity != null &&
                                _matchesCreatedFilter(rawCreatedActivity) &&
                                _matchesFriendsFilter(rawCreatedActivity)
                            ? rawCreatedActivity
                            : null;

                    final matchedJoinedActivity =
                        rawJoinedActivity != null &&
                                _matchesJoinedFilter(rawJoinedActivity) &&
                                _matchesFriendsFilter(rawJoinedActivity)
                            ? rawJoinedActivity
                            : null;

                    final matchedAvailability =
                        rawAvailability != null &&
                                _matchesAvailabilityFilter(rawAvailability)
                            ? rawAvailability
                            : null;

                    final matchedSearch =
                        rawSearchProxy != null &&
                                _matchesSearchFilter(rawSearchProxy)
                            ? rawSearchProxy
                            : null;

                    final hasMatchedElement =
                        matchedCreatedActivity != null ||
                            matchedJoinedActivity != null ||
                            matchedAvailability != null ||
                            matchedSearch != null;

                    final shouldDimNonMatching =
                        _hasActiveFilter && !hasMatchedElement;

                    final createdActivity = hasMatchedElement
                        ? matchedCreatedActivity
                        : rawCreatedActivity;
                    final joinedActivity = hasMatchedElement
                        ? matchedJoinedActivity
                        : rawJoinedActivity;
                    final availability =
                        hasMatchedElement ? matchedAvailability : rawAvailability;
                    final search = hasMatchedElement ? matchedSearch : rawSearchProxy;

                    final isCreatedDimmed =
                        shouldDimNonMatching && createdActivity != null;
                    final isJoinedDimmed =
                        shouldDimNonMatching && joinedActivity != null;
                    final isAvailabilityDimmed =
                        shouldDimNonMatching && availability != null;
                    final isSearchDimmed =
                        shouldDimNonMatching && search != null;

                    Color cellColor = const Color(0xFFFAF9F7);
                    Widget? cellContent;

                    if (search != null) {
                      final baseColor = Colors.orange[200]!;
                      cellColor = isSearchDimmed
                          ? _getMutedColor(baseColor)
                          : baseColor;

                      if (hasMultipleSearches) {
                        if (_isSearchStartSlot(rawSearches.first, hour)) {
                          cellContent = _buildAggregateSearchContent(
                            rawSearches.length,
                            isDimmed: isSearchDimmed,
                          );
                        } else {
                          cellContent = _buildContinuationMarker(
                            isDimmed: isSearchDimmed,
                          );
                        }
                      } else if (_isSearchStartSlot(search, hour)) {
                        cellContent = _buildSearchStartContent(
                          search,
                          isDimmed: isSearchDimmed,
                        );
                      } else {
                        cellContent = _buildContinuationMarker(
                          isDimmed: isSearchDimmed,
                        );
                      }
                    }

                    if (availability != null) {
                      final baseColor = Colors.green[100]!;
                      cellColor = isAvailabilityDimmed
                          ? _getMutedColor(baseColor)
                          : baseColor;

                      if (_isAvailabilityStartSlot(availability, hour)) {
                        cellContent = _buildAvailabilityStartContent(
                          availability,
                          isDimmed: isAvailabilityDimmed,
                        );
                      } else {
                        cellContent = _buildContinuationMarker(
                          isDimmed: isAvailabilityDimmed,
                        );
                      }
                    }

                    if (joinedActivity != null) {
                      final baseColor = _getActivityBaseColor(
                        isCreated: false,
                        activity: joinedActivity,
                      );
                      cellColor = isJoinedDimmed
                          ? _getMutedColor(baseColor)
                          : baseColor;

                      final isJoinedStartSlot =
                          _isActivityStartSlot(joinedActivity, hour);
                      final isJoinedOvernightStart = !isJoinedStartSlot &&
                          joinedActivity.resolvedStartDateTime != null &&
                          joinedActivity.resolvedEndDateTime != null &&
                          !DateUtils.isSameDay(
                            joinedActivity.resolvedStartDateTime!,
                            joinedActivity.resolvedEndDateTime!,
                          ) &&
                          DateUtils.isSameDay(
                            joinedActivity.resolvedEndDateTime!,
                            slotDate,
                          ) &&
                          timeToMinutes(hour) == 0;

                      if (isJoinedStartSlot) {
                        cellContent = _buildActivityStartContent(
                          joinedActivity,
                          isCreated: false,
                          isDimmed: isJoinedDimmed,
                        );
                      } else if (isJoinedOvernightStart) {
                        cellContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              joinedActivity.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '→ fin ${joinedActivity.resolvedEndDateTime!.hour.toString().padLeft(2, '0')}:${joinedActivity.resolvedEndDateTime!.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 8,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        );
                      } else {
                        cellContent = _buildContinuationMarker(
                          isInactive: _isInactiveActivity(joinedActivity),
                          isDimmed: isJoinedDimmed,
                        );
                      }
                    }

                    if (createdActivity != null) {
                      final baseColor = _getActivityBaseColor(
                        isCreated: true,
                        activity: createdActivity,
                      );
                      cellColor = isCreatedDimmed
                          ? _getMutedColor(baseColor)
                          : baseColor;

                      final isCreatedStartSlot =
                          _isActivityStartSlot(createdActivity, hour);
                      final isCreatedOvernightStart = !isCreatedStartSlot &&
                          createdActivity.resolvedStartDateTime != null &&
                          createdActivity.resolvedEndDateTime != null &&
                          !DateUtils.isSameDay(
                            createdActivity.resolvedStartDateTime!,
                            createdActivity.resolvedEndDateTime!,
                          ) &&
                          DateUtils.isSameDay(
                            createdActivity.resolvedEndDateTime!,
                            slotDate,
                          ) &&
                          timeToMinutes(hour) == 0;

                      if (isCreatedStartSlot) {
                        cellContent = _buildActivityStartContent(
                          createdActivity,
                          isCreated: true,
                          isDimmed: isCreatedDimmed,
                        );
                      } else if (isCreatedOvernightStart) {
                        cellContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              createdActivity.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '→ fin ${createdActivity.resolvedEndDateTime!.hour.toString().padLeft(2, '0')}:${createdActivity.resolvedEndDateTime!.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 8,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        );
                      } else {
                        cellContent = _buildContinuationMarker(
                          isInactive: _isInactiveActivity(createdActivity),
                          isDimmed: isCreatedDimmed,
                        );
                      }
                    }

                    final cellBorder = createdActivity != null
                        ? const Border.fromBorderSide(BorderSide(color: Color(0xFFB8ECE6), width: 0.8))
                        : joinedActivity != null
                            ? const Border.fromBorderSide(BorderSide(color: Color(0xFFFFB8B4), width: 0.8))
                            : availability != null
                                ? const Border.fromBorderSide(BorderSide(color: Color(0xFFB8E8C8), width: 0.8))
                                : search != null
                                    ? const Border.fromBorderSide(BorderSide(color: Color(0xFFFFD9A0), width: 0.8))
                                    : const Border.fromBorderSide(BorderSide(color: Color(0xFFEDE9E3), width: 0.5));

                    return GestureDetector(
                      onTap: () {
                        if (createdActivity != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActivityDetailPage(
                                activity: createdActivity,
                              ),
                            ),
                          );
                          return;
                        }

                        if (joinedActivity != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActivityDetailPage(
                                activity: joinedActivity,
                              ),
                            ),
                          );
                          return;
                        }

                        if (search != null) {
                          if (hasMultipleSearches) {
                            _showMultipleSearchesBottomSheet(
                              context,
                              rawSearches,
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchDetailPage(
                                  searchId: (search['id'] ?? '').toString(),
                                  day: (search['day'] ?? '').toString(),
                                  startTime:
                                      (search['startTime'] ?? '').toString(),
                                  endTime: (search['endTime'] ?? '').toString(),
                                  category:
                                      (search['category'] ?? '').toString(),
                                ),
                              ),
                            );
                          }
                          return;
                        }

                        if (availability != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AvailabilityDetailPage(
                                availability: availability,
                              ),
                            ),
                          );
                          return;
                        }

                        showSlotActions(context, day, hour);
                      },
                      child: Container(
                        height: 58,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 1),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cellColor,
                          border: cellBorder,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: cellContent != null
                              ? const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                  BoxShadow(
                                    color: Color(0x06000000),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: cellContent,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void showSlotActions(BuildContext context, String day, String hour) {
    final copiedActivity = ActivityClipboardService.copiedActivity;
    final hasCopiedActivity = copiedActivity != null;

    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: hasCopiedActivity ? 360 : 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$day - $hour',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasCopiedActivity) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'Activité copiée : ${copiedActivity.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateActivityPage(
                            day: day,
                            hour: hour,
                            selectedDate: _getDateForDay(day),
                            groupId: copiedActivity.groupId,
                            groupName: copiedActivity.groupName,
                            duplicatedFromActivity: copiedActivity,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.content_paste),
                    label: const Text('Coller l’activité copiée ici'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      ActivityClipboardService.clear();
                      Navigator.pop(bottomSheetContext);
                      setState(() {});

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Activité copiée supprimée'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Vider l’activité copiée'),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            NoteSlotPage(day: day, hour: hour),
                      ),
                    );
                  },
                  child: const Text('Noter une activité'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SearchActivityPage(day: day, hour: hour, selectedDate: _getDateForDay(day)),
                      ),
                    );
                  },
                  child: const Text('Rechercher une activité'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateActivityPage(
                          day: day,
                          hour: hour,
                          selectedDate: _getDateForDay(day),
                        ),
                      ),
                    );
                  },
                  child: const Text('Créer une activité'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}