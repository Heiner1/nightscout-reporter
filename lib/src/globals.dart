library diamant.globals;

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:googleapis/drive/v3.dart' as gd;
import 'package:googleapis_auth/auth_browser.dart' as auth;
import 'package:angular_components/angular_components.dart';
import 'package:angular_components/material_datepicker/comparison.dart';
import 'package:angular_components/material_datepicker/comparison_option.dart';
import 'package:angular_components/material_datepicker/range.dart';
import 'package:http/browser_client.dart' as http;
import 'package:intl/intl.dart';
import 'package:nightscout_reporter/src/controls/datepicker/datepicker_component.dart';
import 'package:nightscout_reporter/src/forms/base-print.dart';

class Msg
{
  String okText = Intl.message("Schliessen");
  String text;
  String type = "msg";
  var links = [];
  bool get isEmpty
  => (text == null || text == "") && links.length == 0;

  void clear()
  {
    text = null;
    links = [];
  }

  void dismiss(call)
  {
    if (call != null)call();
    text = null;
    links = [];
  }
}

class LangData
{
  String code;
  String name;
  String img;
  String dateformat;
  String get imgPath
  => "https://findicons.com/files/icons/2758/flag_icons/32/${img}.png";

  LangData(this.code, this.name, this.dateformat, this.img);
}

class GoogleAuth
{
  final identifier = new auth.ClientId("939975570793-i9kj0rp6kgv470t45j1pf1hg3j9fqmbh.apps.googleusercontent.com", null);
  final scopes = [gd.DriveApi.DriveAppdataScope];
  var client = null;
  gd.DriveApi drive = null;
}

class Globals
{
  String version = "1.1.2-8";
  String lastVersion;

  GoogleAuth ga = GoogleAuth();
  static final Globals _globals = Globals._internal();

  factory Globals(){
    return _globals;
  }

  Globals._internal(){
    load();
  }

  List<FormConfig> listConfig = List<FormConfig>();

  Date date(DateTime src)
  => Date(src.year, src.month, src.day);

  String get msgBE
  => _khFactor == 10 ? Intl.message("msgBE") : Intl.message("msgKE");
  String get msgUrlFailure
  =>
    Intl.message("Die angegebene URL ist nicht erreichbar. "
      "Wenn die URL stimmt, dann kann es an den Nightscout-Einstellungen liegen. "
      "In der Variable ENABLE muss das Wort \"cors\" stehen, damit externe Tools, "
      "wie dieses hier, auf die Daten zugreifen dürfen.<br><br>Wenn diese URL geschützt ist, "
      "muss ausserdem das UserToken korrekt definiert sein.");
  String get msgNoURLDefined
  => Intl.message("Die URL wurde noch nicht festgelegt.");

  String title = "Nightscout Reporter";
  List<UserData> userList = List<UserData>();
  int _userIdx = 0;
  int get userIdx
  => _userIdx;
  set userIdx(value)
  {
    if (value >= 0 && value < userList.length)_userIdx = value;
    else
      _userIdx = 0;

    for (FormConfig entry in listConfig)
      entry.fillFromString(user.formParams[entry.id]);
  }

  UserData get user
  {
    if (_userIdx >= 0 && _userIdx < userList.length)return userList[_userIdx];
    if (userList.length == 0)userList.add(UserData(this));
    userIdx = 0;
    return userList[0];
  }

  List<LangData> languageList = [
    LangData("de_DE", Intl.message("Deutsch"), "dd.MM.yyyy", "de"),
    LangData("en_US", Intl.message("English"), "M/d/yyyy", "us")
  ];
  LangData language;
  String get msgToday
  => Intl.message("Heute");
  String get msgLast2Days
  => Intl.message("Letzte 2 Tage");
  String get msgLast3Days
  => Intl.message("Letzte 3 Tage");
  String get msgLastWeek
  => Intl.message("Letzte Woche");
  String get msgLast2Weeks
  => Intl.message("Letzte 2 Wochen");
  String get msgLast3Weeks
  => Intl.message("Letzte 3 Wochen");
  String get msgLastMonth
  => Intl.message("Letzter Monat");
  String get msgLast3Months
  => Intl.message("Letzte 3 Monate");

  bool glucMGDL = true;
  DatepickerPeriod period = DatepickerPeriod();
  DatepickerComparison _dateRange = DatepickerComparison(
    DatepickerDateRange(Intl.message("Zeitraum"), null, null), ComparisonOption.custom);
  DateFormat fmtDateForData;
  DateFormat fmtDateForDisplay;
  bool canDebug = false;
  bool isBeta = html.window.location.href.contains("/beta/");
  bool isLocal = html.window.location.href.contains("/localhost:");
  static bool itod = html.window.localStorage["unsafe"] != "zh++;";
  String betaPrefix = "@";
  bool pdfSameWindow = true;
  bool pdfDownload = false;
  bool hideNightscoutInPDF = true;
  bool isConfigured = false;
  int _khFactor = 12;
  int get khFactor
  => _khFactor;
  set khFactor(int value)
  {
    if (value == 10 || value == 12)_khFactor = value;
  }

