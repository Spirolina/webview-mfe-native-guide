# Faz 2 — Hızlı kazanımlar (native-only)

**Amaç:** Ölçüm beklemeden yapılabilecek, kanıt sınıfı en güçlü, maliyeti en düşük işler.
Hepsi ya RFC'ye ya da platform üreticisinin kendi API dokümanına dayanır.

**Süre:** 1-2 hafta · **Risk:** düşük · **Geri alınabilir:** evet

> **Ön koşul:** [`00-kesif.md`](00-kesif.md) onaylandı, [`01-olcum.md`](01-olcum.md) kuruldu.
>
> Bu fazdaki her kalem **native kod tabanında** yapılır. Tek istisna §2.1
> (cache header'ları): o sunucu/CDN tarafındadır ve native ekibin yetkisinde
> olmayabilir — bu yüzden burada yalnızca **native tarafta nasıl doğrulanacağı**
> anlatılır, talep metni [`09-web-sozlesmesi.md`](09-web-sozlesmesi.md)'dedir.

---

## 2.1 Cache header'ları — ⚠️ native değil, ama native doğrular

Bu kalem **sunucu/CDN konfigürasyonudur**, MFE kaynak kodu değildir. Kapsam dışı
sayılsa bile **ölçüp raporlamak native ekibin işidir**, çünkü yanlış header
Faz 3'ün kazancını görünmez kılar.

### Native tarafta nasıl doğrulanır

Prob zaten Resource Timing'i görebiliyor (Faz 1.4). Isınmış bir WebView'de
sorun ve sonucu telemetriye yazın:

```swift
let js = "JSON.stringify(performance.getEntriesByType('resource')"
       + ".filter(r => r.initiatorType === 'script' || r.initiatorType === 'link')"
       + ".map(r => ({ u: r.name.split('/').pop(),"
       + "             kb: Math.round(r.transferSize/1024),"
       + "             cached: r.transferSize === 0 })))"

webView.evaluateJavaScript(js) { value, _ in
    // İKİNCİ açılışta cached:false olan her asset bir regresyondur.
    analytics.log("webview_asset_cache", ["payload": value as? String ?? ""])
}
```

| Gözlem | Anlamı | Yapılacak |
|---|---|---|
| İkinci açılışta hash'li asset `cached: false` | `immutable` yok veya `no-store` var | Talebi §09'a yazın |
| Her açılışta tüm bundle iniyor | Muhtemelen `no-store` | **Acil** — Faz 3 bile bunu kurtaramaz |
| `index.html` her seferinde 200 (304 değil) | `ETag` / revalidation yok | Talebi §09'a yazın |

### Doğru konfigürasyon (talep ederken bunu iletin)

```
hash'li asset'ler :  Cache-Control: public, max-age=31536000, immutable
index.html        :  Cache-Control: no-cache
                     ETag: "<build-hash>"
```

> 🚨 **`no-cache` ≠ `no-store`.** `no-cache` saklamayı yasaklamaz; her kullanımdan
> önce revalidation'a zorlar. İçerik değişmemişse sunucu `304` döner, body tekrar
> inmez — sadece 1 RTT ödenir. `no-store` kullanılıyorsa **tüm bundle her açılışta
> yeniden iner** ve bu, native tarafta yapabileceğiniz her şeyi gölgede bırakır.

### ⚠️ WebView cache'i app update'ten sağ çıkıyor mu — bilinmiyor

Header'lar doğru olsa bile, uygulama güncellemesinden sonra WebView'in HTTP
cache'inin korunup korunmadığı **doğrulanmamıştır**. Sürüm yükselttikten sonraki
ilk açılışı ayrı ölçün.

---

## 2.2 Cookie yazma sırası — sessiz hata

Her iki platformda da cookie yazma **asenkrondur.** `setCookie` çağırıp hemen
yüklerseniz **ilk istek cookie'siz çıkar**, 401 alır ve auth redirect zincirini
tetikler.

### iOS
Apple'ın dokümanı: completion handler *"asynchronously **after** the method
successfully stores the cookie"* çalışır.

```swift
let store = webView.configuration.websiteDataStore.httpCookieStore
let group = DispatchGroup()
for cookie in sessionCookies {
    group.enter()
    store.setCookie(cookie) { group.leave() }
}
group.notify(queue: .main) {
    webView.load(URLRequest(url: url))      // ✅ ancak burada yükle
}
```

### Android
Doküman birebir: *"**This method is asynchronous.** If a `ValueCallback` is provided,
`ValueCallback.onReceiveValue` will be called ... once the operation is complete."*

```kotlin
CookieManager.getInstance().setCookie(url, cookieValue) { ok ->
    if (ok) webView.loadUrl(url)             // ✅ callback'ten sonra
}
```

> ⚠️ Eski `setCookie(String, String)` overload'ı (API 1) **hiçbir tamamlanma sinyali
> vermez.** Callback'li sürümü kullanın.
>
> ⚠️ `Secure` attribute'u kullanıyorsanız doküman `url`'in **`https://`** olmasını
> şart koşar.

### `flush()` kritik yolda olmasın (Android)
Doküman: *"**This call will block the caller until it is done and may perform I/O.**"*
Ekran açılışında çağırmayın; uygulama arka plana giderken veya oturum kurulduktan
sonra çağırın.

---

## 2.3 User script WebView'den ÖNCE eklenmeli (iOS)

Apple'ın dokümanı: *"**Before you create the web view**, add this object to the
`WKUserContentController`..."* Sonradan eklemek o navigasyon için geç kalır.

```swift
let ucc = WKUserContentController()
ucc.addUserScript(WKUserScript(source: bootstrapJS,
                               injectionTime: .atDocumentStart,
                               forMainFrameOnly: true))
config.userContentController = ucc
let webView = WKWebView(frame: .zero, configuration: config)   // ✅ sonra yarat
```

---

## 2.4 Beyaz flash

### iOS (iOS 15+)
```swift
webView.isOpaque = false
webView.backgroundColor = .systemBackground
webView.underPageBackgroundColor = .systemBackground   // overscroll alanı
webView.scrollView.backgroundColor = .systemBackground
```
`underPageBackgroundColor`'ın varsayılanı sayfanın `<html>`/`<body>` arka planından
türetilir; tema renginize sabitleyin.

### Android
```kotlin
webView.setBackgroundColor(ContextCompat.getColor(context, R.color.screen_background))
```

### ⚠️ Web tarafındaki arka plan — kapsam dışı
Sayfanın `<html>`/`<body>` arka planı MFE'nin CSS'indedir ve ona dokunmuyoruz.
Native taraf bunu **üstünden kapatır**: `isOpaque = false` + tema renkli container
sayesinde kullanıcı, sayfa boyanana kadar MFE'nin beyazını değil sizin renginizi görür.

Tema uyumsuzluğu (koyu modda beyaz sayfa) görürseniz bu bir **web talebidir** —
[`09-web-sozlesmesi.md`](09-web-sozlesmesi.md)'ye yazın; native'de çözülmez.

> Bu, yükleme sırasındaki boş ekranı çözmez — onun için Faz 5 (reveal) veya
> Faz 6 (screenshot) gerekir. Bu sadece flash'ı kapatır.

---

## 2.5 Content process termination (iOS) — sıcak WebView tutacaksanız ZORUNLU

Apple: *"WebKit calls this method when the process for the specified web view
terminates **for any reason**."* Arka planda tutulan bir WebView'in content
process'i sistem tarafından öldürülebilir; WebView **boş beyaz bir dikdörtgene**
döner ve hiçbir şey yapmazsanız kullanıcı bunu görür.

```swift
func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    analytics.log("webview_process_terminated", screen: currentScreen)
    // Sıcak havuzdaysa: bu instance'ı at, yenisini hazırla.
    pool.discard(webView)
    Task { await pool.prepareReplacement() }
}
```

**Bu handler Faz 3'ün ön koşuludur.** Sıcak WebView tutup bunu yazmamak,
kullanıcıya beyaz ekran göstermek demektir.

---

## 2.6 Android WebView pre-warm

Android'de WebView başlatma **implicit**'tir ve ilk tetiklendiğinde **tamamen
main/UI thread'de** çalışır — input'u bloklar, ANR riskini artırır.

`androidx.webkit` **1.16.0** ile stable olan resmî API:

```kotlin
// Application.onCreate()
override fun onCreate() {
    super.onCreate()
    if (WebViewFeature.isStartupFeatureSupported(
            this, WebViewFeature.STARTUP_FEATURE_SET_DIRECTORY_BASE_PATHS)) {
        val config = WebViewStartUpConfig.Builder(backgroundExecutor)
            .setShouldRunUiThreadStartUpTasks(false)
            .build()
        WebViewCompat.startUpWebView(config) { result ->
            // result.blockingStartUpLocations → UI thread'i nerede bloklandığını logla
        }
    }
}
```

> 🚨 **Faydası koşulludur.** Çağrıdan hemen sonra main thread'de bir WebView API'si
> kullanırsanız UI thread init'i beklemek zorunda kalır ve **kazanç tam sıfır olur.**
>
> İki kural birden geçerli:
> - **Erken tetikle** → `Application.onCreate()`
> - **Geç instantiate et** → WebView yaratmayı kritik yoldaki diğer UI işlerinden sonraya ertele
>
> `startUpWebView` çağırıp aynı frame'de `WebView(context)` yaratmak, API'yi hiç
> çağırmamakla aynı şeydir.

**iOS'ta bunun resmî karşılığı yoktur.** iOS'ta kazanç Faz 2'deki mimariden gelir.

---

## 2.7 `file://` kullanmayın (Android)

`file://` ve `data:` **opaque origin**'dir ve **`fetch()` / `XMLHttpRequest`
kullanamazlar.** `WebView.loadData()` içeride `data:` kullanır. Yani naif
"bundle'ı diske koy, diskten yükle" yaklaşımı **veri çeken bir React uygulaması
için çalışmaz.**

Doğrusu `WebViewAssetLoader`'dır (Faz 7'de).

---

## 2.8 Kabul kriterleri

- [ ] Hash'li asset'ler `immutable`, `index.html` `no-cache` + `ETag`
- [ ] Resource Timing'de tekrar açılışta `transferSize === 0`
- [ ] `setCookie` callback'i bekleniyor, sonra yükleniyor
- [ ] `CookieManager.flush()` kritik yolda değil
- [ ] `WKUserScript` WebView'den önce ekleniyor
- [ ] Beyaz flash kapalı (her iki platform)
- [ ] `webViewWebContentProcessDidTerminate` handler'ı var
- [ ] Android `startUpWebView` `Application.onCreate()`'te, instantiation ertelenmiş
- [ ] Hiçbir yerde `file://` ile bundle yüklenmiyor

**Beklenen etki:** Bunlar tek başına büyük bir açılış kazancı vermez —
**Faz 3'ün doğru çalışması için ön koşuldur** ve sessiz hataları kapatır.
Cache header'ları tekrar açılışlarda ağ fazını ciddi biçimde düşürür.
