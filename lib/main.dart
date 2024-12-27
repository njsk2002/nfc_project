import 'dart:async';
import 'dart:io' show Platform, sleep;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:logging/logging.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:ndef/utilities.dart';

import 'screen/raw_record_setting.dart';
import 'screen/text_record_setting.dart';
import 'screen/uri_record_setting.dart';

void main() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  runApp(MaterialApp(theme: ThemeData(useMaterial3: true), home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  String _platformVersion = ''; // 플랫폼 버전 정보
  NFCAvailability _availability = NFCAvailability.not_supported; // NFC 사용 가능 여부
  NFCTag? _tag; // 현재 NFC 태그 정보
  String? _result, _writeResult, _mifareResult; // NFC 작업 결과를 담는 변수
  late TabController _tabController; // 탭 컨트롤러
  List<ndef.NDEFRecord>? _records; // NFC 레코드 리스트

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  } // 위젯이 dispose 될 때 호출되는 메서드

  @override
  void initState() {
    super.initState();
    // 플랫폼 버전 정보 설정
    if (!kIsWeb)
      _platformVersion =
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    else
      _platformVersion = 'Web';
    initPlatformState(); // 플랫폼 초기화 함수 호출
    _tabController = new TabController(length: 2, vsync: this); // 탭 컨트롤러 초기화
    _records = []; // NFC 레코드 리스트 초기화
  } // 위젯 초기화 메서드

  // 플랫폼 초기화 비동기 메서드
  Future<void> initPlatformState() async {
    NFCAvailability availability;
    try {
      availability = await FlutterNfcKit.nfcAvailability;
    } on PlatformException {
      availability = NFCAvailability.not_supported;
    } // NFC 사용 가능 여부 확인

    // 애플리케이션이 마운트되어 있는지 확인 후 상태 업데이트
    if (!mounted) return;
    setState(() {
      // _platformVersion = platformVersion;
      _availability = availability;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
            title: const Text('NFC Flutter Kit Example App'),
            bottom: TabBar(
              tabs: <Widget>[
                Tab(text: 'Read'), // 읽기 탭
                Tab(text: 'Write'), // 쓰기 탭
              ],
              controller: _tabController, // 탭 컨트롤러 연결
            )),
        body: new TabBarView(controller: _tabController, children: <Widget>[
          // 읽기 탭
          Scrollbar(
              child: SingleChildScrollView(
                  child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const SizedBox(height: 20),
                            Text('Running on: $_platformVersion\nNFC: $_availability'),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  NFCTag tag = await FlutterNfcKit.poll();
                                  setState(() {
                                    _tag = tag;
                                  });
                                  await FlutterNfcKit.setIosAlertMessage(
                                      "Working on it..."); // iOS 알림 메시지 설정
                                  _mifareResult = null;
                                  if (tag.standard == "ISO 14443-4 (Type B)") {
                                    String result1 =
                                        await FlutterNfcKit.transceive("00B0950000");
                                    String result2 = await FlutterNfcKit.transceive(
                                        "00A4040009A00000000386980701");
                                    setState(() {
                                      _result = '1: $result1\n2: $result2\n'; // 결과 업데이트
                                    });
                                  } else if (tag.type == NFCTagType.iso18092) {
                                    String result1 =
                                        await FlutterNfcKit.transceive("060080080100");
                                    setState(() {
                                      _result = '1: $result1\n'; // 결과 업데이트
                                    });
                                  } else if (tag.ndefAvailable ?? false) {
                                    var ndefRecords = await FlutterNfcKit.readNDEFRecords();
                                    var ndefString = '';
                                    for (int i = 0; i < ndefRecords.length; i++) {
                                      ndefString +=
                                          '${i + 1}: ${ndefRecords[i]}\n'; // NDEF 레코드 정보 업데이트
                                    }
                                    setState(() {
                                      _result = ndefString; // 결과 업데이트
                                    });
                                  } else if (tag.type == NFCTagType.webusb) {
                                    var r = await FlutterNfcKit.transceive(
                                        "00A4040006D27600012401");
                                    print(r);
                                  }
                                } catch (e) {
                                  setState(() {
                                    _result = 'error: $e';
                                  });
                                }

                                // Pretend that we are working
                                if (!kIsWeb) sleep(new Duration(seconds: 1));
                                await FlutterNfcKit.finish(iosAlertMessage: "Finished!");
                              },
                  child: Text('Start polling'), // NFC 폴링 시작 버튼
                ),
                const SizedBox(height: 10),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _tag != null
                        ? Text(
                            'ID: ${_tag!.id}\nStandard: ${_tag!.standard}\nType: ${_tag!.type}\nATQA: ${_tag!.atqa}\nSAK: ${_tag!.sak}\nHistorical Bytes: ${_tag!.historicalBytes}\nProtocol Info: ${_tag!.protocolInfo}\nApplication Data: ${_tag!.applicationData}\nHigher Layer Response: ${_tag!.hiLayerResponse}\nManufacturer: ${_tag!.manufacturer}\nSystem Code: ${_tag!.systemCode}\nDSF ID: ${_tag!.dsfId}\nNDEF Available: ${_tag!.ndefAvailable}\nNDEF Type: ${_tag!.ndefType}\nNDEF Writable: ${_tag!.ndefWritable}\nNDEF Can Make Read Only: ${_tag!.ndefCanMakeReadOnly}\nNDEF Capacity: ${_tag!.ndefCapacity}\nMifare Info:${_tag!.mifareInfo} Transceive Result:\n$_result\n\nBlock Message:\n$_mifareResult')
                        : const Text('No tag polled yet.')),
                // NFC 태그 정보 표시
              ])))),
          // 쓰기 탭
          Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: () async {
                          if (_records!.length != 0) {
                            try {
                              NFCTag tag = await FlutterNfcKit.poll();
                              setState(() {
                                _tag = tag;
                              });
                              if (tag.type == NFCTagType.mifare_ultralight ||
                                  tag.type == NFCTagType.mifare_classic ||
                                  tag.type == NFCTagType.iso15693) {
                                await FlutterNfcKit.writeNDEFRecords(_records!);
                                setState(() {
                                  _writeResult = 'OK';
                                });
                              } else {
                                setState(() {
                                  _writeResult =
                                      'error: NDEF not supported: ${tag.type}';
                                });
                              }
                            } catch (e, stacktrace) {
                              setState(() {
                                _writeResult = 'error: $e';
                              });
                              print(stacktrace);
                            } finally {
                              await FlutterNfcKit.finish();
                            }
                          } else {
                            setState(() {
                              _writeResult = 'error: No record';
                            });
                          }
                        },
                        child: Text("Start writing"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return SimpleDialog(
                                    title: Text("Record Type"),
                                    // 레코드 타입 선택 다이얼로그 타이틀
                                    children: <Widget>[
                                      SimpleDialogOption(
                                        child: Text("Text Record"),
                                        // 텍스트 레코드 옵션
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final result = await Navigator.push(
                                              context, MaterialPageRoute(
                                                  builder: (context) {
                                            return NDEFTextRecordSetting();
                                          }));
                                          if (result != null) {
                                            if (result is ndef.TextRecord) {
                                              setState(() {
                                                _records!.add(result);
                                              });
                                            }
                                          }
                                        },
                                      ),
                                      SimpleDialogOption(
                                        child: Text("Uri Record"), // URI 레코드 옵션
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final result = await Navigator.push(
                                              context, MaterialPageRoute(
                                                  builder: (context) {
                                            return NDEFUriRecordSetting();
                                          }));
                                          if (result != null) {
                                            if (result is ndef.UriRecord) {
                                              setState(() {
                                                _records!.add(result);
                                              });
                                            }
                                          }
                                        },
                                      ),
                                      SimpleDialogOption(
                                        child: Text("Raw Record"), // Raw 레코드 옵션
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final result = await Navigator.push(
                                              context, MaterialPageRoute(
                                                  builder: (context) {
                                            return NDEFRecordSetting();
                                          }));
                                          if (result != null) {
                                            if (result is ndef.NDEFRecord) {
                                              setState(() {
                                                _records!.add(result);
                                              });
                                            }
                                          }
                                        },
                                      ),
                                    ]);
                              });
                        },
                        child: Text("Add record"),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Result: $_writeResult'),
                  const SizedBox(height: 10),
                  Expanded(
                    flex: 1,
                    child: ListView(
                        shrinkWrap: true,
                        children: List<Widget>.generate(
                            _records!.length,
                            (index) => GestureDetector(
                                  child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Text(
                                          'id:${_records![index].idString}\ntnf:${_records![index].tnf}\ntype:${_records![index].type?.toHexString()}\npayload:${_records![index].payload?.toHexString()}\n')),
                                  onTap: () async {
                                    final result = await Navigator.push(context,
                                        MaterialPageRoute(builder: (context) {
                                      return NDEFRecordSetting(
                                          record: _records![index]);
                                    }));
                                    if (result != null) {
                                      if (result is ndef.NDEFRecord) {
                                        setState(() {
                                          _records![index] = result;
                                        });
                                      } else if (result is String &&
                                          result == "Delete") {
                                        _records!.removeAt(index);
                                      }
                                    }
                                  },
                                ))),
                  ),
                ]),
          )
        ]),
      ),
    );
  }
}