  bool get isKHBE
  => _khFactor == 12;

  double glucFromData(double value)
  => glucMGDL ? value : value / 18.02;

  String get pdfTarget
  {
    if (!pdfSameWindow)return "_blank";
    return "";
  }

  static double calc(double a, double b, double factor)
  {
    if (a != null && a > 0)
    {
      if (b != null && b > 0)return a + ((b - a) * factor).toInt();
      else
        return a;
    }
    return b;
  }

  Future<String> request(String url, {String method = "GET"})
  async {
    http.BrowserClient client = http.BrowserClient();
    if (user.token != null && user.token.isNotEmpty)
    {
      String div = url.indexOf("?") > 0 ? "&" : "?";
      url = "${url}${div}token=${user.token}";
    }
    return client.get(url).then((response)
    {
      return response.body;
    }).catchError((error)
    {
      return error.toString();
    });
  }

  Future<String> checkSetup({checkUser: null})
  async {
    if (checkUser == null)checkUser = user;
    if (checkUser.storageApiUrl == null || checkUser.apiUrl == null)return msgNoURLDefined;
    String ret = null;
    String check = "${checkUser.apiUrl}status";
    await request(check).then((String response)
    {
      if (!response.toLowerCase().contains("status ok"))ret = msgUrlFailure;
    }).catchError((err)
    {
      ret = msgUrlFailure;
    });
    return ret;
  }

  changeLanguage(LangData value, {bool doReload = true, bool checkConfigured = false})
  async {
    language = value;
    if (checkConfigured && !isConfigured)clearStorage();
    saveStorage("language", language.code ?? "de_DE");
    if (doReload)
    {
      if (!checkConfigured)save();
      reload();
    }
  }

  reload()
  {
    int pos = html.window.location.href.indexOf("?");
    if (pos > 0)html.window.location.href = html.window.location.href.substring(0, pos - 1);
    else
      html.window.location.reload();
  }

  addForm(BasePrint form)
  {
    FormConfig cfg = FormConfig(form.id, false);
    cfg.form = form;
    listConfig.add(cfg);
  }

  void clearStorage()
  {
    for (var entry in html.window.localStorage.entries)
    {
      bool doKill = false;
      doKill = entry.key.startsWith(betaPrefix);
      if (!isBeta)doKill = !doKill;
      if (doKill)html.window.localStorage.remove(entry.key);
    }
  }

  copyFromOtherStorage()
  {
    isBeta = !isBeta;
    load();
    isBeta = !isBeta;
    save();
  }

  void saveStorage(String key, String value)
  {
    if (isBeta)key = "${betaPrefix}${key}";
    if (value == null || value.isEmpty)html.window.localStorage.remove(key);
    else
      html.window.localStorage[key] = value;
  }

  String loadStorage(String key)
  {
    if (isBeta)key = "${betaPrefix}${key}";
    String ret = html.window.localStorage[key];
    if (ret == "null" || ret == null)ret = "";
    return ret;
  }

  UserData u(url, name)
  {
    UserData ret = UserData(this);
    ret.storageApiUrl = url;
    ret.name = name;
    return ret;
  }

