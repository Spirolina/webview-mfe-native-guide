# Faz 3 — Sıcak WebView havuzu + native route swap

**Bu rehberin çekirdeği ve native-only kapsamın en zor kısmı.**
Referans ölçümde (MFE işbirliğiyle) JS zincirini **397 ms → 22 ms** düşürdü (18×).
Native-only'de bunun ne kadarını alabileceğiniz **ısınma hedefinizin ne kadar
sessiz olduğuna** bağlıdır — §3.2.

**Süre:** 3-6 hafta · **Risk:** orta · **Geri alınabilir:** evet (feature flag arkasında)

> **Ön koşul:** Keşifte route swap **fiilen test edildi** ([`00-kesif.md`](00-kesif.md) §0.3-A).
> Test edilmediyse buraya geçmeyin.

---

## 3.1 Fikir

Bugün olan:
```
kullanıcı dokunur → WebView yarat → doküman yükle → JS indir → parse → React boot → route → veri
                    └──────────── hepsi kullanıcı beklerken ────────────┘
```

Olması gereken:
```
UYGULAMA AÇILIŞI (kullanıcı beklemiyor)
  → gizli WebView yarat → ısınma hedefini yükle → JS indir → parse → React boot → BEKLE

kullanıcı dokunur
  → WebView'i göster → enjekte edilen sürücü: route'u değiştir → veri
     └── sayfa YÜKLENMİYOR. React zaten ayakta. ──┘
```

**MFE işbirliği yapsaydı** bunun için yan etkisiz bir `/warmup` route'u olurdu.
Yok. O yüzden native, **var olan bir route'u ısınma hedefi olarak seçmek** ve
**yan etkilerini kendi katmanında bastırmak** zorunda.

---

## 3.2 Isınma hedefi seçimi — bu fazın en önemli kararı

Dört seçenek var. **Keşif çıktınız hangisinin mümkün olduğunu söyler.**

| # | Hedef | JS boot kazancı | Yan etki riski | Ne zaman |
|---|---|---|---|---|
| **A** | `about:blank` | ❌ yok (sadece WebView/process maliyeti kalkar) | **sıfır** | Her zaman güvenli taban. Ölçülen: **−13%** |
| **B** | Mevcut **veri çekmeyen** route (yasal metin, "hakkında", onay ekranı, 404) | ✅ tam | **düşük** | Keşif §0.5-5'te böyle bir route bulunduysa — **tercih edilen** |
| **C** | Gerçek entry route + native susturma (§3.3) | ✅ tam | **orta-yüksek** | B yoksa ve susturma doğrulandıysa |
| **D** | MFE'ye `/warmup` eklenmesi | ✅ tam | sıfır | **Kapsam dışı** → [`09-web-sozlesmesi.md`](09-web-sozlesmesi.md) |

### 🚨 A ile B/C arasındaki fark neden bu kadar büyük

`about:blank`, JS bundle'ını **hiç indirmez ve çalıştırmaz**. Kazandırdığı tek şey
WKWebView/WebView nesnesinin ve içerik process'inin önceden var olmasıdır.
Referans ölçümde bu **−13%**; `/warmup` ile JS'i de önden çalıştırmak **−37%**.

**Yani bu fazın gerçek kazancı B veya C'yi uygulayabilmenize bağlıdır.**
B'yi bulamadıysanız ve C'nin riskini alamıyorsanız, native-only tavanınız
−13% ile Faz 6 (kalıcı WebView) arasındadır — bunu kullanıcıya **açıkça söyleyin.**

### B seçeneğini nasıl bulursunuz

Keşifte her route'u açıp Network panelini izleyin. Aradığınız route:

- [ ] Hiçbir `/api/*` çağrısı yapmıyor
- [ ] Analitik event'i **ya göndermiyor ya da** gönderdiği event iş metriklerinizi bozmuyor
- [ ] Auth redirect tetiklemiyor (ya da tetikliyorsa bu **istediğiniz** şey — Faz 4)
- [ ] Hızlı mount oluyor

