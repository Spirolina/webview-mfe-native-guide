# Faz 5 — Reveal: "hazır olmadan gösterme" (native-only)

**Bu bir performans optimizasyonu DEĞİL, bir ürün kararıdır.**
Gerçek süreyi düşürmez — hatta biraz artırır. Değiştirdiği şey **ne gösterildiğidir.**

**Süre:** 2-3 hafta · **Risk:** düşük (teknik), yüksek (ürün) · **Geri alınabilir:** evet

> **Ön koşul:** Faz 1 §1.6'daki **sezgi kalitesi ölçümü yapıldı**. Yapılmadıysa
> buraya geçmeyin — bu fazın tamamı o sezginin doğruluğuna bağlıdır.

---

## 5.1 Karar

| | Yarım ekran göster | Veri hazır olunca aç |
|---|---|---|
| Kullanıcı ilk ne görür | MFE'nin kendi iskeleti / boş ekran | Native spinner |
| İçerik atlaması (CLS) | Var | Yok |
| Algılanan ilk tepki | Hızlı | Yavaş |
| Ekranın "tamam" olma anı | Belirsiz, kademeli | Net |
| Bankacılıkta yaygın | — | ✅ |
| **Native-only'de risk** | yok | **sezgi yanılabilir** (§5.3) |

**Bu kararı ürün ekibiyle alın** (keşif §0.5-1). Teknik olarak ikisi de uygulanabilir.

