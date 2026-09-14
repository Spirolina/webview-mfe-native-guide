# Faz 7 — İleri seviye: yerel asset, speculative loading

**Ölçümünüz ağ fazının veya bundle boyutunun baskın olduğunu gösteriyorsa.**
Bu fazdaki her şey platform asimetrisi taşır — iOS ve Android farklı davranır.

---

## 7.1 ⚠️ Platform asimetrisi tablosu

| Yetenek | Android | iOS |
|---|---|---|
| Resmî pre-warm API | ✅ `WebViewCompat.startUpWebView` (1.16.0 stable) | ❌ yok |
| `https://` isteklerini intercept | ✅ `shouldInterceptRequest` | ❌ **imkânsız** |
| Yerel asset origin'i | ✅ gerçek HTTPS, same-origin | ⚠️ custom scheme, **farklı origin** |
| Prerender | ✅ `prerenderUrlAsync` (WebView 135+) | ❌ yok |
| Prefetch | ⚠️ var, ama interceptor'la çakışır | ❌ yok |
| Script-seviyesi profiling (LoAF) | ✅ provider ≥ 123 | ❌ Chromium-only |

**Okunacak sonuç:** iOS, Android'in resmî hızlandırma araçlarının neredeyse
hiçbirine sahip değil. **iOS'ta kazanç mimariden (Faz 3/6) gelmek zorunda.**

---

## 7.2 Yerel asset servisi

> **Kapsam notu:** Bu, MFE'nin **kaynak koduna** değil, **derlenmiş çıktısına**
> dokunur — native uygulama bundle'ı kendi içinde taşır veya OTA ile indirir.
> MFE ekibinden istenen tek şey **build artifact'ına erişimdir**, kod değişikliği değil.
>
> ⚠️ Ama bir ön koşulu var: MFE'nin asset'leri **göreli yollarla** referans
> vermesi gerekir. Mutlak CDN URL'leri gömülüyse yerel servis çalışmaz ve bu
> bir **web talebi** olur.



### Android — `WebViewAssetLoader` (resmî yol)

```kotlin
val assetLoader = WebViewAssetLoader.Builder()
    .setDomain("appassets.example.com")            // kendi domaininiz olabilir
    .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(context))
    .addPathHandler("/ota/", WebViewAssetLoader.InternalStoragePathHandler(context, otaDir))
    .build()

webView.webViewClient = object : WebViewClientCompat() {
    override fun shouldInterceptRequest(view: WebView, req: WebResourceRequest) =
        assetLoader.shouldInterceptRequest(req.url)
}
webView.loadUrl("https://appassets.example.com/assets/index.html")
```

İçerik **normal, opaque olmayan, same-origin HTTPS dokümanı** gibi davranır —
`fetch`, cookie, storage hepsi çalışır.

> `InternalStoragePathHandler` OTA ile indirilen bundle'ı aynı origin altında
> servis etmek için vardır.

### iOS — custom scheme ZORUNLU

Apple'ın dokümanı: *"It is a programmer error to register a handler for a scheme
WebKit already handles, such as `https`, and this method raises an
`invalidArgumentException` if you try to do so."*

