import 'package:flutter/material.dart';
import 'package:modbus_client/modbus_client.dart';
import 'package:modbus_client_tcp/modbus_client_tcp.dart';

void main() {
  runApp(const ModbusPocApp());
}

class ModbusPocApp extends StatelessWidget {
  const ModbusPocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Modbus TCP POC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const ModbusPocPage(),
    );
  }
}

class ModbusPocPage extends StatefulWidget {
  const ModbusPocPage({super.key});

  @override
  State<ModbusPocPage> createState() => _ModbusPocPageState();
}

class _ModbusPocPageState extends State<ModbusPocPage> {
  final ipController = TextEditingController(text: '192.168.1.125');
  final portController = TextEditingController(text: '502');

  // I will NOT assume Unit ID.
  // You must enter it from PLC Modbus settings.
  final unitIdController = TextEditingController();

  final writeRegisterController = TextEditingController(text: '40001');
  final writeValueController = TextEditingController();

  bool isBusy = false;
  String status = 'Ready';

  String reg40001Value = '-';
  String reg40002Value = '-';

  @override
  void dispose() {
    ipController.dispose();
    portController.dispose();
    unitIdController.dispose();
    writeRegisterController.dispose();
    writeValueController.dispose();
    super.dispose();
  }

  int? parseIntField(String value) {
    return int.tryParse(value.trim());
  }

  int holdingRegisterToAddress(int registerNumber) {
    // Standard Modbus notation:
    // 40001 => address 0
    // 40002 => address 1
    return registerNumber - 40001;
  }

  Future<void> readRegisters() async {
    final ip = ipController.text.trim();
    final port = parseIntField(portController.text);
    final unitId = parseIntField(unitIdController.text);

    if (ip.isEmpty || port == null || unitId == null) {
      setState(() {
        status = 'Missing data: IP, Port, and Unit ID are required.';
      });
      return;
    }

    setState(() {
      isBusy = true;
      status = 'Reading...';
    });

    final client = ModbusClientTcp(
      ip,
      serverPort: port,
      unitId: unitId,
      responseTimeout: const Duration(seconds: 3),
      connectionTimeout: const Duration(seconds: 3),
      delayAfterConnect: const Duration(milliseconds: 300),
    );

    final reg40001 = ModbusUint16Register(
      name: '40001',
      type: ModbusElementType.holdingRegister,
      address: holdingRegisterToAddress(40001),
    );

    final reg40002 = ModbusUint16Register(
      name: '40002',
      type: ModbusElementType.holdingRegister,
      address: holdingRegisterToAddress(40002),
    );

    try {
      await client.send(reg40001.getReadRequest());
      await client.send(reg40002.getReadRequest());

      setState(() {
        reg40001Value = reg40001.value?.toString() ?? '-';
        reg40002Value = reg40002.value?.toString() ?? '-';
        status = 'Read successful.';
      });
    } catch (e) {
      setState(() {
        status = 'Read error: $e';
      });
    } finally {
      client.disconnect();
      setState(() {
        isBusy = false;
      });
    }
  }

  Future<void> writeRegister() async {
    final ip = ipController.text.trim();
    final port = parseIntField(portController.text);
    final unitId = parseIntField(unitIdController.text);
    final registerNumber = parseIntField(writeRegisterController.text);
    final value = parseIntField(writeValueController.text);

    if (ip.isEmpty ||
        port == null ||
        unitId == null ||
        registerNumber == null ||
        value == null) {
      setState(() {
        status =
            'Missing data: IP, Port, Unit ID, Write Register, and Write Value are required.';
      });
      return;
    }

    if (registerNumber != 40001 && registerNumber != 40002) {
      setState(() {
        status = 'For this POC, write register must be 40001 or 40002 only.';
      });
      return;
    }

    if (value < 0 || value > 65535) {
      setState(() {
        status = 'Write value must be UINT16 range: 0 to 65535.';
      });
      return;
    }

    setState(() {
      isBusy = true;
      status = 'Writing...';
    });

    final client = ModbusClientTcp(
      ip,
      serverPort: port,
      unitId: unitId,
      responseTimeout: const Duration(seconds: 3),
      connectionTimeout: const Duration(seconds: 3),
      delayAfterConnect: const Duration(milliseconds: 300),
    );

    final register = ModbusUint16Register(
      name: registerNumber.toString(),
      type: ModbusElementType.holdingRegister,
      address: holdingRegisterToAddress(registerNumber),
    );

    try {
      final response = await client.send(
        register.getWriteRequest(value, rawValue: true),
      );

      setState(() {
        status = 'Write successful. Response: ${response.name}';
      });

      await readRegisters();
    } catch (e) {
      setState(() {
        status = 'Write error: $e';
      });
    } finally {
      client.disconnect();
      setState(() {
        isBusy = false;
      });
    }
  }

  Widget buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modbus TCP Read / Write POC')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        buildTextField(
                          label: 'PLC IP',
                          controller: ipController,
                        ),
                        const SizedBox(height: 12),
                        buildTextField(
                          label: 'Port',
                          controller: portController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        buildTextField(
                          label: 'Unit ID / Slave ID - required',
                          controller: unitIdController,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Read Holding Registers',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '40001 = $reg40001Value',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '40002 = $reg40002Value',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isBusy ? null : readRegisters,
                            child: const Text('Read 40001 and 40002'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Write Holding Register - UINT16 only',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        buildTextField(
                          label: 'Register to write: 40001 or 40002',
                          controller: writeRegisterController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        buildTextField(
                          label: 'Value to write: 0 to 65535',
                          controller: writeValueController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isBusy ? null : writeRegister,
                            child: const Text('Write Register'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(status, style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                ),

                if (isBusy) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
