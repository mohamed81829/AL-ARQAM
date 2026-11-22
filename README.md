# الأرقم (AL-ARQAM)

تطبيق موبايل للعبادات اليومية، مبني بـ Flutter.

## المميزات الحالية (v0.1)
- مواقيت الصلاة حسب موقعك (طريقة الهيئة المصرية، وافتراضي القاهرة لو الموقع مرفوض)
- الأذكار: الصباح والمساء، وبعد الصلاة، مع عدّاد لكل ذكر
- مسبحة إلكترونية بتحفظ العدد

## التشغيل
```bash
flutter create --org com.alarqam --project-name al_arqam --platforms=android .
flutter pub get
flutter run
```
بعد `flutter create` أضف صلاحيات الموقع في `android/app/src/main/AndroidManifest.xml` داخل `<manifest>`:
```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

## الخطوات الجاية
- إشعارات الأذان، اتجاه القبلة، تتبّع الصلوات اليومية، المصحف.
