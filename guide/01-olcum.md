# Faz 1 — Ölçüm (zorunlu ön koşul, native-only)

**Amaç:** Ekran açılışını fazlara bölüp her fazın ms maliyetini görmek —
**microfrontend kaynak koduna tek satır yazmadan.**

Bu tablo olmadan sonraki hiçbir fazın size ne kazandıracağını bilemezsiniz.

**Süre:** 2-5 gün · **Risk:** yok · **Geri alınabilir:** evet

> **Ön koşul:** [`00-kesif.md`](00-kesif.md) tamamlandı ve onaylandı.

---

## 1.1 Native-only ölçüm nasıl mümkün

MFE kendi faz mark'larını göndermiyor. Ama native, sayfaya **MFE'nin kodundan
önce** çalışan bir prob enjekte edebilir:

| Mekanizma | iOS | Android |
|---|---|---|
| Enjeksiyon | `WKUserScript(injectionTime: .atDocumentStart)` | `WebViewCompat.addDocumentStartJavaScript` |
| Geri kanal | `window.webkit.messageHandlers.<ad>.postMessage` | `addJavascriptInterface` |

Prob şunları **MFE'nin işbirliği olmadan** görür:

- Doküman yaşam döngüsü (`doc-start`, `dom-interactive`, `DOMContentLoaded`, `load`)
- `fetch` / `XMLHttpRequest` başlangıç-bitişleri ve **uçuştaki istek sayısı**
- Ağın sustuğu an (`net-quiet`) — **veri hazır olmanın vekil göstergesi**
- DOM'da anlamlı içeriğin ilk belirdiği an (`first-content`)
- `paint` girdileri (FCP) ve — Chromium'da — LCP
- SPA route değişimleri (`history.pushState`/`replaceState`/`popstate` yamalanarak)

**Görmediği tek şey:** MFE'nin *kendi* "ben hazırım" tanımı. Onun yerine
**ağ + DOM sezgisi** kullanılır. Bu bir **vekildir, kesinlik değildir** —
§1.6'da kalitesi nasıl ölçülür yazıyor.

---

## 1.2 Ölçülecek fazlar

```
t0 = kullanıcı dokundu (native, monoton saat)
 │
 ├─ native.webview-ready     WebView elde edildi (yaratıldı ya da havuzdan alındı)
 ├─ native.attached          view hierarchy'ye kondu
 ├─ native.nav-start         navigasyon başladı        (delegate)
 ├─ native.redirect ×N       her sunucu yönlendirmesi   (delegate)   ← Faz 4 buna bakar
 ├─ native.committed         ilk byte geldi, render başlıyor (delegate)
 ├─ doc-start                prob çalıştı = JS motoru ayakta       (prob)
 ├─ dom-interactive          parse bitti                            (prob)
 ├─ route-change             SPA route değişti                      (prob)
 ├─ xhr-first                ilk veri isteği çıktı                  (prob)
 ├─ net-quiet                uçuştaki istek 0'a düştü ve öyle kaldı (prob)  ← veri hazır vekili
 ├─ first-content            DOM'da anlamlı içerik belirdi          (prob)
 ├─ fcp                      ilk içerikli boyama                    (prob)
 └─ screen-ready             native ekranı gösterdi   ← ANA METRİK  (native, Faz 5)
```

**Sıcak stratejilerde `doc-start` / `dom-interactive` hiç görünmez** — o iş zaten
dokunmadan önce yapılmıştır. **Sütunun boş olması hata değil, kazancın kendisidir.**

---

## 1.3 Tek kural: her şey `t0`'a göre

Prob **asla mutlak zaman göndermez.** Sadece *"şu faza geldim"* der; farkı native
hesaplar. Böylece iki ayrı saati senkronize etme problemi hiç doğmaz.

```swift
// iOS — monoton saat. Sistem saati değişse bile kaymaz. Date() KULLANMAYIN.
var t0: CFTimeInterval = 0
func onTap() { t0 = CACurrentMediaTime() }

func received(tag: String, phase: String, payload: [String: Any]) {
    let ms = (CACurrentMediaTime() - t0) * 1000
    guard ms >= 0 else { return }    // t0 öncesi (ısınma) mesajlarını sayma
    samples[phase] = ms
}
```

