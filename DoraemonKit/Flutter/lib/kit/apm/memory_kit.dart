import 'dart:ui';

import 'package:dokit/util/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart';

import '../../dokit.dart';
import 'apm.dart';
import 'vm_helper.dart';

class MemoryInfo implements IInfo {
  int fps;
  String pageName;

  @override
  int getValue() {
    return fps;
  }
}

class MemoryKit extends ApmKit {
  int lastFrame = 0;

  @override
  String getKitName() {
    return ApmKitName.KIT_MEMORY;
  }

  @override
  String getIcon() {
    return 'images/dk_ram.png';
  }

  @override
  Future<void> start() async {
    final VmHelper vmHelper = VmHelper.instance;
    await vmHelper.startConnect();
    vmHelper.updateMemoryUsage();

    return Future<void>.value();
  }

  void update() {
    VmHelper.instance.dumpAllocationProfile();
    VmHelper.instance.resolveFlutterVersion();
    VmHelper.instance.updateMemoryUsage();
  }

  AllocationProfile getAllocationProfile() {
    return VmHelper.instance.allocationProfile;
  }

  @override
  void stop() {
    VmHelper.instance.disConnect();
  }

  @override
  IStorage createStorage() {
    return CommonStorage(maxCount: 120);
  }

  @override
  Widget createDisplayPage() {
    return MemoryPage();
  }
}

class MemoryPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return MemoryPageState();
  }
}