  void load()
  {
    // read old data to save them for later. Will be removed in future updates
    if (loadStorage("apiUrl") != "")
    {
      UserData user = UserData(this);
      user.storageApiUrl = loadStorage("apiUrl");
      user.diaStartDate = loadStorage("diaStartDate");
      user.insulin = loadStorage("insulin");
      user.birthDate = loadStorage("birthDate");
      user.name = loadStorage("userName");
      userIdx = 0;
      saveStorage("mu", Globals.doit("[${user.asJson}]"));
      saveStorage("userIdx", "$userIdx");
      saveStorage("version", lastVersion);
      // remove old keys, cod can be removed in future release
      html.window.localStorage.remove("lastVersion");
      html.window.localStorage.remove("apiUrl");
      html.window.localStorage.remove("diaStartDate");
      html.window.localStorage.remove("birthDate");
      html.window.localStorage.remove("userName");
      html.window.localStorage.remove("insulin");
    }

    String users = loadStorage("mu");
    userList.clear();
    // get user list from mu if available
    if (users != null)
    {
      var text = tiod(users);
      if (text != null && text.isNotEmpty)
      {
        try
        {
          var list = convert.json.decode(text);
          for (var entry in list)
            userList.add(UserData.fromData(this, entry));
        }
        catch (e)
        {
          saveStorage("mu", null);
        }
      }
      else
      {
        saveStorage("mu", null);
      }
    }

    userIdx = int.tryParse(loadStorage("userIdx")) ?? 0;
    String langId = loadStorage("language");
    int idx = languageList.indexWhere((v)
    => v.code == langId);
    language = languageList[idx >= 0 ? idx : 0];
    lastVersion = loadStorage("version");
    fmtDateForData = DateFormat("yyyy-MM-dd");
    fmtDateForDisplay = DateFormat(language.dateformat);
    glucMGDL = loadStorage("glucMGDL") != "false";
    canDebug = loadStorage("debug") == "yes";
    pdfSameWindow = loadStorage("pdfSameWindow") != "no";
    pdfDownload = loadStorage("pdfDownload") == "yes";
    hideNightscoutInPDF = loadStorage("hideNightscoutInPDF") == "yes";

    period = DatepickerPeriod(src: loadStorage("period"));
    period.fmtDate = language.dateformat;

    Date start = Date.today();
    Date end = Date.today();
    try
    {
      start = Date.parse(loadStorage("startDate") ?? Date.today().add(days: -7).format(fmtDateForData), fmtDateForData);
      end = Date.parse(loadStorage("endDate") ?? Date.today().format(fmtDateForData), fmtDateForData);
    }
    catch (ex)
    {}
    DatepickerDateRange dr = DatepickerDateRange(_dateRange.range.title, start, end);
    _dateRange = DatepickerComparison(dr, ComparisonOption.custom);
    changeLanguage(language, doReload: false);
    period.list.clear();
    period.list.add(DatepickerEntry("today", msgToday, (DatepickerPeriod data)
    {
      data.start = Date.today();
      data.end = Date.today();
    }));
    period.list.add(
      DatepickerEntry("2days", msgLast2Days, (DatepickerPeriod data)
      {
        data.start = Date.today().add(days: -1);
        data.end = Date.today();
      }));
    period.list.add(
      DatepickerEntry("3days", msgLast3Days, (DatepickerPeriod data)
      {
        data.start = Date.today().add(days: -2);
        data.end = Date.today();
      }));
    period.list.add(
      DatepickerEntry("1week", msgLastWeek, (DatepickerPeriod data)
      {
        data.start = Date.today().add(days: -6);
        data.end = Date.today();
      }));
    period.list.add(
      DatepickerEntry("2weeks", msgLast2Weeks, (DatepickerPeriod data)
      {
        data.start = Date.today().add(days: -13);
        data.end = Date.today();
      }));
    period.list.add(
      DatepickerEntry("3weeks", msgLast3Weeks, (DatepickerPeriod data)
      {
        data.start = Date.today().add(days: -20);
        data.end = Date.today();
      }));
    period.list.add(
      DatepickerEntry("1month", msgLastMonth, (DatepickerPeriod data)
      {
        data.start = Date.today().add(months: -1);
        data.end = Date.today();
      }));
    period.list.add(
      DatepickerEntry("3months", msgLast3Months, (DatepickerPeriod data)
      {
        data.start = Date.today().add(months: -3);
        data.end = Date.today();
      }));
  }

  void save()
  {
    String oldLang = loadStorage("language");
    clearStorage();
    saveStorage("version", version);
    if (canDebug)saveStorage("debug", "yes");
    if (!itod)saveStorage("unsafe", "zh++;");

    String save = "";
    for (int i = 0; i < userList.length; i++)
      save = "${save},${userList[i].asJson}";
    saveStorage("mu", Globals.doit("[${save.substring(1)}]"));

    saveStorage("userIdx", "$userIdx");
    bool doReload = (language.code != oldLang && language.code != null);
    saveStorage("glucMGDL", glucMGDL.toString());
    saveStorage("language", language.code ?? "de_DE");
    saveStorage("pdfSameWindow", pdfSameWindow ? "yes" : "no");
    saveStorage("pdfDownload", pdfDownload ? "yes" : "no");
    saveStorage("hideNightscoutInPDF", hideNightscoutInPDF ? "yes" : "no");
    saveStorage("period", period?.toString() ?? null);

    if (_dateRange.range != null)
    {
      if (_dateRange.range.start != null)saveStorage("startDate", _dateRange.range.start.format(fmtDateForData));
      if (_dateRange.range.end != null)saveStorage("endDate", _dateRange.range.end.format(fmtDateForData));
    }
    if (doReload)reload();
  }

  static tiod(String src)
  {
    if (!itod)return src ?? "";
    if (src == null || src.isEmpty)return "";

    String ret = "";
    int pos = src.length ~/ 2;
    src = "${src.substring(pos + 1)}${src.substring(0, pos - 1)}";
    try
    {
      convert.base64Decode(src).forEach((value)
      {
        ret = "${ret}${String.fromCharCode(value)}";
      });
    }
    catch (ex)
    {
      ret = "";
    }

    return ret;
  }