```kotlin
// Android
val ms = (SystemClock.elapsedRealtimeNanos() - t0) / 1_000_000.0
if (ms >= 0) samples[phase] = ms
```

---

## 1.4 Prob — enjekte edilecek JavaScript

Bu dosyayı **native kaynak ağacına** koyun (ör. `Resources/webview-probe.js`).
MFE reposuna **girmez**.

```js
// webview-probe.js — native tarafından documentStart'ta enjekte edilir.
// MFE'nin hiçbir kodu bu dosyadan haberdar değildir.
(function () {
  if (window.__probe) return;                 // çift enjeksiyona karşı
  var P = (window.__probe = { marks: [], inflight: 0, ignored: 0 });

  // ── Keşif çıktısından doldurun (00-kesif §0.3-E ve §0.3-G) ───────────────
  // Sayaca DAHİL EDİLMEYECEK istekler: analitik, telemetri, polling, SSE.
  var IGNORE = [/\/analytics\//, /\/telemetry\//, /\/beacon/, /\/ping/];
  var QUIET_MS = 150;                         // "ağ sustu" için sessizlik eşiği
  var CONTENT_CHARS = 120;                    // "anlamlı içerik" eşiği
  // ─────────────────────────────────────────────────────────────────────────

  function post(type, data) {
    var m = Object.assign({ type: type, t: Math.round(performance.now()) }, data || {});
    P.marks.push(m);
    try { window.webkit.messageHandlers.probe.postMessage(m); } catch (e) {}
    try { window.__ProbeBridge.post(JSON.stringify(m)); } catch (e) {}
  }
  P.post = post;

  var ignore = function (u) { return IGNORE.some(function (r) { return r.test(String(u)); }); };

  // ── 1. Doküman yaşam döngüsü ────────────────────────────────────────────
  post('doc-start', { url: location.href });
  document.addEventListener('readystatechange', function () {
    if (document.readyState === 'interactive') post('dom-interactive');
  });
  document.addEventListener('DOMContentLoaded', function () { post('dom-content-loaded'); });
  window.addEventListener('load', function () {
    var n = performance.getEntriesByType('navigation')[0];
    post('load', n ? {
      redirectMs: Math.round(n.redirectEnd - n.redirectStart),
      ttfb: Math.round(n.responseStart),
      domInteractive: Math.round(n.domInteractive),
    } : {});
  });

  // ── 2. Ağ: uçuştaki istek sayısı + sessizlik ────────────────────────────
  var quietTimer = null, sawFirst = false;
  function started(url) {
    if (ignore(url)) { P.ignored++; return false; }
    if (!sawFirst) { sawFirst = true; post('xhr-first', { url: String(url).slice(0, 200) }); }
    P.inflight++;
    if (quietTimer) { clearTimeout(quietTimer); quietTimer = null; }
    return true;
  }
  function settled(url, ms, ok) {
    if (ignore(url)) return;
    P.inflight = Math.max(0, P.inflight - 1);
    post('xhr-end', { url: String(url).slice(0, 200), ms: Math.round(ms), ok: !!ok });
    if (P.inflight === 0) {
      if (quietTimer) clearTimeout(quietTimer);
      // Zincirleme istekler (A bitince B başlar) yanlış "sessiz" vermesin diye bekle.
      quietTimer = setTimeout(function () {
        if (P.inflight === 0) post('net-quiet', { since: Math.round(performance.now()) });
      }, QUIET_MS);
    }
  }

  var _fetch = window.fetch;
  if (_fetch) {
    window.fetch = function (input, init) {
      var url = (input && input.url) || input, s = performance.now();
      if (!started(url)) return _fetch.apply(this, arguments);
      return _fetch.apply(this, arguments).then(
        function (r) { settled(url, performance.now() - s, r.ok); return r; },
        function (e) { settled(url, performance.now() - s, false); throw e; }
      );
    };
  }

  var _open = XMLHttpRequest.prototype.open, _send = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (m, u) { this.__u = u; return _open.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function () {
    var self = this, s = performance.now();
    if (started(self.__u)) {
      self.addEventListener('loadend', function () {
        settled(self.__u, performance.now() - s, self.status >= 200 && self.status < 400);
      });
    }
    return _send.apply(this, arguments);
  };

  // ── 3. DOM: anlamlı içerik belirdi mi ───────────────────────────────────
  var contentDone = false;
  function checkContent() {
    if (contentDone) return;
    var root = document.body;
    if (!root) return;
    if ((root.innerText || '').trim().length >= CONTENT_CHARS) {
      contentDone = true;
      post('first-content');
      requestAnimationFrame(function () {
        requestAnimationFrame(function () { post('painted'); });
      });
    }
  }
  new MutationObserver(checkContent).observe(document.documentElement,
    { childList: true, subtree: true, characterData: true });
  document.addEventListener('DOMContentLoaded', checkContent);

  // ── 4. Paint ve LCP ─────────────────────────────────────────────────────
  try {
    new PerformanceObserver(function (l) {
      l.getEntries().forEach(function (e) { post('paint', { name: e.name }); });
    }).observe({ type: 'paint', buffered: true });
  } catch (e) {}
  try {
    // ⚠️ LCP yalnızca Chromium'da var. WebKit'te bu blok sessizce atlanır.
    new PerformanceObserver(function (l) {
      var es = l.getEntries(); post('lcp', { size: es[es.length - 1].size });
    }).observe({ type: 'largest-contentful-paint', buffered: true });
  } catch (e) {}

  // ── 5. SPA route değişimi ───────────────────────────────────────────────
  function onRoute(how) {
    contentDone = false; sawFirst = false;          // yeni ekran için sayaçları sıfırla
    post('route-change', { how: how, path: location.pathname + location.hash });
    setTimeout(checkContent, 0);
  }
  ['pushState', 'replaceState'].forEach(function (k) {
    var orig = history[k];
    history[k] = function () { var r = orig.apply(this, arguments); onRoute(k); return r; };
  });
  window.addEventListener('popstate', function () { onRoute('popstate'); });
  window.addEventListener('hashchange', function () { onRoute('hashchange'); });

  // ── 6. Native'in soracağı özet ──────────────────────────────────────────
  P.snapshot = function () {
    return { inflight: P.inflight, ignored: P.ignored,
             path: location.pathname + location.hash, marks: P.marks.length };
  };
})();
```