`NSURLProtocol` da işe yaramaz: alt sınıf `+canInitWithRequest:` alır ama
**hiç instantiate edilmez** ([WebKit Bug 138169](https://bugs.webkit.org/show_bug.cgi?id=138169), ~12 yıldır açık).

```swift
let config = WKWebViewConfiguration()
config.setURLSchemeHandler(AppAssetSchemeHandler(), forURLScheme: "bankapp-assets")
webView.load(URLRequest(url: URL(string: "bankapp-assets://app/index.html")!))
```

Apple'ın scheme adı kuralları: *"must start with an ASCII letter, and may contain
only ASCII letters, numbers, the `+`, `-`, and `.` characters."* Ve tavsiyesi:
*"include the name of your app or company in any custom scheme names."*

### 🚨 iOS'ta custom scheme'in bedeli: origin değişir

| Etkilenen | Ne olur |
|---|---|
| **CORS** | API'niz `bankapp-assets://` origin'ini tanımalı, yoksa preflight patlar |
| **Cookie** | Custom scheme origin'i `https://api.banka.com` cookie'lerini otomatik göndermez |
| **Storage** | localStorage/IndexedDB farklı partition'a yazar |
| **Service Worker** | Custom scheme altında kullanılabilirliği **doğrulanamadı** |

**Bu, iOS ve Android'i mimari olarak ayrıştıran en büyük tek farktır.** Backend
CORS politikanızı baştan iki origin'i kapsayacak şekilde tasarlayın.

### ⚠️ Naif scheme handler HTTP'den yavaş olabilir

Referans ölçümde senkron `Data(contentsOf:)` kullanan bir handler, loopback HTTP'den
**daha yavaş** çıktı. Streaming ve cache olmadan yazmayın:

```swift
func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
    // ⚠️ Bunu main thread'de senkron yapmayın; büyük dosyalar için streaming kullanın.
    queue.async {
        guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
            return task.didFailWithError(Err.notFound)
        }
        DispatchQueue.main.async {
            task.didReceive(URLResponse(url: url, mimeType: mime,
                                        expectedContentLength: data.count,
                                        textEncodingName: "utf-8"))
            task.didReceive(data)
            task.didFinish()
        }
    }
}
```

---

## 7.3 Code splitting — ⚠️ kapsam dışı, ama kararı ölçümünüz verir

Bundle'ı bölmek bir **web build konfigürasyonu değişikliğidir**; native tarafta
yapılamaz. Buraya konmasının tek sebebi: **talep etmeye değer olup olmadığını
sizin ölçümünüz söyler** ve cevap çoğu zaman "hayır"dır.

Referans ölçüm: 1954 KB tek bundle vs 870 KB entry + 8 × ~134 KB chunk.

| Strateji | Tek bundle | Split | Fark |
|---|---|---|---|
| Cold baseline | 903 | 907 | ≈ 0 |
| **Warm blank** (`about:blank`) | 790 | **646** | **−18%** |
| Sıcak + route swap | 565 | 559 | ≈ 0 |
| Kalıcı paylaşılan | 565 | 587 | ≈ 0 |

**Tek net kazanan: dokunma anında tam JS boot ödeyen strateji.**

> 🚨 **Okunacak sonuç:** Faz 3'ü **A seçeneğiyle** (`about:blank`) uyguladıysanız
> split talep etmek anlamlı olabilir. **B veya C ile** uyguladıysanız JS boot'u
> zaten dokunmadan önce ödüyorsunuz ve split'in size verecek bir şeyi yok —
> **talep etmeyin.**

### ⚠️ Split'in bedeli localhost'ta görünmez
Referans ölçümde route mount 22 ms → 76 ms'ye çıktı: chunk indirme. Loopback'te
bu neredeyse bedava, **gerçek mobil şebekede fazladan bir round-trip** ve bilançoyu
tersine çevirebilir. **Split talebini gerçek şebekede ölçmeden yapmayın.**

Talep metni: [`09-web-sozlesmesi.md`](09-web-sozlesmesi.md).

---

## 7.4 Android speculative loading — üç API, birbirinin yerine geçmez

| API | Ne indirir | React SPA'da değeri |
|---|---|---|
| `Profile.preconnect()` | DNS + TCP + TLS (URL bilmeden çağrılabilir) | Orta — **en ucuz kazanç** |
| `Profile.prefetchUrlAsync()` | **Yalnızca HTML** | **Düşük** — JS/CSS indirmez |
| `WebViewCompat.prerenderUrlAsync()` | Sayfayı gizli renderer'da **çalıştırır** | Yüksek |

### 🚨 Prefetch, interceptor mimarisiyle ÇAKIŞIR

Doküman net:
1. **Prefetch edilen HTML için `shouldInterceptRequest()` tamamen atlanır** — auth
   header injection'ınız ve yerel asset mantığınız uygulanmaz.
2. **Navigasyon anında interceptor `null` dönmezse WebView prefetch cache'ini
   tamamen bypass eder.**

Yani `WebViewAssetLoader` kullanıyorsanız **prefetch fiilen hiçbir işe yaramaz.**
İkisi aynı anda kullanılamaz.

> **Prerender'ın aynı çakışmayı yaşayıp yaşamadığı dokümante edilmemiştir.**
> Kendi deneyinizle test edin.

### Prerender
Chrome'un tanımıyla CWV etkisi: *"near zero LCP, reduced CLS, improved INP."*

```kotlin
// Kullanıcı listede bir karta dokunmadan önce (ör. scroll durduğunda)
WebViewCompat.prerenderUrlAsync(
    webView, targetUrl, cancellationSignal, executor,
    object : PrerenderOperationCallback { /* ... */ }
)
```

> Android'de prerender **Java'dan sürülür**, sayfaya `<script type="speculationrules">`
> enjekte ederek değil. Web'de öğrendiğiniz pattern burada geçerli değil.
>
> **iOS'ta prerender yoktur.** Aynı etkiyi elde etmenin tek yolu Faz 3/6'teki
> elle sıcak tutulan WebView'dir.

### Prerender'ın gizli bedeli: tahmin
Kullanıcının hangi ekrana gideceğini bilmiyorsanız boşa pil ve veri harcarsınız.
Tahmin isabet oranınız hakkında yayımlanmış veri yok. **Kalıcı WebView'de bu
sorun yoktur** — React zaten ayakta, hangi ekrana giderse gitsin.

### ⚠️ API yüzeyi hızlı değişiyor
`androidx.webkit` son 12 ayda değişti (`setSpeculativeLoadingConfig` →
`setMaxPrerenders`/`PrefetchCache`; `SpeculativeLoadingParameters` →
`PrefetchParameters`/`PrerenderParameters`). Blog yazılarındaki imzalara güvenmeyin;
release notes'u kaynak alın.

---

## 7.5 Paylaşılan bağımlılık tekilliği — ⚠️ kapsam dışı

Farklı microfrontend'lerin React'i ayrı ayrı indirmesi gerçek bir maliyettir ama
çözümü web tarafındadır (ortak, sürümlü, immutable bir URL'den servis etmek).
Native tarafta yapılabilecek tek şey **ölçüp göstermektir**:

```swift
// Faz 2.1'deki asset denetimini MFE'ler arasında karşılaştırın.
// Aynı kütüphane iki farklı URL'den iniyorsa duplikasyon vardır.
```

single-spa, büyük kütüphanelerin sayfada **yalnızca bir kez** yüklenmesini
*"crucial"* sayar; framework'ün (React/Vue/Angular) **tek kez** yüklenmesi
gerektiğini söyler. react-router gibi küçük kütüphanelerin duplike olması kabul
edilebilir görülür.

> ⚠️ **"Büyük" ve "küçük" için hiçbir sayısal KB sınırı verilmez.** Sektörde dolaşan
> "V8 50–100 KB bundle bütçesi önerir" iddiası adversarial doğrulamayı **geçemedi**
> (0-3) ve V8'in yayınına atfedilemez. Kendi bütçenizi cihaz çarpanıyla (§7.6)
> kendi ölçümünüzden türetin.

Ayrıca import maps ile Module Federation **birbirinin alternatifidir** — ikisinden
biri seçilmeli, karıştırılmamalıdır. Bu da bir web kararıdır.

Talep metni: [`09-web-sozlesmesi.md`](09-web-sozlesmesi.md).

---

## 7.6 Cihaz sınıfı çarpanı — her bundle kararında hatırlayın

| Cihaz | Üst segmente göre JS execution |
|---|---|
| Pixel 3 (üst segment) | 1× |
| Moto G4 (orta segment) | **3–4×** |
| Alcatel 1X (<$100) | **6×+** |

([V8, 2019](https://v8.dev/blog/cost-of-javascript-2019) — ölçüm 2019, cihazlar 2016–2018)

Geliştirici telefonunda 300 ms olan boot, kullanıcı tabanınızın orta segmentinde
~1 saniyedir. **"Sadece 200 KB daha" üst segmentte fark etmez, orta segmentte
3-4 kat ağırlıkla geri döner.**

---

## 7.7 Kabul kriterleri

- [ ] Yerel asset kararı verildi; MFE'nin göreli yol kullandığı **doğrulandı**
- [ ] iOS'ta custom scheme seçildiyse origin değişikliğinin CORS/cookie etkisi çözüldü
- [ ] iOS scheme handler senkron/bloklayıcı değil
- [ ] Prefetch, `shouldInterceptRequest` mimarisiyle birlikte **kullanılmıyor**
- [ ] Prerender kullanılıyorsa interceptor çakışması test edildi
- [ ] Prerender tahmin isabet oranı ölçülüyor (isabetsiz prerender pil ve veri harcar)
- [ ] Bundle/duplikasyon bulguları **ölçülüp** web ekibine rapor edildi (talep §09'da)
- [ ] Hiçbir web build kararı native taraftan **varsayılarak** uygulanmadı
