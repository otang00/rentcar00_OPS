import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImsReturnInputResult {
  const ImsReturnInputResult({
    required this.returnGasCharge,
    required this.drivenDistanceUponReturn,
    required this.fuelCost,
  });

  final int returnGasCharge;
  final String drivenDistanceUponReturn;
  final int fuelCost;
}

class ImsReturnInputDialog extends StatefulWidget {
  const ImsReturnInputDialog({super.key});

  @override
  State<ImsReturnInputDialog> createState() => _ImsReturnInputDialogState();
}

class _ImsReturnInputDialogState extends State<ImsReturnInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _returnGasChargeController = TextEditingController();
  final _drivenDistanceController = TextEditingController();
  final _fuelCostController = TextEditingController();

  @override
  void dispose() {
    _returnGasChargeController.dispose();
    _drivenDistanceController.dispose();
    _fuelCostController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      ImsReturnInputResult(
        returnGasCharge: int.parse(_returnGasChargeController.text.trim()),
        drivenDistanceUponReturn: _drivenDistanceController.text.trim(),
        fuelCost: int.parse(_fuelCostController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('IMS 반납 정보 입력'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _returnGasChargeController,
                decoration: const InputDecoration(
                  labelText: '반납 유류량',
                  hintText: '예: 70',
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _gasChargeValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _drivenDistanceController,
                decoration: const InputDecoration(
                  labelText: '반납 주행거리',
                  hintText: '예: 70483',
                  suffixText: 'km',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _positiveNumberTextValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fuelCostController,
                decoration: const InputDecoration(
                  labelText: '유류비',
                  hintText: '예: -7010',
                  suffixText: '원',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[-0-9]')),
                ],
                validator: _signedNumberTextValidator,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('계속')),
      ],
    );
  }
}

String? _gasChargeValidator(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return '필수 입력입니다.';
  final number = int.tryParse(text);
  if (number == null || number < 0 || number > 100) {
    return '0~100 사이 숫자를 입력하세요.';
  }
  return null;
}

String? _positiveNumberTextValidator(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return '필수 입력입니다.';
  final number = int.tryParse(text);
  if (number == null || number <= 0) return '0보다 큰 숫자를 입력하세요.';
  return null;
}

String? _signedNumberTextValidator(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return '필수 입력입니다.';
  if (int.tryParse(text) == null) return '숫자를 입력하세요.';
  return null;
}