> 🚨 **`IGNORE` listesini keşif çıktısından doldurun.** Analitik/polling istekleri
> sayaca girerse `net-quiet` **hiç gelmez** ve Faz 5 sonsuza kadar spinner gösterir.
> Keşifte websocket/SSE gördüyseniz bu sezgiye **hiç güvenmeyin** (§00.3-E).

> ⚠️ **Prob, MFE'nin `fetch`'ini yamalar.** Bu bir davranış değişikliğidir:
> yamanın hata yutmadığından, `AbortController`'ı bozmadığından ve
> `Request` nesnesiyle çağrıldığında da çalıştığından emin olun. Prob'u
> **feature flag arkasına alın** ve kapatılabilir tutun.

---

## 1.5 Native tarafta kurulum

### iOS

```swift
import WebKit

final class ProbeHandler: NSObject, WKScriptMessageHandler {
    static let name = "probe"
    weak var sink: PhaseSink?
    let tag: String
    init(tag: String) { self.tag = tag }

    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let body = m.body as? [String: Any] else { return }
        let type = body["type"] as? String ?? "unknown"
        // ⚠️ Bilinmeyen tipleri YUTMAYIN. Yutarsanız mesajlar sessizce kaybolur
        //    ve "ölçüm gelmiyor" diye saatlerce hata ararsınız.
        sink?.received(tag: tag, phase: type, payload: body)
    }
}

// Kurulum — WebView YARATILMADAN ÖNCE (Faz 2.3)
func makeConfiguration(tag: String) -> WKWebViewConfiguration {
    let cfg = WKWebViewConfiguration()
    let ucc = WKUserContentController()
    ucc.add(ProbeHandler(tag: tag), name: ProbeHandler.name)

    let src = try! String(contentsOf: Bundle.main.url(forResource: "webview-probe",
                                                      withExtension: "js")!)
    ucc.addUserScript(WKUserScript(source: src,
                                   injectionTime: .atDocumentStart,
                                   forMainFrameOnly: true))
    cfg.userContentController = ucc
    return cfg
}
```

