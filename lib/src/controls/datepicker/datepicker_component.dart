import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import 'package:angular_components/material_input/material_input.dart';
import 'package:intl/intl.dart';

import 'month_component.dart';

class DatepickerEntry
{
  String key;
  String title;
  var _fill = null;
  fill(DatepickerPeriod data)
  {
    data.entryKey = key;
    _fill(data);
  }

  DatepickerEntry(this.key, this.title, this._fill);
}

class DatepickerPeriod
{
  static List<String> monthNames = Intl.message(
    "Januar|Februar|März|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember").split("|");
  static List<String> monthShortNames = Intl.message("Jan|Feb|Mär|Apr|Mai|Jun|Jul|Aug|Sep|Okt|Nov|Dez").split("|");
  static List<String> dowNames = Intl.message("Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag").split("|");
  static List<String> dowShortNames = Intl.message("Mo|Di|Mi|Do|Fr|Sa|So").split("|");

  String fmtDate = "dd.MM.yyyy";
  DateFormat get dateFormat
  => DateFormat(fmtDate);

  int firstDayOfWeek = 1;
  static monthName(Date date)
  => date != null ? monthNames[date.month - 1] : "";
  static dowName(Date date)
  => date != null ? dowNames[date.weekday - 1] : "";
  static monthShortName(Date date)
  => date != null ? monthShortNames[date.month - 1] : "";
  static dowShortName(Date date)
  => date != null ? dowShortNames[date.weekday - 1] : "";

  Date start = null;
  Date end = null;
  String entryKey = null;
  Date minDate = null;
  Date maxDate = null;

  bool get isEmpty => (entryKey == null || entryKey.isEmpty) && start == null;

  List<DatepickerEntry> list = List<DatepickerEntry>();

  String get entryTitle
  {
    if (list != null)
    {
      for (DatepickerEntry entry in list)
        if (entry.key == entryKey)return entry.title;
    }
    return "";
  }

  Date parse(String date)
  {
    Date ret = null;
    if (date != null && date.length == 8)
    {
      int y = int.tryParse(date.substring(0, 4)) ?? 0;
      int m = int.tryParse(date.substring(4, 6)) ?? 1;
      int d = int.tryParse(date.substring(6, 8)) ?? 1;
      ret = Date(y, m, d);
    }

    return ret;
  }

  reset(String src)
  {
    try
    {
      List<String> parts = (src ?? "").split("|");
      start = null;
      end = null;
      entryKey = null;
      firstDayOfWeek = 1;
      if (parts.length == 4)
      {
        start = parse(parts[0]);
        end = parse(parts[1]);
        entryKey = parts[2] == "" || parts[2] == "null" ? null : parts[2];
        firstDayOfWeek = int.tryParse(parts[3]) ?? 0;
      }
    }
    catch (ex)
    {
    }
  }

  DatepickerPeriod({String src = ""})
  {
    reset(src);
  }

  String toString()
  {
    return "${start?.format(DateFormat("yyyyMMdd")) ?? ""}|${end?.format(DateFormat("yyyyMMdd")) ?? ""}|${entryKey
                                                                                                          ?? ""}|${firstDayOfWeek}";
  }
}

@Component(selector: 'datepicker',
  styleUrls: ['datepicker_component.css'],
  templateUrl: 'datepicker_component.html',
  directives: [
    ModalComponent,
    MaterialDialogComponent,
    MaterialButtonComponent,
    materialInputDirectives,
    MaterialIconComponent,
    MaterialInputComponent,
    MonthComponent,
    NgFor,
    NgIf
  ],
  providers: [],)
class DatepickerComponent
{
  @Input()
  int firstDayOfWeek = 1;

  bool get isMaxMonth
  =>
    period != null && period.maxDate != null && month != null && (month.year > period.maxDate.year || (month.year == period.maxDate.year
                                                                                     && month.month >= period.maxDate
        .month));
  bool get isMinMonth
  =>
    period != null && period.minDate != null && month != null && (month.year < period.minDate.year || (month.year == period.minDate.year
                                                                                     && month.month <= period.minDate
        .month));

  get msgStartIncorrect
  => Intl.message("Das Startdatum ist nicht korrekt");
  get msgEndIncorrect
  => Intl.message("Das Enddatum ist nicht korrekt");

  DatepickerPeriod _period = null;
  Date month = null;

  DatepickerPeriod get period
  => _period;
  @Input()
  void set period(value)
  {
    DatepickerPeriod temp = value is DatepickerPeriod ? value : DatepickerPeriod(src: value);
    _period = temp ?? _period;
    if(_period.entryKey != null && _period.list.length > 0)
    {
      DatepickerEntry entry =_period.list.firstWhere((e)
      => e.key == _period.entryKey);
      entry?.fill(_period);
    }
    month = Date.today();
  }

  final _periodChange = StreamController<DatepickerPeriod>();
  @Output()
  Stream<DatepickerPeriod> get periodChange
  => _periodChange.stream;

  String loadedPeriod = null;
  revertData()
  {
    period.reset(loadedPeriod);
  }

  bool isStartValid = true;
  String get startDate
  => period.start?.format(period.dateFormat);

  set startDate(String value)
  {
    try
    {
      period.start = Date.parse(value, period.dateFormat);
      period.entryKey = null;
      isStartValid = true;
    }
    catch (ex)
    {
      isStartValid = false;
    }
  }

  bool isEndValid = true;
  String get endDate
  => period.end?.format(period.dateFormat);
  set endDate(String value)
  {
    try
    {
      period.end = Date.parse(value, period.dateFormat);
      period.entryKey = null;
      isEndValid = true;
    }
    catch (ex)
    {
      isEndValid = false;
    }
  }

  get msgPeriod
  => Intl.message("Zeitraum");

  get msgPeriodEmpty
  => Intl.message("Zeitraum festlegen");

  String get periodFloatingLabel
  {
    if (period.start == null || period.end == null)return "";
    return msgPeriod;
  }

  String get periodLabel
  {
    if (period == null)return "";
    if (period.entryKey != null)return period.entryTitle;
    if (period.start == null || period.end == null)return msgPeriodEmpty;
    if (period.start.compareTo(period.end) == 0)return period.start.format(period.dateFormat);
    return "${period.start.format(period.dateFormat)} - ${period.end.format(period.dateFormat)}";
  }

  @Output("save")
  Stream<UIEvent> get trigger
  => _trigger.stream;
  final _trigger = StreamController<UIEvent>.broadcast(sync: true);

  @Input()
  bool isDialogOpen = false;

  DatepickerComponent();

  void fire(String type)
  async {
    if(type == "save")
      _periodChange.add(period);
    _trigger.add(UIEvent(type, detail: 0));
  }
}
