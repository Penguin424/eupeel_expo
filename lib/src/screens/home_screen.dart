import 'package:animated_background/animated_background.dart';
// import 'package:eupeel_expo/src/models/producto_cosbiome_model.dart';
import 'package:eupeel_expo/src/providers/almacen_provider.dart';
import 'package:eupeel_expo/src/providers/nfc_provider.dart';
import 'package:eupeel_expo/src/providers/venta_provider.dart';
// import 'package:eupeel_expo/src/services/nfc_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    final nfc = ref.read(nfcProvider);
    final venta = ref.read(ventaProvider);
    final almacen = ref.read(almacenProvider);

    Future.delayed(Duration.zero, () {
      venta.isRedirectToCheckOut = true;
      nfc.toggleAutoLoop(context, true);
      almacen.handleGetProductos();
    });
  }

  @override
  Widget build(BuildContext context) {
    // final nfc = ref.watch(nfcProvider);
    // final venta = ref.read(ventaProvider);
    final size = MediaQuery.of(context).size;

    // print("ESTADO DE LECTURA NFC: ${nfc.status}");

    // if (nfc.status == "¡Lectura Auto Exitosa!") {
    //   venta.handleAddProductoEupeel(
    //     context: context,
    //     almacen: "enExpo",
    //     producto: ProductoCosbiomeModel(
    //       id: nfc.readText,
    //     ),
    //     cantidad: 1,
    //   );
    // }

    return Scaffold(
      backgroundColor: Colors.white,

      body: AnimatedBackground(
        behaviour: RandomParticleBehaviour(
          options: ParticleOptions(
            baseColor: Colors.grey.shade400,
            spawnMinRadius: 40.0,
            spawnMaxRadius: 90.0,
            spawnMaxSpeed: 100.0,
            spawnMinSpeed: 30.0,
            particleCount: 70,
          ),
        ),
        vsync: this,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Escanea tu producto Eupeel',
                  style: TextStyle(
                    fontSize: size.width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    //Here goes the same radius, u can put into a var or function
                    borderRadius: BorderRadius.circular(600),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x54000000),
                        spreadRadius: 2,
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(250),

                    child: CircleAvatar(
                      backgroundColor: Colors.white,

                      radius: size.width * 0.2,
                      child: Hero(
                        tag: 'eupeel_logo_png',
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, "/checkout");
                          },
                          child: Image.asset(
                            'assets/images/eupeel_logo.png',
                            width: size.width * 0.6,
                            height: size.height * 0.4,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
