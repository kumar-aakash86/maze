import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

// ignore: import_of_legacy_library_into_null_safe
import 'package:joystick/joystick.dart';
import 'package:control_pad/control_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:universal_io/io.dart';

import 'maze_painter.dart';
import 'models/item.dart';

///Control types
enum ControlType {
  /// Touch controls
  touch,

  /// Joystick controls
  joystick,

  /// Both controls
  both
}

///Maze
///
///Create a simple but powerfull maze game
///You can customize [wallColor], [wallThickness],
///[columns] and [rows]. A [player] is required and also
///you can pass a List of [checkpoints] and you will be notified
///if the player pass through a checkout at [onCheckpoint]
class Maze extends StatefulWidget {
  ///Default constructor
  Maze({
    required this.player,
    this.checkpoints = const [],
    this.columns = 10,
    this.finish,
    this.height,
    this.loadingWidget,
    this.onCheckpoint,
    this.onFinish,
    this.rows = 7,
    this.wallColor = Colors.black,
    this.wallThickness = 3.0,
    this.width,
    this.mazeBackgroundColor = Colors.transparent,
    this.controlType = ControlType.touch,
  });

  ///List of checkpoints
  final List<MazeItem> checkpoints;

  ///Columns of the maze
  final int columns;

  ///The finish image
  final MazeItem? finish;

  ///Height of the maze
  final double? height;

  ///A widget to show while loading all
  final Widget? loadingWidget;

  ///Callback when the player pass through a checkpoint
  final Function(int)? onCheckpoint;

  ///Callback when the player reach finish
  final Function()? onFinish;

  ///The main player
  final MazeItem player;

  ///Rows of the maze
  final int rows;

  ///Wall color
  final Color? wallColor;

  ///Wall thickness
  ///
  ///Default: 3.0
  final double? wallThickness;

  ///Width of the maze
  final double? width;

  ///Background color of maze
  final Color mazeBackgroundColor;

  ///Control Types
  final ControlType controlType;

  @override
  _MazeState createState() => _MazeState();
}

class _MazeState extends State<Maze> {
  bool _loaded = false;
  late MazePainter _mazePainter;

  @override
  void initState() {
    super.initState();
    setUp();
  }

  void setUp() async {
    final playerImage = await _itemToImage(widget.player);
    final checkpoints = await Future.wait(
        widget.checkpoints.map((c) async => await _itemToImage(c)));
    final finishImage =
        widget.finish != null ? await _itemToImage(widget.finish!) : null;

    _mazePainter = MazePainter(
      checkpointsImages: checkpoints,
      columns: widget.columns,
      finishImage: finishImage,
      onCheckpoint: widget.onCheckpoint,
      onFinish: widget.onFinish,
      playerImage: playerImage,
      rows: widget.rows,
      wallColor: widget.wallColor ?? Colors.black,
      wallThickness: widget.wallThickness ?? 4.0,
      mazeBackgroundColor: widget.mazeBackgroundColor,
    );
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      child: Stack(
        // mainAxisSize: MainAxisSize.max,
        children: [
          Builder(builder: (context) {
            if (_loaded) {
              return AbsorbPointer(
                absorbing: widget.controlType == ControlType.joystick,
                child: GestureDetector(
                    onVerticalDragUpdate: (info) =>
                        _mazePainter.updatePosition(info.localPosition),
                    child: CustomPaint(
                        painter: _mazePainter,
                        size: Size(widget.width ?? context.width,
                            widget.height ?? context.height))),
              );
            } else {
              if (widget.loadingWidget != null) {
                return widget.loadingWidget!;
              } else {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
            }
          }),
          widget.controlType != ControlType.touch ? getJoyStick() : Container(),
        ],
      ),
    );
  }

  Widget getJoyStick() {
    var now = DateTime.now().millisecondsSinceEpoch;
    var _joystickLeft = context.width / 2 - 100;
    var _joystickTop = context.height / 2 - 100;
    return StatefulBuilder(builder: (context, setState) {
      return Positioned(
        left: _joystickLeft,
        top: _joystickTop,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _joystickLeft = details.globalPosition.dx - 200;
              _joystickTop = details.globalPosition.dy;
            });
          },
          // onHorizontalDragUpdate: (details) {
          //   setState(() {
          //     _joystickTop = details.localPosition.dy - 100;
          //   });
          // },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.drag_handle),
              JoystickView(
                size: 200,
                opacity: .3,
                onDirectionChanged: (double degrees, double disFromCenter) {
                  var radians = degrees * pi / 180;
                  var x = cos(radians) * disFromCenter;
                  var y = sin(radians) * disFromCenter;

                  Direction? direction = null;
                  if (x > 0.1)
                    direction = Direction.up;
                  else if (x < -0.1)
                    direction = Direction.down;
                  else if (y > 0.1)
                    direction = Direction.right;
                  else if (y < -0.1) direction = Direction.left;

                  // print('DIRECTION $direction');
                  // print(
                  //     '$degrees / $disFromCenter  $x == $y  / ${MediaQuery.of(context).size.width / 2}');
                  // _mazePainter.updatePositionByXY(x, y);

                  if (direction != null &&
                      (DateTime.now().millisecondsSinceEpoch - now) > 1000) {
                    _mazePainter.movePlayer(direction);
                  }
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget getJoyStick2() {
    return Joystick(
        size: 100,
        isDraggable: false,
        iconColor: Colors.amber,
        backgroundColor: Colors.black,
        opacity: 0.5,
        joystickMode: JoystickModes.all,
        onUpPressed: () {
          _mazePainter.movePlayer(Direction.up);
        },
        onLeftPressed: () {
          _mazePainter.movePlayer(Direction.left);
        },
        onRightPressed: () {
          _mazePainter.movePlayer(Direction.right);
        },
        onDownPressed: () {
          _mazePainter.movePlayer(Direction.down);
        },
        onPressed: (_direction) {
          // print("pressed $_direction");
        });
  }

  Future<ui.Image> _itemToImage(MazeItem item) {
    switch (item.type) {
      case ImageType.file:
        return _fileToByte(item.path);
      case ImageType.network:
        return _networkToByte(item.path);
      default:
        return _assetToByte(item.path);
    }
  }

  ///Creates a Image from file
  Future<ui.Image> _fileToByte(String path) async {
    final completer = Completer<ui.Image>();
    final bytes = await File(path).readAsBytes();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  ///Creates a Image from asset
  Future<ui.Image> _assetToByte(String asset) async {
    final completer = Completer<ui.Image>();
    final bytes = await rootBundle.load(asset);
    ui.decodeImageFromList(bytes.buffer.asUint8List(), completer.complete);
    return completer.future;
  }

  ///Creates a Image from network
  Future<ui.Image> _networkToByte(String url) async {
    final completer = Completer<ui.Image>();
    final response = await http.get(Uri.parse(url));
    ui.decodeImageFromList(
        response.bodyBytes.buffer.asUint8List(), completer.complete);
    return completer.future;
  }
}

///Extension to get screen size
extension ScreenSizeExtension on BuildContext {
  ///Gets the current height
  double get height => MediaQuery.of(this).size.height;

  ///Gets the current width
  double get width => MediaQuery.of(this).size.width;
}