> ⚠️ **Skeleton'ın daha iyi olduğu varsayımı ampirik olarak garanti değildir.**
> 136 kişilik, üç gruplu, rastgele atamalı bir deneyde skeleton **tüm metriklerde
> en kötü** koşul çıktı: algılanan bekleme skeleton 2.82 sn / spinner 2.41 sn /
> boş ekran 2.29 sn. *"The meals loaded quickly for me"* ifadesine katılım:
> spinner %74, boş %66, skeleton %59.
> ([Viget, 2017](https://www.viget.com/articles/a-bone-to-pick-with-skeleton-screens/) —
> anlamlılık testi içermiyor, 2017 tarihli)
>
> Bu, "skeleton kullanmayın" demek değil — **"kesin doğru" saymayın** demek.

---

## 5.2 Akış

```
kullanıcı dokunur
   │
   ├─ native ekran ANINDA açılır → nav bar + spinner         ← kullanıcı bunu görür
   ├─ sıcak WebView container'a konur, opacity 0             ← GÖRÜNMEZ
   ├─ native route swap (Faz 3.4) → MFE kendi verisini çeker
   ├─ prob: net-quiet + first-content + 2×rAF                ← HAZIR SEZGİSİ
   └─ native: opacity 1, spinner kaybolur
```

**Bedeli net:** ekran, **en yavaş API çağrısı kadar** gecikir.
Ekran 3 servise bağlıysa üçünün **maksimumunu** bekler, toplamını değil (paralel).

> **MFE işbirliği yapsaydı** burada kesin bir `screen-ready` sinyali olurdu.
> Yok. Native, prob'un sezgisini kullanır — ve o sezginin **yanılabileceğini
> varsayarak** tasarlanmak zorundadır.

---

## 5.3 Hazır-olma sezgisi — native tarafın kararı

Prob üç sinyal üretiyor (Faz 1.4). Native bunları birleştirir:

```swift
/// MFE "hazırım" demiyor. Bu, onun yerine geçen KURALDIR — ve bir vekildir.
struct ReadinessRule {
    /// Route değişimi görüldü mü (swap tuttu mu)
    var sawRouteChange = false
    /// Uçuştaki istek 0'a düştü ve QUIET_MS boyunca öyle kaldı
    var sawNetQuiet = false
    /// DOM'da anlamlı içerik belirdi ve iki kare boyandı
    var sawPainted = false

    /// Ekranın veri çekmesi BEKLENİYOR mu? Keşif §0.3-F'den doldurulur.
    let expectsData: Bool

    var isReady: Bool {
        guard sawRouteChange, sawPainted else { return false }
        return expectsData ? sawNetQuiet : true
    }
}
```

### 🚨 `expectsData` neden route bazında tutulmalı

Veri çekmeyen bir ekranda `net-quiet` beklerseniz, prob hiçbir istek görmediği
için sayaç zaten 0'dır ve `net-quiet` **QUIET_MS sonra** gelir — gereksiz 150 ms.
Veri çeken bir ekranda `net-quiet` beklemezseniz **boş ekran gösterirsiniz.**

Keşif §0.3-F'deki ekran-başına-istek tablosundan bir harita kurun:

```swift
enum RouteExpectation {
    static let expectsData: [String: Bool] = [
        "/accounts": true, "/cards": true, "/transfer": true,
        "/transfer/confirm": false,     // onay ekranı — veri çekmez
        "/legal": false,
    ]
    // Bilinmeyen route: veri çeker varsay (güvenli taraf — zaman aşımı yakalar).
    static func expects(_ route: String) -> Bool { expectsData[route] ?? true }
}
```

### Sezginin bozulduğu üç durum ve ne yapılacağı

| Durum | Belirti | Çözüm |
|---|---|---|
| **Polling / websocket** | `net-quiet` hiç gelmez | Prob'un `IGNORE` listesine ekleyin; ekleyemiyorsanız o route'ta `expectsData = false` yapıp yalnızca `painted`'a güvenin |
| **Zincirleme istek** (A bitince B başlar) | Erken `net-quiet` → yarım ekran | `QUIET_MS`'i artırın (150 → 300). Bedeli: her ekran 150 ms daha geç açılır |
| **Boş liste ekranı** | `first-content` hiç gelmez (yeterli metin yok) | `CONTENT_CHARS` eşiğini düşürün veya o route için `sawPainted` şartını kaldırın |

---

## 5.4 iOS — reveal

WebView **her zaman mount'ta** olmalı (render edebilmesi için); sadece `opacity`
ile gizlenir.

```swift
struct ScreenHost: View {
    @ObservedObject var vm: ScreenViewModel

    var body: some View {
        VStack(spacing: 0) {
            NativeHeader(title: vm.title, loading: !vm.revealed)   // ANINDA çizilir
            ZStack {
                Color(.systemBackground)
                if let wv = vm.webView {
                    WebViewContainer(webView: wv)
                        .opacity(vm.revealed ? 1 : 0)
                        .animation(.easeOut(duration: 0.18), value: vm.revealed)
                }
                if !vm.revealed { NativeLoader(title: vm.title) }
            }
        }
    }
}
```

```swift
// Prob mesajlarını kurala besleyin
func received(tag: String, phase: String, payload: [String: Any]) {
    switch phase {
    case "route-change": rule.sawRouteChange = true
    case "net-quiet":    rule.sawNetQuiet = true
    case "painted":      rule.sawPainted = true
    default: break
    }
    if rule.isReady { vm.revealed = true }
}
```

> ⚠️ `opacity(0)` kullanın, `if vm.revealed { ... }` **kullanmayın.** İkincisi
> WebView'i hierarchy'den çıkarır, render edemez ve `painted` **hiç gelmez** —
> ekran sonsuza kadar spinner'da kalır.

### Android

```kotlin
webView.alpha = if (revealed) 1f else 0f
// ⚠️ View.GONE KULLANMAYIN — Android'de de render'ı durdurur, aynı tuzak.
```

---

## 5.5 Uygulama içi gezinme — native overlay ile

Kullanıcı WebView'in **içinde** bir bağlantıya dokunduğunda native araya girmez.
Ama prob `route-change` gönderir — native bunu duyar ve **üstüne spinner koyar.**

```swift
func received(tag: String, phase: String, payload: [String: Any]) {
    guard phase == "route-change" else { return /* ... */ }
    let newRoute = payload["path"] as? String ?? ""
    guard newRoute != vm.currentRoute else { return }

    vm.currentRoute = newRoute
    rule = ReadinessRule(expectsData: RouteExpectation.expects(newRoute))

    // 🚨 HEMEN spinner göstermeyin. Veri gerektirmeyen geçişler anında biter;
    //    80 ms'lik gecikme, hızlı geçişlerde spinner'ın hiç görünmemesini sağlar.
    //    Referans ölçümde veri gerektirmeyen geçiş 8 ms sürdü.
    scheduleOverlay(after: .milliseconds(80))
}
```

**Önceki ekran görünür kalır, üzerine yarı saydam overlay + spinner gelir.**
WebView'i gizlemeyin — kullanıcı bir an için boşluk görür ve bu, hiçbir şey
yapmamaktan kötüdür.

> ⚠️ **Bu, MFE'nin kendi geçiş animasyonuyla çakışabilir.** MFE zaten kendi
> spinner'ını gösteriyorsa iki spinner üst üste gelir. Keşifte bunu gözleyin;
> çakışıyorsa uygulama içi gezinmede overlay'i **kapatın** ve yalnızca native
> ekran açılışlarında kullanın.

---

## 5.6 Zaman aşımı — zorunlu

Sezgi yanılırsa ekran sonsuza kadar spinner'da kalır. **Her zaman bir kaçış yolu:**

```swift
let revealed = await awaitReadiness(timeout: 8)     // native-only'de daha kısa tutun
if !revealed {
    // Seçenek A: yine de göster (yarım ekranla da olsa) — ÖNERİLEN
    vm.revealed = true
    analytics.log("webview_reveal_timeout", ["route": route, "rule": rule.debugState])
    // Seçenek B: native hata ekranı + tekrar dene
}
```

> **Native-only'de zaman aşımı kesin bir sinyal değil, bir sezgi hatasıdır.**
> Bu yüzden **Seçenek A tercih edilmelidir**: kesin bilgiye dayanmayan bir
> kuralın kullanıcıya hata ekranı göstermesi yanlıştır.
>
> `rule.debugState`'i mutlaka loglayın — hangi sinyalin gelmediğini bilmeden
> sezgiyi düzeltemezsiniz.

**Zaman aşımı oranı sizin en önemli sağlık metriğinizdir.** %1'in üstündeyse
sezgi yanlış ayarlanmış demektir; §5.3'teki tabloya dönün.

---

## 5.7 Ölçülmüş gerçek: bu desen maliyeti backend'e kaydırır

Referans ölçümde (bankacılık benzeri gecikmeler, ekran başına 2-3 paralel servis):

| Faz | Cold | Sıcak + route swap |
|---|---|---|
| JS zinciri | 397 ms | **22 ms** |
| **Veri bekleme** | **435 ms** | **497 ms** |
| Çizim + reveal | 71 ms | 46 ms |
| **Toplam** | 903 ms | 565 ms |

**Veri bekleme kalemi hiçbir WebView stratejisiyle küçülmedi.** Reveal desenini
uyguladığınızda ekran açılış süreniz büyük ölçüde **backend'inizin p95'i olur.**

Uygulama içi gezinmede bu daha da net görüldü:
```
/transfer → /transfer/confirm     8 ms   ← veri gerektirmeyen TEK ekran
diğer tüm geçişler          198–578 ms   ← tamamı API beklemesi
```

> **Sonuç:** Reveal'e geçerseniz, ekran açılış süresini iyileştirmenin yolu
> **API'lerinizi hızlandırmaktan** geçer. Ekran başına servis sayısını azaltmak
> (BFF/aggregation) muhtemelen en yüksek getirili iştir — ve o da bu rehberin
> kapsamı dışındadır. Keşif §0.3-F'deki tabloyu backend ekibiyle paylaşın.

---

## 5.8 Kabul kriterleri

- [ ] Ürün kararı alındı ve yazıldı (yarım ekran mı, bekleme mi)
- [ ] §1.6 sezgi kalitesi ölçümü yapıldı; erken/geç sapma kayıt altında
- [ ] `expectsData` haritası keşif §0.3-F'den kuruldu; bilinmeyen route'lar `true`
- [ ] Prob `IGNORE` listesi polling/analitik isteklerini kapsıyor
- [ ] Native spinner **anında** görünüyor (nav bar dahil)
- [ ] WebView `opacity`/`alpha` ile gizleniyor; `if`/`GONE` **kullanılmıyor**
- [ ] Uygulama içi gezinmede overlay **gecikmeli** açılıyor (hızlı geçişte görünmüyor)
- [ ] MFE'nin kendi spinner'ıyla çakışma kontrol edildi
- [ ] **Zaman aşımı yolu var**, varsayılan davranış "yine de göster"
- [ ] `rule.debugState` zaman aşımında loglanıyor
- [ ] Zaman aşımı oranı production'da izleniyor (hedef < %1)