**Native fazlar — delegate'ten, prob olmadan:**

```swift
extension ScreenCoordinator: WKNavigationDelegate {
    func webView(_ w: WKWebView, didStartProvisionalNavigation n: WKNavigation!) {
        phase("native.nav-start")
    }
    // Redirect'i BURADA sayın — Faz 4'ün önceliği bu sayıya bağlı.
    func webView(_ w: WKWebView, didReceiveServerRedirectForProvisionalNavigation n: WKNavigation!) {
        redirectCount += 1
        phase("native.redirect", ["n": redirectCount, "url": w.url?.absoluteString ?? ""])
    }
    func webView(_ w: WKWebView, didCommit n: WKNavigation!) { phase("native.committed") }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!)  { phase("native.finished") }
}
```

### Android

```kotlin
class ProbeBridge(private val onPhase: (String, JSONObject) -> Unit) {
    @JavascriptInterface
    fun post(json: String) {
        val o = JSONObject(json)
        onPhase(o.optString("type", "unknown"), o)
    }
}

fun installProbe(webView: WebView, probeJs: String) {
    webView.addJavascriptInterface(ProbeBridge { phase, payload ->
        val ms = (SystemClock.elapsedRealtimeNanos() - t0) / 1_000_000.0
        if (ms >= 0) record(phase, ms, payload)
    }, "__ProbeBridge")

    if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
        WebViewCompat.addDocumentStartJavaScript(webView, probeJs, setOf(MFE_ORIGIN))
    } else {
        // ⚠️ Fallback yok sayılmamalı: bu cihazlarda ölçüm eksik olur.
        //    Raporlayın, sessizce geçmeyin.
        analytics.log("probe_document_start_unsupported")
    }
}
```

> ⚠️ `addJavascriptInterface` güvenlik yüzeyidir. Yalnızca **kendi origin'inize**
> yüklenen sayfalarda etkinleştirin (`addDocumentStartJavaScript`'te `setOf(origin)`
> zorunlu tutun) ve arayüzü minimum tutun — yukarıdaki `post` tek metottur.

---

## 1.6 ⚠️ Sezginin kalitesini ölçün — bu adım atlanamaz

`net-quiet` + `first-content`, MFE'nin gerçek "hazırım"ının **vekilidir**.
Vekilin ne kadar iyi olduğunu bilmeden Faz 5'i uygulayamazsınız.

**Yöntem:** 20-30 açılışı **ekran videosuyla** (60 fps) kaydedin ve karşılaştırın:

| Ölçü | Nasıl | Kabul |
|---|---|---|
| Sezgi **erken** tetikliyor | Video: içerik hâlâ görünmezken sinyal geldi | < %5 |
| Sezgi **geç** tetikliyor | Video: içerik göründükten sonra sinyal geldi | ortalama < 150 ms |
| Sezgi **hiç** tetiklemiyor | `net-quiet` gelmedi, zaman aşımına düşüldü | < %1 |

Erken tetikleme kullanıcıya **yarım ekran** gösterir; geç tetikleme **boşuna
bekletir**. Hangisine tahammülünüz olduğuna karar verin ve `QUIET_MS` /
`CONTENT_CHARS` değerlerini ona göre ayarlayın.

