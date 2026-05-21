import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service.dart';

void main() {
  test('restart HTTP/2 transport close is recoverable', () {
    const recoverableError = GrpcError.unknown(
      'HTTP/2 error: Connection error: Connection is being forcefully terminated. (errorCode: 1)',
    );
    const realError = GrpcError.unknown('permission denied');

    expect(isRecoverableRestartGrpcDisconnect(recoverableError), isTrue);
    expect(isRecoverableRestartGrpcDisconnect(realError), isFalse);
  });
}
