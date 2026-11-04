# iWindoor Mobil + Masaüstü (Flutter)

Pencere/kapı tasarım uygulaması. Aynı kod Android, iOS, Windows, macOS ve Linux'ta çalışır.

## Yapı

```
packages/windoor_core/   saf Dart çekirdek: tasarım modeli, düzenleme işlemleri, çizim motoru, kesim listesi (+ testler)
lib/drawing/             çizici (kasa, kanat, kayıt, cam çıtası, cam görünümleri, ölçüler) ve tuval
lib/screens/design_editor/  yeni editör: araç kutusu, özellik paneli, kesim listesi / teklif
lib/services/design_api.dart  backend: katalog paketi, pencere belgesi (GET/PUT /api/v1/windows/{id})
lib/config/app_config.dart    sunucu adresi (giriş ekranındaki ağ simgesinden değiştirilir)
```

Çizim ve hesap cihazda yapılır; sunucuya sadece **Kaydet** ile gidilir (belge + kesim listesi).
Kesim listesi backend'in fiyatlandırdığı biçimdedir (`group/role/length/w/h/qty/glassCode`).

## Çalıştırma

```bash
flutter pub get
flutter run -d windows          # masaüstü (sunucu varsayılanı http://localhost:8080)
flutter run -d <telefon>        # telefon (varsayılan http://192.168.0.37:8080; giriş ekranından değiştir)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emülatörü
```

## Testler

```bash
cd packages/windoor_core && dart test     # çizim motoru, düzenleme işlemleri, kesim listesi
flutter test                              # tuval: çizim + dokunarak seçim
```
Çekirdek testlerindeki sayılar (kasa 1806/1706, kanat 542/1220, cam 408×1086, profil 7,024 m...)
backend'in fiyat testleriyle birebir aynı pencereye aittir.

## Editör

- Çizimde bir cam alanına dokun → araç kutusundan böl (dikey/yatay 2-3), açılım seç (sabit, açılır sol/sağ,
  vasistas, çift açılım sol/sağ, sürme), sağ panelden cam/panel, dubleks, bölme ölçüleri, pencere ölçüsü, seri, renk.
- Geri al / ileri al: Ctrl+Z / Ctrl+Y, kaydet: Ctrl+S (masaüstü).
- Aynı pencere başka cihazda kaydedildiyse "güncel hâli yükle / üzerine yaz" sorulur.
- Eski (düğüm tabanlı) pencereler açılınca otomatik dönüştürülür; ilk kayıtta yeni biçime geçer.

`lib/screens/window_editor_screen.dart` ve `lib/widgets/window_painter.dart` eski editördür, artık kullanılmıyor;
geçiş testlerden sonra silinebilir.