> **Ekranınızda hiç veri çekmeyen bir route varsa** (statik metin, onay ekranı)
> `net-quiet` anında gelir ve sezgi kusursuz çalışır. Referans ölçümde veri
> gerektirmeyen tek geçiş **8 ms** sürdü; diğerlerinin hepsi 198–578 ms.

---

## 1.7 Release build'de profiling

Debug build'in performans karakteristiği yanıltıcıdır. **Production'a yakın
build'i profilleyin.**

### Android
Chrome DevTools WebView'e tam yüzeyle bağlanır ve bu, manifest'teki `debuggable`
bayrağından **bağımsızdır** — yani release-configuration build profillenebilir.
Ama uygulamanız açıkça izin vermelidir:

```kotlin
if (FeatureFlags.webPerfProfiling) {
    WebView.setWebContentsDebuggingEnabled(true)
}
```

### iOS
iOS 16.4+ SDK'sına link edilmiş uygulamalarda `WKWebView` varsayılan olarak
inspect **edilemez**. `isInspectable = true` ile **TestFlight ve
release-configuration build'ler de** Safari Web Inspector'a açılabilir.

```swift
#if DEBUG
webView.isInspectable = true
#else
webView.isInspectable = FeatureFlags.webPerfProfiling
#endif
```

---

## 1.8 Production RUM

Lab ölçümü tek başına yetmez; p95'i gerçek cihaz/ağ dağılımında görmeniz gerekir.

Prob native'e raporladığı için **tüm zinciri native yazar** — web tarafında ayrı
bir analytics entegrasyonu gerekmez. Native, `t0`'dan `screen-ready`'ye kadar olan
faz tablosunu **tek bir event** olarak kendi analytics'ine yazar.

```swift
analytics.log("webview_screen_open", [
    "route": route, "strategy": strategy.rawValue,
    "t_committed": samples["native.committed"], "t_doc_start": samples["doc-start"],
    "t_route_change": samples["route-change"], "t_net_quiet": samples["net-quiet"],
    "t_screen_ready": samples["screen-ready"],
    "redirects": redirectCount, "xhr_count": xhrCount, "slowest_xhr_ms": slowestXhr,
    "device_class": DeviceClass.current.rawValue, "network": Reachability.current.rawValue,
    "timed_out": timedOut,
])
```

---

## 1.9 ⚠️ Cihaz sınıfına göre kırın

Ölçülmüş gerçek: aynı JS orta segment telefonda **3–4 kat**, 100 doların altındaki
cihazda **6 kattan fazla** sürüyor ([V8, 2019](https://v8.dev/blog/cost-of-javascript-2019)).

- Geliştirici telefonunda test etmeyin.
- Tek bir p50 sayısı, kullanıcılarınızın yarısının yaşadığını gizler.
- Metrikleri **cihaz sınıfı** ve **ağ koşulu** etiketiyle kırın.

---

## 1.10 Kabul kriterleri

Faz 2'ye geçmeden önce elinizde şunlar olmalı:

- [ ] Prob native kaynak ağacında, feature flag arkasında, documentStart'ta enjekte ediliyor
- [ ] `IGNORE` listesi keşif çıktısından dolduruldu
- [ ] Bilinmeyen mesaj tipleri **yutulmuyor**
- [ ] Redirect sayısı **native delegate'ten** sayılıyor
- [ ] Release-configuration build'de açılabilen profiling (flag'li)
- [ ] **p50 ve p95** faz tablosu, **cihaz sınıfı** ve **ağ koşulu** kırılımlı
- [ ] Cold start ve warm start senaryoları **ayrı** ölçülmüş
- [ ] **§1.6 sezgi kalitesi videoyla doğrulandı** ve sapma yazıldı

### İlk bakılacak üç sayı

1. **Redirect sayısı.** Sıfırdan farklıysa Faz 4 en yüksek önceliğinizdir.
2. **`native.committed` → `route-change` aralığı.** Büyükse Faz 3 çok kazandırır.
3. **`route-change` → `net-quiet` aralığı.** Baskınsa hiçbir WebView stratejisi
   sizi kurtarmaz; backend'e bakın (Faz 5.7).
