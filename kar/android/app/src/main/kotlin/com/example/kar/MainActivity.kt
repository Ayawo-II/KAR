package com.example.kar

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * `FlutterFragmentActivity` et non `FlutterActivity` : la boite de dialogue de
 * `local_auth` a besoin d'un FragmentActivity pour afficher la securite de
 * l'appareil (empreinte, visage, code).
 */
class MainActivity : FlutterFragmentActivity()