> ⚠️ **Analitik hâlâ bir sorun olabilir.** Isınma hedefi bir "ekran görüntüleme"
> event'i gönderiyorsa, kullanıcı o ekranı hiç görmeden görüntülenmiş sayılır.
> §3.3'teki susturma bunu ağ seviyesinde keser; ama uygulama event'i **kuyruğa
> alıp sonra gönderiyorsa** kesilmez. Keşif §0.3-G'de bunu tespit edin.

---

## 3.3 Isınmayı susturma — native katmanda

Isınma sırasında analitiği (ve gerekiyorsa API'yi) **ağ seviyesinde** engelleyin,
WebView gösterilmeden hemen önce engeli kaldırın.

### iOS — `WKContentRuleList`

```swift
import WebKit

enum WarmupSilencer {
    /// Keşif §0.3-G'de tespit ettiğiniz host'ları buraya yazın.
    static let rulesJSON = """
    [
      { "trigger": { "url-filter": ".*", "if-domain": ["*analytics.example.com",
                                                       "*telemetry.example.com"] },
        "action": { "type": "block" } }
    ]
    """

    static func compile() async -> WKContentRuleList? {
        await withCheckedContinuation { c in
            WKContentRuleListStore.default()?.compileContentRuleList(
                forIdentifier: "warmup-silencer",
                encodedContentRuleList: rulesJSON
            ) { list, _ in c.resume(returning: list) }
        }
    }
}

// Isınırken ekle
if let list = await WarmupSilencer.compile() {
    webView.configuration.userContentController.add(list)
    silencer = list
}

// Kullanıcıya göstermeden HEMEN ÖNCE kaldır
if let list = silencer {
    webView.configuration.userContentController.remove(list)
    silencer = nil
}
```

### Android — `shouldInterceptRequest`

```kotlin
class WarmupAwareClient(private val isWarming: () -> Boolean) : WebViewClientCompat() {
    private val blocked = listOf("analytics.example.com", "telemetry.example.com")

    override fun shouldInterceptRequest(view: WebView, req: WebResourceRequest):
        WebResourceResponse? {
        if (isWarming() && blocked.any { req.url.host?.endsWith(it) == true }) {
            // Boş 204 — istek ağa hiç çıkmaz.
            return WebResourceResponse("text/plain", "utf-8", 204, "No Content",
                                       emptyMap(), ByteArrayInputStream(ByteArray(0)))
        }
        return null
    }
}
```

> ⚠️ Keşifte zaten bir `WebViewClient` alt sınıfı bulduysanız bu mantığı **onun
> içine** ekleyin, ikinci bir client kurmayın.
>
> 🚨 `shouldInterceptRequest` kullanıyorsanız Android speculative **prefetch**
> API'si fiilen devre dışı kalır (Faz 7.4). İkisi birlikte kullanılamaz.

### 🚨 Susturmanın üç sınırı — dürüstçe

| Sınır | Sonuç |
|---|---|
| **Kuyruklu analitik** | Uygulama event'i `sendBeacon`/kuyrukla sonra gönderiyorsa engel işe yaramaz; event daha sonra gider |
| **API engellenirse hata state'i** | Ekran "yüklenemedi" durumuna düşer; route swap sonrası bu state'te kalabilir (bazı veri katmanları hatayı cache'ler) |
| **Uygulama içi sayaçlar** | `localStorage`'a yazılan "kaç kez açıldı" gibi sayaçlar ağdan bağımsız artar |

**Bu yüzden B seçeneği (veri çekmeyen route) C'den her zaman daha iyidir.**
C'yi seçtiyseniz, engeli kaldırdıktan sonra hedef route'a geçişin **gerçekten
taze veri çektiğini** doğrulayın (§3.10).

---

## 3.4 Native route swap — enjekte edilen sürücü

MFE bir `window.__mfe.navigate()` köprüsü sunmuyor. Native kendi sürücüsünü
enjekte eder — **prob ile aynı documentStart script'inin içine** koyun.

```js
// webview-probe.js'in sonuna eklenir.
// MFE'nin router'ını DIŞARIDAN sürer. Sayfa yeniden yüklenmez.
window.__nativeRoute = {
  /** Keşif §0.3-A'da tespit edilen mod: 'history' | 'hash' */
  mode: 'history',

  go: function (path) {
    var before = location.pathname + location.hash;
    if (this.mode === 'hash') {
      // Hash router: en güvenilir yol. hashchange doğal olarak tetiklenir.
      if (location.hash !== '#' + path) location.hash = path;
      else window.dispatchEvent(new HashChangeEvent('hashchange'));
    } else {
      history.pushState({}, '', path);
      // Router'ın dinlediği olay bu. Sentetik dispatch ŞARTTIR —
      // pushState tek başına hiçbir olay üretmez.
      window.dispatchEvent(new PopStateEvent('popstate', { state: history.state }));
    }
    window.__probe && window.__probe.post('native-route-go', { from: before, to: path });
    return before;
  },

  /** Native, swap'ın gerçekten işe yaradığını doğrulamak için sorar. */
  current: function () { return location.pathname + location.hash; },
}
```

```swift
// iOS — çağrı
webView.evaluateJavaScript("window.__nativeRoute.go('\(route)')", completionHandler: nil)
```
```kotlin
// Android — çağrı
webView.evaluateJavascript("window.__nativeRoute.go('$route')", null)
```

> ⚠️ **`evaluateJavaScript`'i Swift'te `async` bağlamda çağırırsanız** derleyici
> `async throws` overload'ını seçer ve çağrı **bloklar**. Ölçümü bozar. Açıkça
> `completionHandler:` varyantını kullanın.

### 🚨 Route swap'ın çalıştığını varsaymayın — doğrulayın

Sentetik `popstate` her router sürümünde işe yaramaz. Bazı router'lar
`history.state` içinde kendi indekslerini tutar ve dışarıdan gelen olayı yok sayar.

**Runtime doğrulama koyun ve başarısızlıkta tam yüklemeye düşün:**

```swift
func swapRoute(_ wv: WKWebView, to route: String) {
    wv.evaluateJavaScript("window.__nativeRoute.go('\(route)')", completionHandler: nil)

    // 400 ms içinde route değişmediyse swap tutmadı → normal yüklemeye düş.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        wv.evaluateJavaScript("window.__nativeRoute.current()") { value, _ in
            let ok = (value as? String)?.contains(route) == true
            analytics.log("webview_route_swap", ["route": route, "ok": ok])
            if !ok {
                // Fallback: kazancı kaybederiz ama kullanıcı doğru ekranı görür.
                wv.load(URLRequest(url: self.url(for: route)))
            }
        }
    }
}
```

**Bu fallback zorunludur.** Onsuz, router uyumsuzluğu sizi kullanıcıya
**yanlış ekran** göstermeye götürür — yavaş ekrandan çok daha kötü bir hata.

---

## 3.5 iOS — sıcak WebView havuzu

```swift
import WebKit

@MainActor
final class WarmWebViewPool {
    private var warm: WKWebView?
    private var isReady = false
    private var silencer: WKContentRuleList?
    private let config: AppConfig

    // MARK: Hazırlık — uygulama açılışında çağrılır

    func prepare() async {
        teardown()
        let wv = makeWebView()
        attachOffscreen(wv)                    // hierarchy İÇİNDE ama görünmez
        warm = wv

        if let list = await WarmupSilencer.compile() {       // §3.3
            wv.configuration.userContentController.add(list)
            silencer = list
        }
        wv.load(URLRequest(url: config.warmupTargetURL))     // §3.2'deki A/B/C
        isReady = await waitUntilWarm(wv, timeout: 15)
    }

    /// "Isındı" tanımı — MFE bize söylemiyor, prob'dan çıkarıyoruz.
    /// A seçeneğinde (about:blank) yalnızca didFinish beklenir.
    /// B/C'de: doc-start geldi VE ağ sustu.
    private func waitUntilWarm(_ wv: WKWebView, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if probe.sawDocStart(for: wv) && probe.sawNetQuiet(for: wv) { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        analytics.log("webview_warmup_timeout")
        return false
    }

    // MARK: Kullanım — kullanıcı dokunduğunda

    /// Sıcak instance'ı verir ve havuzu boşaltır.
    /// Hazır değilse hazırlanmasını bekler (ilk açılış senaryosu).
    func take() async -> WKWebView {
        if !isReady { await prepare() }
        // Susturmayı KALDIR — artık gerçek ekran açılıyor.
        if let list = silencer {
            warm?.configuration.userContentController.remove(list)
            silencer = nil
        }
        defer { warm = nil; isReady = false }
        return warm ?? makeWebView()
    }

    /// Ekran kapandıktan sonra bir sonraki için yeniden ısıt.
    func replenish() async { await prepare() }

    // MARK: Detaylar

    private func makeWebView() -> WKWebView {
        let c = makeConfiguration(tag: "pool")   // Faz 1.5: prob + sürücü burada enjekte edilir
        let wv = WKWebView(frame: UIScreen.main.bounds, configuration: c)
        wv.navigationDelegate = self             // redirect sayımı + process termination
        wv.isOpaque = false
        wv.backgroundColor = .systemBackground
        wv.underPageBackgroundColor = .systemBackground
        return wv
    }

    /// Görünmez ama hierarchy İÇİNDE.
    ///
    /// ⚠️ Hierarchy dışındaki bir WKWebView'in gerçekten render edip etmediği
    /// Apple tarafından dokümante edilmemiştir. Ekranda olmayan ama hierarchy'de
    /// olan bir view render eder; tamamen detached olan etmeyebilir.
    /// Bu anahtarı açık/kapalı ÖLÇÜN — Faz 3'ün temel varsayımıdır.
    private func attachOffscreen(_ wv: WKWebView) {
        guard let win = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
        wv.frame = CGRect(x: -win.bounds.width * 2, y: 0,
                          width: win.bounds.width, height: win.bounds.height)
        wv.isHidden = false
        wv.alpha = 1
        win.insertSubview(wv, at: 0)             // en altta, hiçbir şeyi kapatmaz
    }

    private func teardown() {
        warm?.configuration.userContentController
            .removeScriptMessageHandler(forName: ProbeHandler.name)
        warm?.removeFromSuperview()
        warm = nil; isReady = false; silencer = nil
    }
}
```

### Ekranı açma

```swift
@MainActor
func openWebScreen(route: String) async {
    let t0 = CACurrentMediaTime()            // ÖLÇÜM: kullanıcının dokunduğu an

    let wv = await pool.take()               // susturma burada kalkar
    wv.removeFromSuperview()
    present(wv)                              // container'a koy (Faz 5: opacity 0 ile)

    swapRoute(wv, to: route)                 // §3.4 — doğrulama + fallback dahil

    Task { await pool.replenish() }          // bir sonraki açılış için arka planda ısıt
}
```

---

## 3.6 Android — sıcak WebView havuzu

```kotlin
class WarmWebViewPool(
    private val app: Application,
    private val config: AppConfig,
) {
    private var warm: WebView? = null
    private var ready = false
    @Volatile var isWarming = false
        private set

    suspend fun prepare() = withContext(Dispatchers.Main) {
        teardown()
        isWarming = true                       // WarmupAwareClient bunu okur (§3.3)
        val wv = makeWebView()
        attachOffscreen(wv)
        warm = wv
        wv.loadUrl(config.warmupTargetUrl)
        ready = awaitWarm(15_000)
    }

    suspend fun take(): WebView = withContext(Dispatchers.Main) {
        if (!ready) prepare()
        isWarming = false                      // susturmayı kaldır
        val wv = warm ?: makeWebView()
        warm = null; ready = false
        wv
    }

    private fun makeWebView(): WebView = WebView(app).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        setBackgroundColor(ContextCompat.getColor(app, R.color.screen_background))
        installProbe(this, probeJs)            // Faz 1.5
        webViewClient = WarmupAwareClient { isWarming }
    }

    /**
     * Hierarchy içinde ama ekran dışında. decor view'a 1x1 eklemek yaygın yöntemdir.
     */
    private fun attachOffscreen(wv: WebView) {
        val root = currentActivity()?.window?.decorView as? ViewGroup ?: return
        root.addView(wv, ViewGroup.LayoutParams(1, 1))
        wv.x = -10_000f
    }

    private fun teardown() {
        warm?.let { (it.parent as? ViewGroup)?.removeView(it); it.destroy() }
        warm = null; ready = false; isWarming = false
    }
}
```

```kotlin
suspend fun openWebScreen(route: String) {
    val t0 = SystemClock.elapsedRealtimeNanos()
    val wv = pool.take()
    present(wv)
    swapRoute(wv, route)                       // §3.4 doğrulama + fallback
    scope.launch { pool.prepare() }
}
```

---

## 3.7 Ne zaman ısıtmalı

| An | Yapılacak |
|---|---|
| Uygulama açılışı (`didFinishLaunching` / `Application.onCreate`) | İlk sıcak instance'ı hazırla |
| Bir web ekranı kapandığında | Yeniden ısıt (`replenish`) |
| Uygulama arka plana gittiğinde | Bellek baskısı yüksekse bırakmayı değerlendir |
| Öne döndüğünde | Sıcak instance hâlâ canlı mı kontrol et, değilse yeniden kur |
| `webContentProcessDidTerminate` | At, yenisini hazırla (Faz 2.5) |

> ⚠️ **Android'de `startUpWebView` ile çakışmayın.** Faz 2.6'daki kural hâlâ
> geçerli: `Application.onCreate`'te `startUpWebView` çağırıp **aynı frame'de**
> havuzun WebView'ini yaratırsanız kazanç tam sıfır olur. Havuz hazırlığını
> bir sonraki frame'e veya ilk idle'a erteleyin.

> **Kaç instance tutmalı?** Referans uygulama **tek** instance tuttu. Havuz boyutunu
> artırmak ard arda ekran açmayı hızlandırır ama bellek ve jetsam riskini büyütür.
> Optimal değeri **ölçülmemiştir** — keşif §0.5-2'deki bellek bütçesiyle deneyin.

---

## 3.8 Reset problemi — havuz modelinde yoktur, bu bir avantajdır

MFE işbirliği yapsaydı, ekran kapanınca `window.__mfe.reset()` çağırıp React
ağacını temizlerdiniz. Yapmıyor ve native, React state'ini dışarıdan güvenilir
biçimde temizleyemez.

**Havuz modelinde buna gerek yok:** kullanılan WebView **atılır**, yenisi sıfırdan
ısıtılır. Kirlenmiş state ile hiç karşılaşmazsınız.

> 🚨 **Bu, Faz 6'ya (kalıcı WebView) geçerseniz değişir.** Orada aynı WebView
> yaşamaya devam eder ve state kirlenmesi gerçek bir sorundur —
> [`06-kalici-webview.md`](06-kalici-webview.md) §6.6'ya bakın.

Bedeli: her ekran açılışından sonra ısınmayı **yeniden ödersiniz**. Kullanıcı
ard arda hızlı ekran açarsa ikinci açılış sıcak olmayabilir. Bunu ölçün:
**"ard arda 5 ekran"** senaryosu (Faz 6.2).

---

## 3.9 🚨 Bu fazı sessizce öldüren hatalar

| Hata | Sonuç |
|---|---|
| Route swap'ın çalıştığını **doğrulamamak** | Kullanıcı **yanlış ekranı** görür — en kötü hata |
| Swap fallback'i yazmamak | Router uyumsuzluğunda ekran hiç değişmez |
| Sıcak WebView hierarchy dışında | Render etmeyebilir; "ısıttım ama fark yok" |
| `evaluateJavaScript`'in async overload'ı (Swift) | Çağrı bloklar, ölçüm bozulur |
| Ekran kapandıktan sonra yeniden ısıtmamak | İkinci açılış cold baseline'a döner |
| Susturmayı göstermeden önce kaldırmamak | Gerçek ekran veri çekemez, boş kalır |
| Susturmayı hiç kurmamak (C seçeneğinde) | Görüntülenmemiş ekranlar analitiğinizi bozar |
| `about:blank` ile ısıtıp `/warmup` kazancı beklemek | JS hiç çalışmadı; kazanç −13% ile sınırlı |
| Process termination handler yok (Faz 2.5) | Kullanıcı beyaz dikdörtgen görür |
| Isınma bitmeden ölçüm başlatmak | Kazanç ısınma süresiyle maskelenir |
| `startUpWebView` ile aynı frame'de havuz kurmak | Android'de kazanç tam sıfır |

---

## 3.10 Doğrulama

### Isınma gerçekten sessiz mi?
Uygulamayı açın, **hiçbir ekrana dokunmayın**, 60 sn bekleyin. Sunucu/analitik
tarafında sayın:

```
beklenen:  doküman yüklemesi > 0      (JS ayağa kalktı — B/C seçeneğinde)
           analitik event     = 0      ← ZORUNLU
           veri isteği        = 0      ← B seçeneğinde zorunlu, C'de susturmayla
```

> Bu ölçümü **backend/analitik ekibiyle birlikte** yapın. Kendi cihazınızdaki
> Network paneli, kuyruğa alınıp sonra gönderilen event'i göstermez.

### Faz tablosunda ne görmelisiniz
```
native.committed  → yok        (sayfa yeniden yüklenmedi)
doc-start         → yok        (prob zaten çalışmıştı)
native-route-go   → ~5-20 ms
route-change      → ~20-80 ms  ← buraya kadar olan her şey artık neredeyse bedava
net-quiet         → API'nize bağlı
```

`doc-start` sütunu **boşsa doğru çalışıyor.** Doluysa sayfa yeniden yükleniyor
demektir — swap fallback'i devreye girmiş olabilir, `webview_route_swap` telemetrisine bakın.

### Swap başarı oranı — production sağlık metriği
`webview_route_swap.ok` oranı **%99'un altındaysa** bu fazın kazancı yoktur;
router uyumluluğunu yeniden inceleyin.

---

## 3.11 Kabul kriterleri

- [ ] Isınma hedefi seçildi (A/B/C) ve gerekçesi keşif raporuna dayandırıldı
- [ ] C seçildiyse susturma kuruldu ve **kaldırma** yolu test edildi
- [ ] Isınmanın sessizliği backend/analitik tarafında **doğrulandı**
- [ ] `window.__nativeRoute` sürücüsü prob ile aynı script'te enjekte ediliyor
- [ ] Route swap **runtime doğrulaması** ve **tam yükleme fallback'i** var
- [ ] `webview_route_swap.ok` telemetriye yazılıyor
- [ ] Sıcak instance uygulama açılışında hazırlanıyor, ekran kapanınca yeniden ısıtılıyor
- [ ] Sıcak WebView hierarchy içinde (ve bu **ölçümle** doğrulandı)
- [ ] Process termination handler'ı sıcak instance'ı değiştiriyor
- [ ] Faz tablosunda `doc-start` boş
- [ ] Android: `startUpWebView` ile havuz kurulumu aynı frame'de değil
- [ ] Feature flag arkasında, açıp kapatılabiliyor

**Beklenen etki — dürüst aralık:**

| Isınma hedefi | Beklenen |
|---|---|
| A (`about:blank`) | **≈ −13%** (ölçüldü) |
| B (veri çekmeyen mevcut route) | −13% ile −37% arası. **Referans ölçümde bu varyant ayrıca ölçülmedi** — kendi sayınızı üretin |
| C (entry route + susturma) | B ile aynı tavan, ama yan etki riski taşır |

Gerçek etkisi sizin veri bekleme payınıza bağlıdır — Faz 1 tablonuz söyler.
