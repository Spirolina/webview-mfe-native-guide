# Faz 6 — Kalıcı paylaşılan WebView (native-only)

**En yüksek tavan, en yüksek maliyet.** İki bağımsız üretim sistemi bu mimariye
ulaştı — bu rehberdeki en güçlü mimari sinyal.

**Süre:** 1-2 çeyrek · **Risk:** yüksek (mimari) · **Geri alınabilir:** zor

---

## 6.1 Yakınsayan kanıt

| Desen | Hotwire Native (Basecamp/HEY) | Shopify Mobile Bridge (~600 ekran) |
|---|---|---|
| WebView yaşam döngüsü | Navigation stack başına **tek** paylaşılan `WKWebView` | Havuzlanır, kullanıldıktan sonra **atılmaz** |
| Ekranlar arası geçiş | `VisitableView`'lar arasında **re-parent** | `TransportableView` — *"without losing state or data"* |
| Beyaz ekran önleme | Ayrılan ekranda render edilmiş **screenshot** bırakılır | Geçişten önce WebView'in **anlık görüntüsü** alınır |
| Yayımlanmış rakam | yok | P75 6 sn → 1.4 sn (paket sonucu) |

Kaynaklar: [Hotwire Native iOS](https://native.hotwired.dev/ios/reference) ·
[Shopify Engineering](https://shopify.engineering/mobilebridge-native-webviews)

> ⚠️ Hotwire kanıtı **server-rendered Turbo/HTML** bağlamındandır, React SPA değil.
> Mimari transfer edilebilir; performans rakamı yoktur.

---

## 6.2 Faz 3'ten farkı

| | Faz 3 (sıcak havuz) | Faz 6 (kalıcı paylaşılan) |
|---|---|---|
| Ekran kapandığında | WebView atılır, yenisi ısıtılır | WebView **kalır**, route ısınma hedefine döner |
| Isınma maliyeti | Her ekran açılışından sonra tekrar ödenir | **Bir kez** ödenir |
| Ekranlar arası state | Kaybolur | **Korunur** (HTTP cache, auth context, React state) |
| Geri navigasyonu | Yeniden yükleme | Screenshot → anında |
| Bellek | Kullanım anında 1 instance | Sürekli 1 instance |
| Bağımsız deployability | Korunur | **Zayıflar** (tek shell'e giderseniz) |

> **Referans ölçümde Faz 6, Faz 3'ten anlamlı biçimde iyi çıkmadı (565 vs 565 ms).**
> Sebep: o düzenekte Faz 3 de her koşudan önce yeniden ısıtılıyordu ve **ısınma
> süresi ölçüme girmiyordu.** Kalıcı modelin asıl avantajı ısınmayı hiç
> tekrarlamamaktır — bunu görmek için ısınma maliyetini de sayan bir senaryo gerekir.
>
> **Kendi ölçümünüzde bunu ayırın:** kullanıcı ard arda 5 ekran açtığında toplam
> süre nedir?

---

## 6.3 Üç uygulama modeli — ikisi native, biri kapsam dışı

### Model A — Stack başına paylaşılan WebView (Hotwire'ın birebir karşılığı) ✅ native
Her navigation stack bir WebView tutar, ekranlar arasında re-parent edilir.
Microfrontend'ler hâlâ ayrı SPA'lar olabilir ve **kodlarına dokunulmaz.**

- ✅ Tamamen native tarafta uygulanır
- ✅ Bağımsız deployability korunur
- ✅ Mimari risk düşük
- ⚠️ Farklı microfrontend'ler arası geçişte JS boot hâlâ ödenir (ayrı origin/bundle)

### Model B — Tek shell + client-side route swap ❌ KAPSAM DIŞI
Tüm microfrontend'lerin tek bir shell uygulamasının lazy modülleri hâline
getirilmesi. En yüksek tavan, **ama tamamen bir web mimarisi değişikliğidir** —
native ekibin yapabileceği bir şey yoktur.

Değerlendirmeye alınacaksa [`09-web-sozlesmesi.md`](09-web-sozlesmesi.md)'deki
talep ve risk listesine bakın. **Bu rehberdeki hiçbir adım bunu içermez.**

### Model C — Warm pool (Faz 3'te zaten yaptınız) ✅ native
En az invaziv. Ekran açılışında WebView yaratma maliyeti kalkar.

**Hangisi?** Faz 1 tablonuza bakın:

| Ölçüm sonucu | Model |
|---|---|
| Maliyet ağırlıklı WebView creation'da | C yeterli |
| Maliyet ağırlıklı JS boot'ta, **aynı** MFE'nin ekranları arasında geziliyor | **A** |
| Maliyet ağırlıklı JS boot'ta, **farklı** MFE'ler arası geziliyor | A kısmi çözer; tam çözüm B (kapsam dışı) |
| Maliyet ağırlıklı veri beklemede | **Hiçbiri çözmez** — Faz 5.7'ye bakın |

> **Native-only'de A, ulaşabileceğiniz tavandır.** Bunu kullanıcıya açıkça söyleyin:
> aynı MFE içinde gezinme neredeyse bedava olur, MFE'ler arası geçiş olmaz.

---

## 6.4 Re-parenting (iOS)

```swift
/// Tek WebView'i container'lar arasında taşır. YENİDEN YARATMAZ, YÜKLEMEZ.
@MainActor
final class SharedWebViewCoordinator {
    private let webView: WKWebView
    private var snapshots: [ObjectIdentifier: UIImage] = [:]

    func move(to container: UIView, leaving previous: UIView?) {
        // 1. Ayrılan ekrana gerçek görüntüsünü bırak — beyaz ekran olmasın.
        if let previous { leaveSnapshot(in: previous) }

        // 2. Canlı WebView'i yeni container'a taşı.
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }

    private func leaveSnapshot(in container: UIView) {
        let cfg = WKSnapshotConfiguration()
        cfg.afterScreenUpdates = false        // canlı görüntüyü al, yeni render bekleme
        webView.takeSnapshot(with: cfg) { image, _ in
            guard let image else { return }
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFill
            iv.frame = container.bounds
            iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(iv)
        }
    }
}
```

## 6.5 Screenshot tekniği — her modelde uygulanabilir

**Bu, bu rehberdeki en ucuz fikirlerden biridir ve Faz 6'yı beklemeden yapılabilir.**

```
Ekrandan ayrılırken  →  canlı WebView'in görüntüsünü yakala, container'a bırak
Geri dönüşte         →  önce screenshot (anında), canlı WebView arkadan re-parent
```

Kullanıcı hiçbir zaman boş/beyaz bir container görmez. Bu **gerçek süreyi değil
algılanan süreyi** düşürür — ama geri navigasyonunda algılanan süre neredeyse sıfır olur.

> Faz 5'teki skeleton tartışmasının bu tekniğe **itirazı yoktur**: burada gösterdiğiniz
> şey sahte bir placeholder değil, ekranın **gerçek, daha önce render edilmiş
> görüntüsüdür.** Bekleme hissini yönetmiyorsunuz — beklemeyi görünmez kılıyorsunuz.

---

## 6.6 Kalıcı WebView'in riskleri — ve native-only'de state problemi

Faz 3'te havuz modelinin bir avantajı vardı: kullanılan WebView atılıyordu, bu
yüzden kirlenmiş state hiç oluşmuyordu. **Faz 6'da bu avantaj kayboluyor** ve
MFE bir `reset()` sunmadığı için native'in elinde temiz bir çözüm yok.

### Native'in elindeki üç seçenek — hepsinin bedeli var

| Seçenek | Ne yapar | Bedeli |
|---|---|---|
| **Hafif hedefe geri dön** (`__nativeRoute.go('/legal')`) | Görünen ekranı boşaltır | React ağacı unmount olur ama modül state'i, cache'i, listener'ları **bellekte kalır** |
| **Periyodik hard reload** | `webView.reload()` — her şeyi temizler | Isınmayı **baştan öder**; kullanıcı beklemeyecek bir anda yapın |
| **Hiçbir şey yapma** | — | Uzun oturumlarda bellek ve bayat state birikir |

**Önerilen bileşim:**

```swift
func onWebScreenClosed() {
    // 1. Görüneni boşalt — bir sonraki açılış temiz DOM'a gelsin.
    swapRoute(shared, to: config.warmupTargetRoute)

    // 2. Sınır koy: N ekran veya T dakika sonra tamamen tazele.
    screensSinceReload += 1
    if screensSinceReload >= 20 || Date().timeIntervalSince(lastReload) > 30 * 60 {
        scheduleReloadWhenIdle()     // uygulama arka plana gittiğinde veya
                                     // kullanıcı native ekranlardayken
    }
}
```

> 🚨 **`scheduleReloadWhenIdle` gerçekten idle beklemeli.** Kullanıcı bir web
> ekranı açarken reload tetiklerseniz cold baseline'a düşersiniz ve bunu
> ölçümde **rastgele yavaş açılışlar** olarak görürsünüz — sebebini bulmak çok zordur.

### Hata yakalama — native tarafta

MFE'ye error boundary ekleyemezsiniz. Prob, sayfa genelindeki hataları yakalar:

```js
// webview-probe.js'e eklenir
window.addEventListener('error', function (e) {
  window.__probe.post('js-error', { msg: String(e.message).slice(0, 300) });
});
window.addEventListener('unhandledrejection', function (e) {
  window.__probe.post('js-rejection', { msg: String(e.reason).slice(0, 300) });
});
```

Native bunu duyduğunda: telemetriye yazar, ekran hâlâ açılmadıysa **native hata
ekranı** gösterir ve paylaşılan WebView'i **tazeler**. Kalıcı modelde bir hata
tek ekranı değil **sonraki tüm ekranları** etkileyebilir — bu yüzden hard reload
burada Faz 3'tekinden daha kritiktir.

### Diğer riskler

| Risk | Önlem |
|---|---|
| **Content process termination** (iOS) | `webViewWebContentProcessDidTerminate` → yeniden kur + son route'a dön |
| **Bellek büyümesi** | 30 dakikalık gezinme sonrası artışı ölçün; §6.6'daki sınırı ona göre koyun |
| **Auth izolasyonu** | Farklı güven seviyeli MFE'ler **aynı** WebView'i paylaşmamalı — ayrı instance tutun |
| **Cross-MFE state sızıntısı** | `localStorage`/`sessionStorage` origin başına ayrıdır; aynı origin'deki farklı MFE'ler birbirini görür |

---

## 6.7 Kabul kriterleri

- [ ] Model seçildi (**A veya C**; B kapsam dışı) ve gerekçesi Faz 1 tablosuna dayandırıldı
- [ ] WebView ekranlar arasında re-parent ediliyor, yeniden yaratılmıyor
- [ ] Ayrılan ekranda screenshot bırakılıyor, geri dönüşte anında görünüyor
- [ ] Ekran kapanınca hafif ısınma hedefine dönülüyor
- [ ] **Sınırlı hard reload** kuralı var (N ekran / T dakika) ve yalnızca idle'da çalışıyor
- [ ] Prob `js-error` / `js-rejection` gönderiyor; native bunu telemetriye yazıyor
- [ ] Hata sonrası paylaşılan WebView tazeleniyor
- [ ] Content process termination'da son route'a geri dönülüyor
- [ ] Bellek: 30 dakikalık gezinme sonrası artış ölçüldü ve kabul edilebilir
- [ ] Farklı güven seviyeli MFE'ler aynı WebView'i paylaşmıyor
- [ ] **Ard arda 5 ekran açma** senaryosu ölçüldü (Faz 3 vs Faz 6 farkı burada görünür)