  static doit(String src)
  {
    if (!itod)return src;
    String ret = convert.base64Encode(src.codeUnits);
    int pos = ret.length ~/ 2;
    math.Random rnd = math.Random();
    String.fromCharCode(rnd.nextInt(26) + 64);
    ret =
    "${ret.substring(pos)}${String.fromCharCode(rnd.nextInt(26) + 64)}${String.fromCharCode(rnd.nextInt(10) + 48)}${ret
      .substring(0, pos)}";
    return ret;
  }

  static double percentile(List entries, int value)
  {
    double v = value / 100;
    List temp = List();
    // the entries must not be rearranged,
    // so we need a copy of this list
    for (var entry in entries)
      temp.add(entry);
    temp.sort((a, b)
    => a.gluc.compareTo(b.gluc));
    int N = temp.length;
    double n = (N - 1) * v + 1;
    if (n == 1)
    {
      return temp[0].gluc;
    }
    else if (n == N)
    {
      return temp[N - 1].gluc;
    }
    else
    {
      int k = n.toInt();
      double d = n - k;
      if (k > 0 && k < temp.length)return temp[k - 1].gluc + d * (temp[k].gluc - temp[k - 1].gluc);
      else
        return 0.0;
    }
  }
}

class UserData
{
  Globals g;
  String name = "";
  String birthDate = "";
  String storageApiUrl = "";
  String token = "";
  dynamic customData = Map<String, String>();
  dynamic formParams = {};
  String diaStartDate = "";
  String insulin = "";

//  Map<String, FormConfig> formList = Map<String, FormConfig>();

  UserData(this.g);

  String get display
  {
    return name.isEmpty ? storageApiUrl : name;
  }

  String get asJson
  {
    if (storageApiUrl.endsWith("/api/v1/"))storageApiUrl.replaceAll("/api/v1/", "");
    if (storageApiUrl.endsWith("/api/v1"))storageApiUrl.replaceAll("/api/v1", "");
    if (storageApiUrl == "null")storageApiUrl = null;
    Map<String, String> forms = Map<String, String>();
    try
    {
      for (FormConfig cfg in g.listConfig)
        forms[cfg.id] = cfg.asString;
    }
    catch (ex)
    {}

    return '{"n":"$name",'
      '"bd":"${birthDate ?? ''}",'
      '"ut":"${token ?? ''}",'
      '"u":"${storageApiUrl ?? ''}",'
      '"dd":"${diaStartDate ?? ''}",'
      '"i":"${insulin ?? ''}",'
      '"c":${convert.json.encode(customData)},'
      '"f":${convert.json.encode(forms)}'
      '}';
  }

  static UserData fromData(Globals g, var data)
  {
    UserData ret = UserData(g);
    try
    {
      ret.name = data["n"];
      ret.birthDate = data["bd"];
      ret.diaStartDate = data["dd"];
      ret.insulin = data["i"];
      ret.storageApiUrl = data["u"];
      ret.token = data["ut"];
      ret.customData = data["c"];
      ret.formParams = data["f"];
      if (ret.formParams != null && ret.formParams["analysis"] is bool)ret.formParams = {};
//      ret.formList = Map<String, FormConfig>();
/*
      for (String key in data["f"].keys)
      {
        FormConfig cfg = FormConfig(key, false);
        cfg.fillFromString(data["f"][key]);
        ret.formList[key] = cfg;
      }*/
    }
    catch (ex)
    {}
    return ret;
  }

  String get baseUrl
  {
    if (storageApiUrl == null || storageApiUrl.length < 8)return "";
    return storageApiUrl.substring(0, storageApiUrl.substring(8).indexOf("/") + 8);
  }

  String get apiUrl
  {
    String ret = storageApiUrl;
    if (ret != null)
    {
      if (ret.startsWith("@"))return ret.substring(1);
      if (!ret.endsWith("/"))ret = "$ret/";
      if (!ret.endsWith("/api/v1/")) ret = "${ret}api/v1/";
    }
    return ret;
  }

  String get reportUrl
  {
    String ret = storageApiUrl;
    if (ret != null)
    {
      if (!ret.endsWith("/"))ret = "$ret/";
    }
    return "${ret}report";
  }

  Future<String> get isValid
  async {
    if (storageApiUrl == null || apiUrl == null)return Intl.message("Die URL wurde noch nicht festgelegt");
    String ret = null;
    String check = "${apiUrl}status";
    await g.request(check).then((String response)
    {
      if (response != "<h1>STATUS OK</h1>")ret = g.msgUrlFailure;
    }).catchError((err)
    {
      ret = g.msgUrlFailure;
    });
    return ret;
  }
}