class MemoryPageState extends State<MemoryPage> {
  MemoryKit kit =
      ApmKitManager.instance.getKit<MemoryKit>(ApmKitName.KIT_MEMORY);
  List<ClassHeapStats> heaps = <ClassHeapStats>[];
  TextEditingController editingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    kit.update();
    initHeaps();
  }

  void initHeaps() {
    if (kit.getAllocationProfile() != null) {
      kit.getAllocationProfile().members.sort(
          (ClassHeapStats left, ClassHeapStats right) =>
              right.bytesCurrent.compareTo(left.bytesCurrent));
      kit.getAllocationProfile().members.forEach((ClassHeapStats element) {
        if (heaps.length < 32) {
          heaps.add(element);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Container(
            margin: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Memory Info',
                          style: TextStyle(
                              color: Color(0xff333333),
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      StreamBuilder<dynamic>(
                        stream: Stream<dynamic>.periodic(
                            const Duration(seconds: 2), (int value) {
                          VmHelper.instance.dumpAllocationProfile();
                          VmHelper.instance.updateMemoryUsage();
                        }),
                        builder: (BuildContext context,
                            AsyncSnapshot<dynamic> snapshot) {
                          return Container(
                            margin: const EdgeInsets.only(top: 3),
                            alignment: Alignment.topLeft,
                            child: VmHelper.instance.memoryInfo != null &&
                                    VmHelper.instance.memoryInfo.isNotEmpty
                                ? Column(
                                    children: getMemoryInfo(
                                        VmHelper.instance.memoryInfo))
                                : const Text('??????Memory????????????(release???????????????????????????)',
                                    style: TextStyle(
                                        color: Color(0xff999999),
                                        fontSize: 12)),
                          );
                        },
                      )
                    ]),
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 13),
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xff337cc4),
                        width: 0.5,
                        style: BorderStyle.solid),
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        child: TextField(
                          controller: editingController,
                          style: const TextStyle(
                              color: Color(0xff333333), fontSize: 16),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.deny(
                              RegExp(
                                  '[^\\u0020-\\u007E\\u00A0-\\u00BE\\u2E80-\\uA4CF\\uF900-\\uFAFF\\uFE30-\\uFE4F\\uFF00-\\uFFEF\\u0080-\\u009F\\u2000-\\u201f\r\n]'),
                            )
                          ],
                          onSubmitted: (String value) {
                            filterAllocations();
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                                color: Color(0xffbebebe), fontSize: 16),
                            hintText: '?????????????????????????????????',
                          ),
                        ),
                        width: MediaQuery.of(context).size.width - 150,
                      ),
                      Container(
                        width: 60,
                        child: FlatButton(
                          padding: const EdgeInsets.only(
                              left: 15, right: 0, top: 15, bottom: 15),
                          child: Image.asset('images/dk_memory_search.png',
                              package: DoKit.PACKAGE_NAME,
                              height: 16,
                              width: 16),
                          onPressed: filterAllocations,
                        ),
                      )
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  height: 34,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 80,
                        decoration: const BoxDecoration(
                            color: Color(0xff337cc4),
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(4),
                                bottomLeft: Radius.circular(4))),
                        alignment: Alignment.center,
                        child: const Text('Size',
                            style: TextStyle(
                                color: Color(0xffffffff), fontSize: 14)),
                      ),
                      const VerticalDivider(
                        width: 0.5,
                        color: Color(0xffffffff),
                      ),
                      Container(
                        width: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xff337cc4),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Count',
                            style: TextStyle(
                                color: Color(0xffffffff), fontSize: 14)),
                      ),
                      const VerticalDivider(
                        width: 0.5,
                        color: Color(0xffffffff),
                      ),
                      Container(
                          decoration: const BoxDecoration(
                              color: Color(0xff337cc4),
                              borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(4),
                                  bottomRight: Radius.circular(4))),
                          width: MediaQuery.of(context).size.width - 193,
                          alignment: Alignment.center,
                          child: const Text('ClassName',
                              style: TextStyle(
                                  color: Color(0xffffffff), fontSize: 14))),
                    ],
                  ),
                ),
                Container(
                  height: MediaQuery.of(context).size.height - 200 - 210,
                  child: ListView.builder(
                      padding: const EdgeInsets.all(0),
                      itemCount: heaps.length,
                      itemBuilder: (BuildContext context, int index) {
                        return HeapItemWidget(
                          item: heaps[index],
                          index: index,
                        );
                      }),
                ),
              ],
            )));
  }

  void filterAllocations() {
    final String className = editingController.text;
    assert(className != null);
    heaps.clear();
    if (className.length >= 3 && kit.getAllocationProfile() != null) {
      kit.getAllocationProfile().members.forEach((ClassHeapStats element) {
        if (element.classRef.name
            .toLowerCase()
            .contains(className.toLowerCase())) {
          heaps.add(element);
        }
      });
      heaps.sort((ClassHeapStats left, ClassHeapStats right) =>
          right.bytesCurrent.compareTo(left.bytesCurrent));
    }
    setState(() {});
  }

  List<Widget> getMemoryInfo(Map<IsolateRef, MemoryUsage> map) {
    final List<Widget> widgets = <Widget>[];
    map.forEach((IsolateRef key, MemoryUsage value) {
      widgets.add(RichText(
          text: TextSpan(children: <TextSpan>[
        const TextSpan(
            text: 'IsolateName: ',
            style:
                TextStyle(fontSize: 10, color: Color(0xff333333), height: 1.5)),
        TextSpan(
            text: key.name,
            style: const TextStyle(
                fontSize: 10, height: 1.5, color: Color(0xff666666))),
        const TextSpan(
            text: '\nHeapUsage: ',
            style:
                TextStyle(height: 1.5, fontSize: 10, color: Color(0xff333333))),
        TextSpan(
            text: ByteUtil.toByteString(value.heapUsage),
            style: const TextStyle(
                fontSize: 10, height: 1.5, color: Color(0xff666666))),
        const TextSpan(
            text: '\nHeapCapacity: ',
            style:
                TextStyle(fontSize: 10, height: 1.5, color: Color(0xff333333))),
        TextSpan(
            text: ByteUtil.toByteString(value.heapCapacity),
            style: const TextStyle(
                fontSize: 10, height: 1.5, color: Color(0xff666666))),
        const TextSpan(
            text: '\nExternalUsage: ',
            style:
                TextStyle(fontSize: 10, height: 1.5, color: Color(0xff333333))),
        TextSpan(
            text: ByteUtil.toByteString(value.externalUsage),
            style: const TextStyle(
                fontSize: 10, height: 1.5, color: Color(0xff666666))),
      ])));
    });
    return widgets;
  }
}

class HeapItemWidget extends StatelessWidget {
  const HeapItemWidget({Key key, @required this.item, @required this.index})
      : super(key: key);

  final ClassHeapStats item;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: index % 2 == 1 ? const Color(0xfffafafa) : Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 80,
            alignment: Alignment.center,
            child: Text(ByteUtil.toByteString(item.bytesCurrent),
                style: const TextStyle(color: Color(0xff333333), fontSize: 12)),
          ),
          Container(
            width: 80,
            alignment: Alignment.center,
            child: Text('${item.instancesCurrent}',
                style: const TextStyle(color: Color(0xff333333), fontSize: 12)),
          ),
          Container(
              width: MediaQuery.of(context).size.width - 193,
              alignment: Alignment.center,
              child: Text(item.classRef.name,
                  style:
                      const TextStyle(color: Color(0xff333333), fontSize: 12))),
        ],
      ),
    );
  }
}
